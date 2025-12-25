FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /workspace

# Install Python deps first (better layer caching)
COPY app/requirements.txt app/requirements.txt
RUN python -m pip install --upgrade pip setuptools wheel && \
    python -m pip install -r app/requirements.txt

# App source
COPY app app

EXPOSE 5000

# Healthcheck is used by docker-compose depends_on: condition: service_healthy
HEALTHCHECK --interval=5s --timeout=3s --start-period=10s --retries=30 \
  CMD python -c "import os, urllib.request; p=os.environ.get('PROXY_PORT','5000'); urllib.request.urlopen('http://127.0.0.1:{}/health'.format(p), timeout=2).read()"

CMD ["python", "-m", "app.server"]

