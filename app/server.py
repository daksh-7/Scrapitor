from __future__ import annotations

import datetime as dt
import json
import hashlib
import logging
import os
import pathlib
import string
import re
import subprocess
import sys
import time
from typing import Any, Dict

import requests
try:
    import yaml  # optional; config.yaml support
except Exception:
    yaml = None  # type: ignore
from flask import Flask, Response, jsonify, request, stream_with_context, render_template_string, render_template
from flask_cors import CORS
try:
    from werkzeug.middleware.proxy_fix import ProxyFix
except Exception:
    ProxyFix = None  # type: ignore


# ── config ───────────────────────────────────────────────────
def _load_config() -> Dict[str, Any]:
    cfg_path = pathlib.Path("config.yaml")
    file_cfg: Dict[str, Any] = {}
    if cfg_path.exists() and yaml is not None:
        try:
            file_cfg = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
        except Exception as e:
            print(f"Warning: failed to load config.yaml: {e}")

    def get(path, default):
        cur = file_cfg
        for k in path.split("."):
            cur = (cur or {}).get(k, {})
        return default if cur == {} else cur

    # env helpers
    def env(k, default, cast=str):
        v = os.getenv(k)
        if v is None:
            return default
        try:
            return cast(v)
        except Exception:
            return default

    return {
        "server": {
            "port": env("PROXY_PORT", get("server.port", 5000), int),
            "allowed_origins": (
                os.getenv("ALLOWED_ORIGINS", "") or ",".join(get("server.allowed_origins", ["*"]))
            ).split(","),
            "rate_limit": env("RATE_LIMIT", get("server.rate_limit", "60 per minute")),
            "connect_timeout": env("CONNECT_TIMEOUT", get("server.connect_timeout", 5.0), float),
            "read_timeout": env("READ_TIMEOUT", get("server.read_timeout", 300.0), float),
        },
        "openrouter": {
            "url": os.getenv("OPENROUTER_URL", get("openrouter.url", "https://openrouter.ai/api/v1/chat/completions")),
            "api_key": os.getenv("OPENROUTER_API_KEY", get("openrouter.api_key", "")),
            "defaults": get("openrouter.defaults", {
                "temperature": 1.0, "top_p": 1.0, "top_k": 0, "max_tokens": 1024
            }),
        },
        "logging": {
            "directory": os.getenv("LOG_DIR", get("logging.directory", "var/logs")),
            "max_files": env("MAX_LOG_FILES", get("logging.max_files", 1000), int),
            "level": os.getenv("LOG_LEVEL", get("logging.level", "INFO")),
        },
        "parser": get("parser", {
            "mode": "default",   # default | custom
            "include_tags": [],
            "exclude_tags": [],
        }),
        "security": get("security", {"max_messages": 50, "max_model_length": 100, "validate_requests": True}),
    }

CONFIG = _load_config()

logging.basicConfig(
    level=getattr(logging, CONFIG["logging"]["level"], logging.INFO),
    format="%(asctime)s - %(levelname)s - %(message)s",
)
log = logging.getLogger("proxy")

OPENROUTER_URL = CONFIG["openrouter"]["url"]
LISTEN_PORT = CONFIG["server"]["port"]
TIMEOUT = (CONFIG["server"]["connect_timeout"], CONFIG["server"]["read_timeout"])
BASE_DIR = pathlib.Path(__file__).parents[1]
BASE_DIR = pathlib.Path(__file__).parent
LOG_DIR = (BASE_DIR / CONFIG["logging"].get("directory", "var/logs")).resolve(); LOG_DIR.mkdir(parents=True, exist_ok=True)
PARSED_ROOT = (LOG_DIR / "parsed").resolve(); PARSED_ROOT.mkdir(parents=True, exist_ok=True)
MAX_LOG_FILES = CONFIG["logging"]["max_files"]
GEN_CFG = CONFIG["openrouter"]["defaults"].copy()
STARTED_MONO = time.monotonic()

