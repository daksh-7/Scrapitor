# 🎴 Scrapitor - Character Card Generator

> 将 JanitorAI 对话转换为 SillyTavern 角色卡

Scrapitor 是一个强大的工具，可以从 JanitorAI API 响应中提取角色定义，并生成兼容 SillyTavern 的 Character Card V2 PNG 文件。

## ✨ 主要功能

### 核心功能
- 🔄 **OpenRouter API 代理** - 转发 JanitorAI 请求到 OpenRouter
- 📝 **智能解析** - 从系统消息中提取角色定义
- 🏷️ **标签过滤** - Include/Exclude 模式灵活控制输出内容
- 🎴 **角色卡生成** - 生成 Character Card V2 格式
- 🖼️ **PNG 嵌入** - 将角色数据写入 PNG 元数据
- ☁️ **无服务器** - 完全运行在 Cloudflare Workers + Pages

### 新特性（Workers 版本）
- ⚡ **实时处理** - 无需持久化存储
- 🌍 **全球 CDN** - Cloudflare 全球加速
- 💰 **零成本** - 免费额度内完全免费
- 🔒 **安全** - 客户端处理图片，数据不上传

## 🚀 快速开始

### 在线使用

访问部署的实例:
- 🌐 [scrapitor.pages.dev](https://scrapitor.pages.dev) (演示)

### 本地运行

```bash
# 克隆仓库
git clone https://github.com/your-username/scrapitor.git
cd scrapitor

# 安装 Workers 依赖
cd workers
npm install

# 启动 Workers dev server
npm run dev

# 在另一个终端，启动前端
cd ../public
python3 -m http.server 3000

# 访问 http://localhost:3000
```

## 📖 使用指南

### 1. 配置 Parser

选择解析模式:
- **Default**: 保留所有内容（角色、场景、第一条消息）
- **Custom**: 自定义 Include/Exclude 标签

### 2. 选择日志

从下拉列表中选择一个对话日志，或者手动输入 JSON。

### 3. 解析内容

点击"Parse"按钮，查看提取的角色定义。可以手动编辑预览内容。

### 4. 上传图片

选择一张 PNG 图片作为角色头像。

### 5. 生成角色卡

填写元数据（标签、创建者名称），点击"Generate & Download"。

生成的 PNG 文件可直接导入到:
- ✅ SillyTavern
- ✅ Agnaistic
- ✅ 其他支持 Character Card V2 的前端

## 🏗️ 架构

```
┌─────────────────┐
│  Cloudflare     │
│  Pages          │  ← 静态前端 (HTML/JS/CSS)
└────────┬────────┘
         │
         │ API calls
         ↓
┌─────────────────┐
│  Cloudflare     │
│  Workers        │  ← API (TypeScript)
│                 │    - OpenRouter 代理
│  - proxy.ts     │    - 消息解析
│  - parser.ts    │    - 角色卡生成
│  - character-   │
│    card.ts      │
└─────────────────┘
         │
         │ Upstream
         ↓
┌─────────────────┐
│  OpenRouter     │
│  API            │
└─────────────────┘
```

### 技术栈

**后端 (Workers):**
- TypeScript
- Cloudflare Workers
- Character Card V2 规范

**前端:**
- Vanilla JavaScript
- PNG Chunk Manipulation
- Responsive CSS

## 📂 项目结构

```
Scrapitor/
├── workers/                # Cloudflare Workers API
│   ├── src/
│   │   ├── index.ts       # 入口文件
│   │   ├── proxy.ts       # OpenRouter 代理
│   │   ├── parser.ts      # 消息解析器
│   │   ├── character-card.ts  # 角色卡生成
│   │   └── utils/
│   │       └── cors.ts    # CORS 处理
│   ├── package.json
│   └── wrangler.toml      # Cloudflare 配置
│
├── public/                 # 前端静态文件
│   ├── index.html         # 主页面
│   ├── js/
│   │   ├── png-handler.js         # PNG 元数据处理
│   │   ├── character-card.js      # 角色卡生成器
│   │   └── card-generator-ui.js   # UI 逻辑
│   ├── css/
│   │   └── app.css
│   ├── _headers           # Cloudflare Pages 头部
│   └── _redirects         # API 代理配置
│
├── docs/                   # 文档
│   └── cloudflare-workers-migration-plan.md
│
├── DEPLOYMENT.md           # 部署指南
└── README.md
```

## 🔧 配置

### Workers 环境变量

在 `wrangler.toml` 或 Cloudflare Dashboard 中设置:

```toml
[env.production]
vars = {
  ENVIRONMENT = "production",
  OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
}
```

### 前端配置

修改 `public/_redirects` 中的 Workers URL:

```
/api/*  https://your-worker.workers.dev/:splat  200
```

## 📡 API 文档

### `POST /api/proxy`

转发请求到 OpenRouter。

**Headers:**
```
Authorization: Bearer YOUR_OPENROUTER_KEY
Content-Type: application/json
```

**Body:**
```json
{
  "model": "mistralai/mistral-small",
  "messages": [...],
  "stream": false
}
```

### `POST /api/parse`

解析消息并提取角色内容。

**Body:**
```json
{
  "messages": [...],
  "parserMode": "custom",
  "includeTags": ["character", "scenario"],
  "excludeTags": []
}
```

**Response:**
```json
{
  "characterName": "Miku",
  "content": "...",
  "tags": ["character", "scenario"],
  "metadata": {
    "scenario": "...",
    "firstMessage": "..."
  }
}
```

### `POST /api/create-card`

生成 Character Card V2 数据。

**Body:**
```json
{
  "characterName": "Miku",
  "content": "...",
  "scenario": "...",
  "firstMessage": "...",
  "tags": ["anime", "vocaloid"],
  "creator": "YourName"
}
```

**Response:**
```json
{
  "spec": "chara_card_v2",
  "spec_version": "2.0",
  "data": {
    "name": "Miku",
    "description": "...",
    ...
  }
}
```

## 🚢 部署

详细部署指南请查看 [DEPLOYMENT.md](./DEPLOYMENT.md)。

### 快速部署

```bash
# 部署 Workers
cd workers
npm install
wrangler login
wrangler deploy

# 部署 Pages
cd ..
wrangler pages deploy public --project-name=scrapitor
```

或使用 GitHub Actions 自动部署（推送到 `main` 分支）。

## 🧪 测试

### 本地测试

```bash
# Workers
cd workers
npm run dev

# 访问 http://localhost:8787/health
```

### 功能测试

1. 打开浏览器开发者工具
2. 访问前端页面
3. 按步骤操作并检查控制台输出

### 角色卡验证

生成的 PNG 文件可以:
1. 用 `PNGHandler.readTextChunk()` 读取验证
2. 导入到 SillyTavern 测试
3. 用在线工具检查 PNG chunks: https://www.nayuki.io/page/png-file-chunk-inspector

## 📝 Character Card V2 规范

Scrapitor 遵循官方 Character Card V2 规范:
- GitHub: https://github.com/malfoyslastname/character-card-spec-v2
- 数据存储在 PNG `tEXt` chunk，keyword 为 `"chara"`
- JSON 数据 base64 编码

## 🤝 贡献

欢迎贡献！请遵循以下步骤:

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 Pull Request

## 📄 License

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🙏 致谢

- [Character Card V2 Specification](https://github.com/malfoyslastname/character-card-spec-v2)
- [SillyTavern](https://github.com/SillyTavern/SillyTavern)
- [OpenRouter](https://openrouter.ai/)
- [Cloudflare Workers](https://workers.cloudflare.com/)

## 📧 联系方式

- Issues: https://github.com/your-username/scrapitor/issues
- Discussions: https://github.com/your-username/scrapitor/discussions

---

**注意:** 本项目仅用于教育和个人使用。请遵守相关服务的使用条款。
