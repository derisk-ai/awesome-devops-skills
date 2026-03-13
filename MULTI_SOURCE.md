# 多源收集策略

## 📡 数据来源

本项目从多个来源收集DevOps和Cloud相关的Skills/MCP仓库：

### 1. GitHub (主要来源)
- **API**: GitHub Search API v3
- **覆盖范围**: 全球最大的开源代码托管平台
- **搜索策略**: 
  - 关键词: devops, kubernetes, docker, terraform, mcp, skill, automation
  - 筛选条件: stars > 5 (新项目) 或 > 50 (成熟项目)
  - 排序: 最近更新时间
- **数据字段**: 仓库名、描述、stars、topics、更新时间

### 2. ClawHub (Skill Registry)
- **URL**: https://clawhub.ai
- **类型**: OpenClaw官方Skill市场
- **覆盖范围**: OpenClaw生态系统中的官方和社区skills
- **获取方式**: API/网页抓取
- **数据字段**: Skill名称、描述、版本、作者

### 3. 其他Registry (待扩展)
- **MCP Registry**: Model Context Protocol官方注册表
- **Awesome Lists**: GitHub上的awesome-devops等列表
- **Package Managers**: npm, pypi等包管理器中的相关工具

---

## 🔄 收集流程

```
每天 09:00 CST
    │
    ├─> 1. GitHub API搜索
    │      ├─> 执行多个搜索查询
    │      ├─> 筛选skill/mcp相关仓库
    │      └─> 获取详细信息
    │
    ├─> 2. ClawHub获取
    │      ├─> 访问ClawHub API
    │      ├─> 提取热门skills
    │      └─> 去重处理
    │
    ├─> 3. 数据聚合
    │      ├─> 合并多源数据
    │      ├─> 智能分类
    │      └─> 去重验证
    │
    └─> 4. 生成更新
           ├─> 更新README
           ├─> 保存数据
           └─> 创建PR
```

---

## 📊 数据字段

每个收集的仓库包含以下字段：

```json
{
  "repo": "owner/name",
  "name": "repository-name",
  "url": "https://github.com/owner/name",
  "description": "Repository description",
  "stars": 100,
  "discovered": "2026-02-27 09:00:00 CST",
  "source": "github|clawhub|other",
  "category": "mcp|kubernetes|cicd|..."
}
```

---

## 🎯 分类标准

自动分类到以下9个类别：

| 类别 | 关键词 |
|------|--------|
| **OpenClaw Skills** | openclaw, claw |
| **MCP Servers** | mcp, model-context-protocol |
| **Kubernetes** | kubernetes, k8s, helm |
| **CI/CD** | cicd, pipeline, jenkins, github-action, argo |
| **Infrastructure as Code** | terraform, pulumi, ansible, chef, puppet |
| **Monitoring & Observability** | prometheus, grafana, monitoring, observability |
| **Security** | security, trivy, falco, scan, vulnerability |
| **Cloud Platforms** | aws, azure, gcp, cloud, gcloud |
| **Other Tools** | 其他未分类 |

---

## ⚙️ 配置文件

### 环境变量

```bash
# GitHub Token (提高API限制)
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"

# 其他Registry Token (如有)
export CLAWHUB_TOKEN="xxx"
```

### 本地配置文件

```bash
# .github-token 文件
echo "ghp_xxxxxxxxxxxx" > .github-token
```

---

## 🚀 执行脚本

### 主收集脚本

```bash
./collect-multi-source.sh
```

功能：
- 从多个来源收集数据
- 智能分类和去重
- 生成README文档
- 创建Git分支和PR

### 手动执行

```bash
cd /Users/magic/workspace/github/derisk-ai/awesome-devops-skills
bash collect-multi-source.sh
```

---

## 📈 更新频率

| 来源 | 频率 | 说明 |
|------|------|------|
| GitHub | 每天一次 | 09:00 CST |
| ClawHub | 每天一次 | 与GitHub同步 |
| 其他 | 按需 | 待扩展 |

---

## 📝 待办事项

- [ ] 完善ClawHub API集成
- [ ] 添加MCP Registry支持
- [ ] 集成更多Skill市场
- [ ] 添加数据质量评分
- [ ] 实现增量更新优化

---

*最后更新: 2026-02-27*