# Parser settings (mutable at runtime, persisted under var/state)
_PARSER_SETTINGS_PATH = (BASE_DIR / "var/state/parser_settings.json").resolve()

def _load_parser_settings() -> Dict[str, Any]:
    base = {
        "mode": str(CONFIG["parser"].get("mode", "default")),
        "include_tags": list(CONFIG["parser"].get("include_tags", [])),
        "exclude_tags": list(CONFIG["parser"].get("exclude_tags", [])),
    }
    try:
        if _PARSER_SETTINGS_PATH.exists():
            disk = json.loads(_PARSER_SETTINGS_PATH.read_text(encoding="utf-8"))
            if isinstance(disk, dict):
                # Backward compatibility mapping
                if "mode" in disk and "tags" in disk and ("include_tags" not in disk and "exclude_tags" not in disk):
                    old_mode = str(disk.get("mode", "keep_all")).lower()
                    tags = list(disk.get("tags", []))
                    if old_mode == "include":
                        disk["mode"] = "custom"; disk["include_tags"] = tags; disk["exclude_tags"] = []
                    elif old_mode == "omit":
                        disk["mode"] = "custom"; disk["exclude_tags"] = tags; disk["include_tags"] = []
                    else:
                        disk["mode"] = "default"; disk["include_tags"] = []; disk["exclude_tags"] = []
                if "preset" in disk or "omit_tags" in disk or "include_tags" in disk:
                    preset = str(disk.get("preset", "default")).lower()
                    if preset == "default":
                        disk["mode"] = "default"
                        disk.setdefault("include_tags", [])
                        disk.setdefault("exclude_tags", [])
                    else:
                        disk["mode"] = "custom"
                        disk.setdefault("include_tags", disk.get("include_tags", []))
                        disk.setdefault("exclude_tags", disk.get("omit_tags", []))
                for k in ("mode","include_tags","exclude_tags"):
                    if k in disk:
                        base[k] = disk[k]
    except Exception as e:
        log.warning(f"Failed to read parser_settings.json: {e}")
    return base

def _save_parser_settings(settings: Dict[str, Any]) -> None:
    try:
        _PARSER_SETTINGS_PATH.write_text(json.dumps(settings, ensure_ascii=False, indent=2), encoding="utf-8")
    except Exception as e:
        log.warning(f"Failed to write parser_settings.json: {e}")

PARSER_SETTINGS = _load_parser_settings()

# Shared parameter bounds
BOUNDS = {
    "temperature": (0, 2, float),
    "top_p": (0, 1, float),
    "top_k": (0, 200, int),
    "max_tokens": (1, 4096, int),
}

# ── session ──────────────────────────────────────────────────
sess = requests.Session()
adapter = requests.adapters.HTTPAdapter(pool_connections=10, pool_maxsize=10, max_retries=3)
sess.mount("http://", adapter); sess.mount("https://", adapter)
sess.headers.update({
    "Content-Type": "application/json",
    "Referer": "https://janitorai.com/",
    "X-Title": "JanitorAI-Local-Proxy",
})
_do_post   = lambda **kw: sess.post(OPENROUTER_URL, timeout=TIMEOUT, **kw)
_do_stream = lambda **kw: sess.post(OPENROUTER_URL, stream=True, timeout=TIMEOUT, **kw)

# ── utils ────────────────────────────────────────────────────
def _ts() -> str:
    now = dt.datetime.now(dt.timezone.utc)
    return now.strftime("%Y-%m-%d_%H-%M-%S_%f")[:-3]

def _safe_name(seed: str) -> str:
    allowed = set(string.ascii_letters + string.digits + "-_ .")
    s = "".join(c for c in (seed or "") if c in allowed).strip()[:100]
    return s or "log"

