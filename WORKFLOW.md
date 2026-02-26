# 分支工作流说明

## 工作流程

本项目采用 **分支-based 工作流**，所有自动更新都通过新建分支提交，然后创建 Pull Request 合并到 main 分支。

## 分支命名规范

自动收集脚本创建的分支名称格式：

```
auto-update/YYYY-MM-DD-HHMMSS
```

例如：`auto-update/2026-02-26-233045`

## 手动创建分支

如需手动提交更新，请使用以下命名格式：

```
update/YYYY-MM-DD-brief-description
```

例如：
- `update/2026-02-26-english-readme`
- `update/2026-02-27-add-mcp-servers`

## 提交步骤

### 1. 创建新分支

```bash
git checkout -b update/YYYY-MM-DD-description
```

### 2. 进行修改

编辑 README.md、README_EN.md 或其他文件

### 3. 提交变更

```bash
git add .
git commit -m "描述信息"
```

### 4. 推送到远程

```bash
git push -u origin update/YYYY-MM-DD-description
```

### 5. 创建 Pull Request

访问 GitHub 仓库页面，点击 "Compare & pull request" 按钮创建 PR

## 自动收集任务

- **任务名称**: devops-skills-collector
- **执行频率**: 每小时
- **自动创建分支**: 是（格式：auto-update/日期-时间）
- **自动推送**: 是
- **需要手动操作**: 创建 Pull Request 并合并

## 文件说明

| 文件 | 说明 |
|------|------|
| `README.md` | 中文版主文档 |
| `README_EN.md` | 英文版文档 |
| `collect.sh` | 自动收集脚本 |
| `data/repos.json` | 已收集仓库数据 |
| `.github-token` | GitHub API Token（可选，提高API限制） |

## 注意事项

1. 不要直接推送到 `main` 分支
2. 所有变更都应通过 Pull Request 合并
3. 自动收集脚本会自动切换回 main 分支
4. 如遇到推送失败，请检查 SSH 密钥配置
