# Cloudflare 部署指南

本指南介绍如何将 Scrapitor 部署到 Cloudflare Workers + Pages。

## 前置要求

1. **Cloudflare 账号**
   - 注册: https://dash.cloudflare.com/sign-up
   - 免费套餐即可

2. **Node.js 和 npm**
   - 版本: Node.js 18+
   - 安装: https://nodejs.org/

3. **Wrangler CLI**
   ```bash
   npm install -g wrangler
   ```

4. **Git**（可选，用于自动部署）

## 快速开始

### 1. Workers API 部署

```bash
# 进入 workers 目录
cd workers

# 安装依赖
npm install

# 登录 Cloudflare
wrangler login

# 本地测试
npm run dev

# 部署到生产环境
npm run deploy
```

部署成功后，你会得到一个 Workers URL，类似：
```
https://scrapitor-api.your-subdomain.workers.dev
```

### 2. Pages 前端部署

#### 方法 A: 通过 Wrangler CLI

```bash
# 从项目根目录
wrangler pages deploy public --project-name=scrapitor
```

#### 方法 B: 通过 Cloudflare Dashboard (推荐)

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. 进入 **Pages** 部分
3. 点击 **Create a project**
4. 选择 **Connect to Git** 或 **Direct Upload**

**Git 方式:**
- 连接你的 GitHub 仓库
- 设置构建配置:
  - Build command: (留空)
  - Build output directory: `public`
  - Root directory: (留空)

**直接上传:**
```bash
cd public
zip -r scrapitor.zip .
# 在 Dashboard 上传 scrapitor.zip
```

### 3. 配置 API 端点

部署完成后，需要更新 `public/_redirects` 文件中的 Workers URL：

```
# 将这一行
/api/*  https://scrapitor-api.your-domain.workers.dev/:splat  200

# 改为你的实际 Workers URL
/api/*  https://scrapitor-api.abc123.workers.dev/:splat  200
```

然后重新部署 Pages。

## 环境变量配置

### Workers 环境变量

在 `wrangler.toml` 或 Cloudflare Dashboard 中设置：

```toml
[env.production]
vars = {
  ENVIRONMENT = "production",
  OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
}
```

或者在 Dashboard:
1. 进入 Workers & Pages
2. 选择你的 Worker
3. Settings → Variables
4. 添加环境变量

### Pages 环境变量

通常不需要，所有配置都在 Workers 端。

## 自动化部署（GitHub Actions）

### 1. 设置 GitHub Secrets

在你的 GitHub 仓库中设置以下 Secrets:

1. `CLOUDFLARE_API_TOKEN`
   - 获取方式: Cloudflare Dashboard → My Profile → API Tokens
   - 创建一个新 Token，模板选择 "Edit Cloudflare Workers"
   - 权限需要: `Account.Cloudflare Pages:Edit`, `Account.Workers Scripts:Edit`

2. `CLOUDFLARE_ACCOUNT_ID`
   - 获取方式: Cloudflare Dashboard → Workers & Pages → 右侧 Account ID

### 2. 启用 Workflow

将 `.github/workflows/deploy.yml` 推送到仓库后，每次推送到 `main` 分支时会自动部署。

查看部署状态:
- GitHub: Actions 标签页
- Cloudflare: Workers & Pages → Deployments

## 自定义域名

### Workers 自定义域名

1. Cloudflare Dashboard → Workers & Pages
2. 选择你的 Worker
3. Triggers → Custom Domains → Add Custom Domain
4. 输入域名，如 `api.yourdomain.com`
5. Cloudflare 会自动添加 DNS 记录

### Pages 自定义域名

1. Cloudflare Dashboard → Pages
2. 选择你的项目
3. Custom domains → Set up a custom domain
4. 输入域名，如 `scrapitor.yourdomain.com`
5. Cloudflare 会自动配置 CNAME

## 本地开发

### 同时运行 Workers 和前端

Terminal 1 - Workers:
```bash
cd workers
npm run dev
# 运行在 http://localhost:8787
```

Terminal 2 - 前端 (简单 HTTP 服务器):
```bash
cd public
python3 -m http.server 3000
# 或使用其他 HTTP 服务器
```

然后访问 `http://localhost:3000`

### 本地测试完整流程

1. 确保 Workers dev server 运行在 8787 端口
2. 修改前端代码中的 API 端点为 `http://localhost:8787`
3. 测试所有功能

## 常见问题

### Q: 部署后出现 404

**A:** 检查以下几点:
1. `_redirects` 文件中的 Workers URL 是否正确
2. Workers 是否成功部署
3. 浏览器控制台是否有 CORS 错误

### Q: Workers CPU 时间超限

**A:** 如果解析大文件时超时:
1. 考虑将解析移到前端
2. 或者使用 Durable Objects (需付费)
3. 简化 Parser 逻辑

### Q: 无法上传大图片

**A:** Cloudflare Pages 有文件大小限制:
1. 图片文件建议 < 5MB
2. 或使用 Cloudflare Images (需付费)

### Q: 如何查看日志

**A:**
- Workers 日志: Dashboard → Workers → Logs → Tail Workers
- Pages 日志: Dashboard → Pages → 项目 → Deployments → View Logs
- 或使用 `wrangler tail` 实时查看

## 成本估算

Cloudflare Workers 和 Pages 提供慷慨的免费额度:

| 服务 | 免费额度 | 超出费用 |
|------|---------|---------|
| Workers Requests | 100,000 /天 | $0.50 / 百万请求 |
| Workers CPU Time | 10ms / 请求 | 按使用量 |
| Pages Builds | 500 / 月 | $0.25 / 构建 |
| Pages Bandwidth | 无限 | 免费 |

对于个人使用，**完全免费**。

## 更新和维护

### 更新 Workers

```bash
cd workers
git pull
npm install
npm run deploy
```

### 更新 Pages

如果使用 Git 集成，直接推送代码即可:
```bash
git add .
git commit -m "Update frontend"
git push
```

如果使用直接上传:
```bash
cd public
wrangler pages deploy . --project-name=scrapitor
```

## 回滚

### Workers 回滚

```bash
cd workers
wrangler rollback
```

### Pages 回滚

1. Dashboard → Pages → 项目
2. Deployments 标签
3. 找到之前的部署
4. 点击 "Rollback to this deployment"

## 监控和分析

### Workers Analytics

Dashboard → Workers & Pages → 你的 Worker → Analytics

查看:
- 请求数量
- 成功率
- CPU 时间
- 错误日志

### Pages Analytics

Dashboard → Pages → 你的项目 → Analytics

查看:
- 页面浏览量
- 带宽使用
- 构建历史

## 安全最佳实践

1. **API 密钥管理**
   - 永远不要在前端硬编码 OpenRouter API Key
   - 让用户在客户端提供自己的密钥

2. **CORS 配置**
   - 在生产环境限制允许的来源
   - 修改 `workers/src/utils/cors.ts`

3. **速率限制**
   - 考虑添加速率限制防止滥用
   - 可使用 Cloudflare Workers KV 存储计数

4. **输入验证**
   - 已在 Workers 代码中实现基本验证
   - 可根据需要加强

## 技术支持

- Cloudflare 文档: https://developers.cloudflare.com/
- Scrapitor Issues: https://github.com/your-repo/issues
- Cloudflare Community: https://community.cloudflare.com/

## License

MIT