def _prune_logs() -> None:
    files = sorted(LOG_DIR.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    for old in files[MAX_LOG_FILES:]:
        try:
            old.unlink()
        except Exception as e:
            log.warning(f"Failed to delete old log {old.name}: {e}")

def _save_log(payload: dict) -> None:
    try:
        path = LOG_DIR / f"{_safe_name(_ts())}.json"
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        _prune_logs()

        parser = pathlib.Path(__file__).parent / "parser" / "parser.py"
        if parser.exists():
            try:
                # Build parser args based on current settings
                args = _build_parser_args(path)
                res = subprocess.run(args, capture_output=True, text=True)
                if res.stdout.strip(): log.debug(f"Parser stdout: {res.stdout.strip()}")
                if res.stderr.strip(): log.warning(f"Parser stderr: {res.stderr.strip()}")
            except Exception as e:
                log.warning(f"Parser.py failed: {e}")
    except Exception as e:
        log.error(f"Failed to save log: {e}")

def _next_version_suffix_for(json_path: pathlib.Path) -> str:
    """Return next human-friendly version label like 'v3' for parsed TXT outputs.

    Versioning is scoped to the parsed directory for this JSON's stem.
    """
    base_dir = _parsed_output_dir_for(json_path)
    try:
        base_dir.mkdir(parents=True, exist_ok=True)
    except Exception:
        pass
    max_v = 0
    try:
        for p in base_dir.glob("*.v*.txt"):
            name = p.name
            try:
                after = name.rsplit('.v', 1)[1]
                num = after.split('.txt', 1)[0]
                v = int(''.join(ch for ch in num if ch.isdigit()))
                if v > max_v:
                    max_v = v
            except Exception:
                continue
    except Exception:
        pass
    return f"v{max_v + 1}"


def _parsed_output_dir_for(json_path: pathlib.Path) -> pathlib.Path:
    # Place versions under var/logs/parsed/<json_stem>/
    return (PARSED_ROOT / json_path.stem).resolve()


def _build_parser_args(json_path: pathlib.Path) -> list[str]:
    args = [sys.executable, str(pathlib.Path(__file__).parent / "parser" / "parser.py")]
    mode = str(PARSER_SETTINGS.get("mode", "default")).lower()
    include_tags = [str(x).strip() for x in PARSER_SETTINGS.get("include_tags", []) if str(x).strip()]
    exclude_tags = [str(x).strip() for x in PARSER_SETTINGS.get("exclude_tags", []) if str(x).strip()]
    persona_name = ""
    if mode == "custom":
        if include_tags:
            args += ["--preset", "custom", "--include-tags", ",".join(include_tags)]
        elif exclude_tags:
            args += ["--preset", "custom", "--omit-tags", ",".join(exclude_tags)]
        else:
            args += ["--preset", "default"]
    else:
        args += ["--preset", "default"]
    # Output routing and versioning
    out_dir = _parsed_output_dir_for(json_path)
    suffix = _next_version_suffix_for(json_path)
    args += ["--output-dir", str(out_dir), "--suffix", suffix]

    # no persona mapping; persona tag is always 'UserPersona'
    args.append(str(json_path))
    return args

def _validate_payload(pl: dict) -> dict:
    if not CONFIG["security"]["validate_requests"]:
        return pl
    if not isinstance(pl, dict) or not isinstance(pl.get("messages"), list):
        raise ValueError("`messages` must be an array")

    messages = pl["messages"][: CONFIG["security"]["max_messages"]]

    def clamp(value, lo, hi, cast, default):
        try:
            return max(lo, min(hi, cast(value)))
        except Exception:
            return max(lo, min(hi, cast(default)))

    out = {
        "model": str(pl.get("model", ""))[: CONFIG["security"]["max_model_length"]],
        "messages": messages,
        "stream": bool(pl.get("stream", False)),
    }
    for key, (lo, hi, cast) in BOUNDS.items():
        out[key] = clamp(pl.get(key, GEN_CFG[key]), lo, hi, cast, GEN_CFG[key])
    return out

def _auth_headers(client_auth: str) -> dict:
    headers: Dict[str, str] = {}
    if CONFIG["openrouter"]["api_key"]:
        headers["Authorization"] = f"Bearer {CONFIG['openrouter']['api_key']}"
        if client_auth:
            headers["X-Original-Authorization"] = client_auth
    elif client_auth:
        headers["Authorization"] = client_auth
    return headers

def _stream_back(payload: dict, headers: dict):
    try:
        hdrs = dict(headers)
        hdrs.setdefault("Accept", "text/event-stream")
        with _do_stream(json=payload, headers=hdrs) as r:
            r.raise_for_status()
            for chunk in r.iter_lines():
                # OpenRouter streams Server-Sent Events already ("data: {...}\n\n")
                if chunk and chunk != b": OPENROUTER PROCESSING":
                    yield chunk + b"\n\n"
    except requests.exceptions.RequestException as e:
        err = {"error": {"message": str(e), "type": "stream_error"}}
        yield f"data: {json.dumps(err)}\n\n".encode()

# ── app ──────────────────────────────────────────────────────
def create_app() -> Flask:
    app = Flask(__name__, static_folder='static', template_folder='templates', static_url_path='/static')
    # Honor X-Forwarded-* headers from cloudflared so url_for and request.url_root are correct
    try:
        from werkzeug.middleware.proxy_fix import ProxyFix
        app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_prefix=1)
    except Exception:
        pass

    # Allow cross-origin access (including Authorization header) so the
    # JanitorAI site or other tools can call the proxy via the Cloudflare URL.
    # Cloudflared terminates TLS and forwards to us over HTTP, so we keep this
    # permissive to avoid "localhost-only" behavior from browsers.
    CORS(
        app,
        resources={r"/*": {"origins": "*"}},
        allow_headers=["Content-Type", "Authorization"],
        expose_headers=["Content-Type", "Authorization"],
        supports_credentials=False,
    )

    # No rate limiting

    @app.route("/openrouter-cc", methods=["GET", "POST", "OPTIONS"])
    def openrouter_cc():
        if request.method == "OPTIONS":
            return "", 204
        if request.method == "GET":
            return jsonify({
                "status": "alive",
                "message": "Proxy alive - POST your /chat/completions here",
                "version": "2.0",
                "config": {"max_messages": CONFIG["security"]["max_messages"]},
            })
        return _handle_completion()

    # Optional alias to match OpenAI route shape if you want:
    @app.route("/chat/completions", methods=["POST"])
    def chat_completions():
        return _handle_completion()

    def _handle_completion():
        if not request.is_json:
            return jsonify({"error": "Only application/json accepted"}), 415

        client_auth = request.headers.get("Authorization", "")

        # No mandatory server-side API key; client should supply Authorization header.

        payload_in = request.get_json(silent=True) or {}
        # fire-and-forget log write (synchronous but quick, no thread)
        _save_log(dict(payload_in))

        try:
            payload = _validate_payload(payload_in)
        except ValueError as e:
            return jsonify({"error": str(e)}), 400

        headers = _auth_headers(client_auth)

        if payload.get("stream"):
            gen = stream_with_context(_stream_back(payload, headers))
            return Response(gen, mimetype="text/event-stream")

        try:
            r = _do_post(json=payload, headers=headers)
            r.raise_for_status()
            return r.json(), r.status_code
        except requests.exceptions.HTTPError as e:
            try:
                detail = e.response.json().get("error", {}).get("message", str(e))
            except Exception:
                detail = f"OpenRouter error: {getattr(e.response,'status_code', 'unknown')}"
            log.error(f"OpenRouter HTTP error: {detail}")
            return jsonify({"error": detail}), 502
        except Exception as e:
            log.exception("Unexpected error")
            return jsonify({"error": "Internal server error"}), 500

    @app.route("/models")
    def models():
        return {
            "object": "list",
            "data": [{"id": "openrouter-proxy", "object": "model", "created": 0, "owned_by": "janitorai-local-proxy"}],
        }

    @app.route("/param", methods=["GET", "POST"])
    def param():
        if request.method == "POST":
            data = request.get_json(silent=True) or {}
            for k, (lo, hi, cast) in BOUNDS.items():
                if k in data:
                    try:
                        GEN_CFG[k] = max(lo, min(hi, cast(data[k])))
                    except Exception:
                        pass
        return jsonify(GEN_CFG)

    @app.route("/logs")
    def list_logs():
        files = sorted(LOG_DIR.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
        names = [p.name for p in files[:50]]
        return jsonify({"logs": names, "total": len(files), "recent": names})

    @app.route("/logs/<name>")
    def get_log(name: str):
        safe = _safe_name(name)
        if not safe.endswith(".json"):
            safe += ".json"
        p = LOG_DIR / safe
        if p.exists() and p.is_file():
            try:
                return p.read_text(encoding="utf-8"), 200, {"Content-Type": "application/json"}
            except Exception as e:
                return jsonify({"error": f"Failed to read log: {e}"}), 500
        return jsonify({"error": f"{safe} not found"}), 404

    @app.route("/logs/<name>/parsed", methods=["GET"])
    def list_parsed_versions(name: str):
        safe = _safe_name(name)
        if safe.endswith(".json"):
            stem = pathlib.Path(safe).stem
        else:
            stem = pathlib.Path(safe + ".json").stem
        base_dir = _parsed_output_dir_for(LOG_DIR / f"{stem}.json")
        try:
            if not base_dir.exists() or not base_dir.is_dir():
                return jsonify({"versions": [], "latest": ""})
            files = sorted(base_dir.glob("*.txt"), key=lambda p: p.stat().st_mtime, reverse=True)
            out = []
            latest_id = ""
            highest_v = -1
            for i, p in enumerate(files):
                try:
                    st = p.stat()
                    ver = None
                    nm = p.name
                    if ".v" in nm:
                        try:
                            after = nm.rsplit('.v', 1)[1]
                            num = after.split('.txt', 1)[0]
                            ver = int(''.join(ch for ch in num if ch.isdigit()))
                            if ver is not None and ver > highest_v:
                                highest_v = ver
                                latest_id = p.name
                        except Exception:
                            pass
                    item = {
                        "id": p.name,
                        "file": p.name,
                        "size": st.st_size,
                        "mtime": st.st_mtime,
                        "version": ver,
                    }
                    out.append(item)
                except Exception:
                    continue
            if not latest_id and out:
                latest_id = out[0]["file"]
            return jsonify({"versions": out, "latest": latest_id, "dir": base_dir.name})
        except Exception as e:
            return jsonify({"versions": [], "error": str(e)}), 500

    @app.route("/logs/<name>/parsed/<path:fname>", methods=["GET"])
    def get_parsed_content(name: str, fname: str):
        safe = _safe_name(name)
        if safe.endswith(".json"):
            stem = pathlib.Path(safe).stem
        else:
            stem = pathlib.Path(safe + ".json").stem
        base_dir = _parsed_output_dir_for(LOG_DIR / f"{stem}.json")
        target = (base_dir / fname).resolve()
        try:
            # Ensure target is inside base_dir
            if base_dir not in target.parents:
                return jsonify({"error": "Invalid path"}), 400
            if target.exists() and target.is_file() and target.suffix.lower() == ".txt":
                return target.read_text(encoding="utf-8-sig"), 200, {"Content-Type": "text/plain; charset=utf-8"}
            return jsonify({"error": f"{fname} not found"}), 404
        except Exception as e:
            return jsonify({"error": str(e)}), 500

    @app.route("/logs/<name>/rename", methods=["POST"])
    def rename_log(name: str):
        data = request.get_json(silent=True) or {}
        new_name_raw = str(data.get("new_name", "")).strip()
        if not new_name_raw:
            return jsonify({"error": "new_name is required"}), 400
        old_safe = _safe_name(name)
        if not old_safe.endswith('.json'):
            old_safe += '.json'
        old_path = LOG_DIR / old_safe
        if not old_path.exists():
            return jsonify({"error": f"{old_safe} not found"}), 404
        new_safe = _safe_name(new_name_raw)
        if not new_safe.endswith('.json'):
            new_safe += '.json'
        new_path = LOG_DIR / new_safe
        if new_path.exists():
            return jsonify({"error": "A file with that name already exists"}), 409
        try:
            old_path.rename(new_path)
            # Move parsed dir if present
            old_dir = _parsed_output_dir_for(old_path)
            new_dir = _parsed_output_dir_for(new_path)
            if old_dir.exists() and old_dir.is_dir():
                try:
                    old_dir.rename(new_dir)
                except Exception:
                    pass
            return jsonify({"old": old_safe, "new": new_safe})
        except Exception as e:
            return jsonify({"error": str(e)}), 500

    @app.route("/logs/<name>/parsed/rename", methods=["POST"])
    def rename_parsed_txt(name: str):
        data = request.get_json(silent=True) or {}
        old_file = str(data.get("old", "")).strip()
        new_file_raw = str(data.get("new", "")).strip()
        if not old_file or not new_file_raw:
            return jsonify({"error": "old and new are required"}), 400
        safe = _safe_name(name)
        if not safe.endswith('.json'):
            safe += '.json'
        base_dir = _parsed_output_dir_for(LOG_DIR / safe)
        old_p = (base_dir / pathlib.Path(old_file).name).resolve()
        new_safe = _safe_name(new_file_raw)
        if not new_safe.endswith('.txt'):
            new_safe += '.txt'
        new_p = (base_dir / new_safe).resolve()
        try:
            if base_dir not in old_p.parents or base_dir not in new_p.parents:
                return jsonify({"error": "Invalid path"}), 400
            if not old_p.exists() or not old_p.is_file():
                return jsonify({"error": "Source file not found"}), 404
            if new_p.exists():
                return jsonify({"error": "Destination already exists"}), 409
            new_p.write_text(old_p.read_text(encoding='utf-8-sig'), encoding='utf-8-sig')
            try:
                old_p.unlink()
            except Exception:
                pass
            return jsonify({"old": old_p.name, "new": new_p.name})
        except Exception as e:
            return jsonify({"error": str(e)}), 500

    @app.route("/parser-settings", methods=["GET", "POST"])
    def parser_settings():
        global PARSER_SETTINGS
        if request.method == "POST":
            data = request.get_json(silent=True) or {}
            mode = str(data.get("mode", PARSER_SETTINGS.get("mode", "default")).lower())
            if mode not in ("default", "custom"):
                mode = "default"

            def _norm_list(v):
                if isinstance(v, str):
                    return [s.strip() for s in v.split(',') if s.strip()]
                if isinstance(v, list):
                    return [str(s).strip() for s in v if str(s).strip()]
                return []

            include_tags = _norm_list(data.get("include_tags", PARSER_SETTINGS.get("include_tags", [])))
            exclude_tags = _norm_list(data.get("exclude_tags", PARSER_SETTINGS.get("exclude_tags", [])))
            PARSER_SETTINGS = {
                "mode": mode,
                "include_tags": include_tags,
                "exclude_tags": exclude_tags,
            }
            _save_parser_settings(PARSER_SETTINGS)
        return jsonify(PARSER_SETTINGS)

    @app.route("/parser-rewrite", methods=["POST"])
    def parser_rewrite():
        data = request.get_json(silent=True) or {}
        mode = str(data.get("mode", "all")).lower()
        files_in = data.get("files", [])
        if isinstance(files_in, list) and files_in:
            targets = [LOG_DIR / (f if f.endswith('.json') else f + '.json') for f in files_in]
            targets = [t for t in targets if t.exists() and t.is_file()]
        else:
            files = sorted(LOG_DIR.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
            targets = files if mode != "latest" else (files[:1] if files else [])

        results = []
        for t in targets:
            try:
                args = _build_parser_args(t)
                res = subprocess.run(args, capture_output=True, text=True)
                ok = res.returncode == 0
                results.append({
                    "file": t.name,
                    "ok": ok,
                    "stdout": res.stdout.strip(),
                    "stderr": res.stderr.strip(),
                })
            except Exception as e:
                results.append({"file": t.name, "ok": False, "error": str(e)})
        return jsonify({"rewritten": len(results), "results": results})

    @app.route("/tunnel", methods=["GET"])
    def tunnel():
        try:
            p = BASE_DIR / "var/state/tunnel_url.txt"
            if p.exists():
                url = p.read_text(encoding="utf-8").strip()
                return jsonify({"url": url})
        except Exception:
            pass
        return jsonify({"url": ""})

    @app.route("/parser-tags", methods=["GET"])
    def parser_tags():
        """Return tag names detected from selected log file(s).

        Query params:
        - file: may repeat multiple times
        - files: comma-separated list
        If none provided, falls back to latest.
        """
        names_in = set()
        for n in request.args.getlist("file"):
            n = (n or "").strip()
            if n:
                names_in.add(n)
        csv = (request.args.get("files", "") or "").strip()
        if csv:
            for n in csv.split(','):
                n = n.strip()
                if n:
                    names_in.add(n)

        files = sorted(LOG_DIR.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
        targets = []
        if names_in:
            for raw in names_in:
                safe = _safe_name(raw)
                if not safe.endswith('.json'):
                    safe += '.json'
                cand = LOG_DIR / safe
                if cand.exists():
                    targets.append(cand)
        else:
            if files:
                targets = [files[0]]

        if not targets:
            return jsonify({"tags": [], "files": [], "by_file": {}, "by_tag": {}})

        names = set()
        used = []
        file_to_tags: dict[str, list[str]] = {}
        for target in targets:
            try:
                data = json.loads(target.read_text(encoding='utf-8'))
                msgs = data.get('messages', [])
                content = ""
                if msgs and isinstance(msgs[0], dict) and msgs[0].get('role') == "system":
                    content = str(msgs[0].get('content', ""))
                tagset = set()
                for m in re.finditer(r"<\s*([^<>/]+?)\s*>", content, re.IGNORECASE):
                    nm = m.group(1).strip()
                    if nm:
                        names.add(nm)
                        tagset.add(nm)
                used.append(target.name)
                file_to_tags[target.name] = sorted({t.strip() for t in tagset if t.strip()}, key=lambda x: x.lower())
            except Exception:
                continue

        tag_to_files: dict[str, list[str]] = {}
        for fname, tags in file_to_tags.items():
            for t in tags:
                tag_to_files.setdefault(t, []).append(fname)
        for t, lst in tag_to_files.items():
            tag_to_files[t] = sorted(lst)
        return jsonify({
            "tags": sorted(names, key=lambda x: x.lower()),
            "files": used,
            "by_file": file_to_tags,
            "by_tag": tag_to_files,
        })

    @app.route("/health")
    def health():
        return jsonify({
            "status": "healthy",
            "uptime_seconds": round(time.monotonic() - STARTED_MONO, 3),
            "version": "2.0",
            "config": {"port": LISTEN_PORT},
        })

    return app

app = create_app()

@app.route("/")
def ui():
    html = render_template(
        "index.html",
        port=LISTEN_PORT,
        max_messages=CONFIG["security"]["max_messages"],
    )
    return html, 200, {"Cache-Control": "no-store, no-cache, must-revalidate, max-age=0"}


@app.errorhandler(500)
def internal_error(e):
    log.exception("Internal server error")
    return jsonify({
        "error": "Internal server error",
        "message": "An unexpected error occurred"
    }), 500


# ── run ───────────────────────────────────────────────────
if __name__ == "__main__":
    os.chdir(pathlib.Path(__file__).parent.resolve())
    
    # Show configuration summary
    log.info(f"Starting JanitorAI Proxy on port {LISTEN_PORT}")
    log.info(f"API key configured: {bool(CONFIG['openrouter']['api_key'])}")
    log.info(f"Allowed origins: {CONFIG['server']['allowed_origins']}")
    
    app.run(host="0.0.0.0", port=LISTEN_PORT, threaded=True, debug=False)
