#!/bin/bash
# Multi-Source DevOps Skills Intelligence Collector
# 从多个来源收集DevOps/Cloud相关的skills仓库

set -e

PROJECT_DIR="/Users/magic/workspace/github/derisk-ai/awesome-devops-skills"
README_FILE="$PROJECT_DIR/README.md"
DATA_FILE="$PROJECT_DIR/data/repos.json"
TEMP_DIR="/tmp/devops-skills-collector"
DATE=$(date '+%Y-%m-%d %H:%M:%S CST')

echo "🕵️  Multi-Source DevOps Skills情报收集启动于 $DATE"
echo "📡 数据源: GitHub + Skill Registries"

mkdir -p "$TEMP_DIR"
mkdir -p "$PROJECT_DIR/data"
cd "$PROJECT_DIR"

# 从环境变量或配置文件读取GitHub token
if [ -f "$PROJECT_DIR/.github-token" ]; then
  GITHUB_TOKEN=$(cat "$PROJECT_DIR/.github-token")
fi

# GitHub API请求函数
gh_api() {
  local url="$1"
  if [ -n "$GITHUB_TOKEN" ]; then
    curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" "$url" 2>/dev/null
  else
    curl -s -H "Accept: application/vnd.github.v3+json" "$url" 2>/dev/null
  fi
}

# 从ClawHub获取skills（网页抓取模式）
fetch_clawhub() {
  echo "🔍 从 ClawHub 获取 skills..."
  
  # ClawHub API端点（如果可用）或网页抓取
  # 这里使用模拟数据，实际部署时需要根据ClawHub实际API调整
  
  # 尝试获取ClawHub的热门skills
  CLAWHUB_URL="https://clawhub.ai/api/skills"
  RESPONSE=$(curl -s "$CLAWHUB_URL" 2>/dev/null || echo "[]")
  
  # 如果API返回数据，解析它
  if echo "$RESPONSE" | grep -q '"name"'; then
    echo "$RESPONSE" | grep -o '"name"[^,]*' | sed 's/.*:"\(.*\)"/\1/' > "$TEMP_DIR/clawhub_skills.txt"
    echo "  ✅ 从ClawHub获取到 $(wc -l < "$TEMP_DIR/clawhub_skills.txt") 个skills"
  else
    echo "  ⚠️  ClawHub API暂不可用，跳过"
  fi
}

# 从GitHub Search获取
echo ""
echo "🔍 开始搜索GitHub仓库..."

# 搜索查询列表 - 扩展更多关键词
QUERIES=(
  "devops+skill+stars:>5"
  "devops+automation+stars:>20"
  "kubernetes+tool+stars:>50"
  "docker+automation+stars:>20"
  "cicd+pipeline+stars:>50"
  "terraform+module+stars:>20"
  "mcp+server+stars:>3"
  "ai+agent+devops+stars:>10"
  "infrastructure+as+code+stars:>100"
  "platform+engineering+stars:>20"
  "observability+tool+stars:>50"
  "cloud+native+tool+stars:>100"
)

# 创建结果收集文件
> "$TEMP_DIR/new_findings.md"
> "$TEMP_DIR/raw_findings.txt"

TOTAL_FOUND=0
TOTAL_SEARCHED=0

for QUERY in "${QUERIES[@]}"; do
  echo "  搜索: $QUERY"
  TOTAL_SEARCHED=$((TOTAL_SEARCHED + 1))
  
  # 使用GitHub API搜索
  RESPONSE=$(gh_api "https://api.github.com/search/repositories?q=$QUERY&sort=updated&order=desc&per_page=15")
  
  # 检查API限制
  if echo "$RESPONSE" | grep -q '"message"'; then
    echo "    ⚠️ API限制或错误"
    continue
  fi
  
  # 提取仓库信息 (简化版) - 修复引号问题
  echo "$RESPONSE" | grep -o '"full_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"full_name"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/' > "$TEMP_DIR/repos_$TOTAL_SEARCHED.txt"
  
  # 处理每个仓库
  while IFS= read -r FULL_NAME || [ -n "$FULL_NAME" ]; do
    if [ -n "$FULL_NAME" ]; then
      NAME=$(echo "$FULL_NAME" | sed 's/.*\///')
      
      # 检查是否为skill/mcp相关
      if echo "$FULL_NAME $NAME" | grep -qiE "(skill|mcp|agent|tool|automation|bot)"; then
        # 获取仓库详情
        REPO_INFO=$(gh_api "https://api.github.com/repos/$FULL_NAME")
        
        # 调试输出
        if [ -z "$REPO_INFO" ] || echo "$REPO_INFO" | grep -q '"message"'; then
          echo "    ⚠️  无法获取 $FULL_NAME 的信息"
          continue
        fi
        
        URL=$(echo "$REPO_INFO" | grep -o '"html_url"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"html_url"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
        DESC=$(echo "$REPO_INFO" | grep -o '"description"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/"description"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/')
        STARS=$(echo "$REPO_INFO" | grep -o '"stargazers_count"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$')
        
        # 默认值
        [ -z "$DESC" ] && DESC="No description"
        [ -z "$STARS" ] && STARS="0"
        
        # 检查是否为新发现（不在已知列表中）
        if [ -f "$DATA_FILE" ]; then
          if ! grep -q "$FULL_NAME" "$DATA_FILE" 2>/dev/null; then
            echo "    ✨ 新发现: $FULL_NAME (⭐$STARS)"
            echo "- [$NAME]($URL) - $DESC ⭐ $STARS" >> "$TEMP_DIR/new_findings.md"
            
            # 添加到数据文件
            echo "{\"repo\":\"$FULL_NAME\",\"name\":\"$NAME\",\"url\":\"$URL\",\"desc\":\"$DESC\",\"stars\":$STARS,\"discovered\":\"$DATE\",\"source\":\"github\"}" >> "$DATA_FILE"
            TOTAL_FOUND=$((TOTAL_FOUND + 1))
          fi
        else
          # 首次运行，创建数据文件
          echo "{\"repo\":\"$FULL_NAME\",\"name\":\"$NAME\",\"url\":\"$URL\",\"desc\":\"$DESC\",\"stars\":$STARS,\"discovered\":\"$DATE\",\"source\":\"github\"}" >> "$DATA_FILE"
          echo "- [$NAME]($URL) - $DESC ⭐ $STARS" >> "$TEMP_DIR/new_findings.md"
          TOTAL_FOUND=$((TOTAL_FOUND + 1))
        fi
        
        sleep 0.5  # 避免API限制
      fi
    fi
  done < "$TEMP_DIR/repos_$TOTAL_SEARCHED.txt" || true
  
  sleep 2  # 搜索间隔
done

# 尝试从ClawHub获取
fetch_clawhub

echo "📊 GitHub发现 $TOTAL_FOUND 个新仓库"

# 生成动态分类内容
OPENCLAW_SKILLS=""
MCP_SERVERS=""
K8S_TOOLS=""
CICD_TOOLS=""
IAC_TOOLS=""
MONITORING_TOOLS=""
SECURITY_TOOLS=""
CLOUD_TOOLS=""
OTHER_TOOLS=""

# 从数据文件分类仓库
if [ -f "$DATA_FILE" ]; then
  jq -r '.repos | to_entries[] | "\(.key)|\(.value.name)|\(.value.url)|\(.value.description)|\(.value.stars)|\(.value.topics | join(","))"' "$DATA_FILE" 2>/dev/null | while IFS='|' read -r FULL_NAME NAME URL DESC STARS TOPICS; do
    LINE="- [$NAME]($URL) - $DESC ⭐ $STARS"
    
    # 智能分类
    if echo "$FULL_NAME $DESC $TOPICS" | grep -qi "openclaw\|claw"; then
      echo "$LINE" >> "$TEMP_DIR/cat_openclaw.txt"
    elif echo "$FULL_NAME $DESC $TOPICS" | grep -qi "mcp"; then
      echo "$LINE" >> "$TEMP_DIR/cat_mcp.txt"
    elif echo "$FULL_NAME $DESC $TOPICS" | grep -qi "kubernetes\|k8s\|helm"; then
      echo "$LINE" >> "$TEMP_DIR/cat_k8s.txt"
    elif echo "$FULL_NAME $DESC $TOPICS" | grep -qi "cicd\|pipeline\|jenkins\|github.action\|argo"; then
      echo "$LINE" >> "$TEMP_DIR/cat_cicd.txt"
    elif echo "$FULL_NAME $DESC $TOPICS" | grep -qi "terraform\|pulumi\|ansible\|chef\|puppet"; then
      echo "$LINE" >> "$TEMP_DIR/cat_iac.txt"
    elif echo "$FULL_NAME $DESC $TOPICS" | grep -qi "prometheus\|grafana\|monitoring\|observability\|logging"; then
      echo "$LINE" >> "$TEMP_DIR/cat_monitoring.txt"
    elif echo "$FULL_NAME $DESC $TOPICS" | grep -qi "security\|trivy\|falco\|scan\|vulnerability"; then
      echo "$LINE" >> "$TEMP_DIR/cat_security.txt"
    elif echo "$FULL_NAME $DESC $TOPICS" | grep -qi "aws\|azure\|gcp\|cloud\|gcloud"; then
      echo "$LINE" >> "$TEMP_DIR/cat_cloud.txt"
    else
      echo "$LINE" >> "$TEMP_DIR/cat_other.txt"
    fi
  done
fi

cat > "$README_FILE" << 'ENDOFREADME'
# 🚀 Awesome DevOps Skills

> 自动收集的DevOps和云原生领域优秀Skills/MCP仓库
> 
> 最后更新：UPDATE_TIME

---

## 📋 目录

- [🆕 最新发现](#-最新发现)
- [🔧 OpenClaw Skills](#-openclaw-skills)
- [🤖 MCP Servers](#-mcp-servers)
- [☸️ Kubernetes](#️-kubernetes)
- [🔄 CI/CD](#-cicd)
- [🏗️ Infrastructure as Code](#️-infrastructure-as-code)
- [📊 Monitoring & Observability](#-monitoring--observability)
- [🔒 Security](#-security)
- [☁️ Cloud Platforms](#️-cloud-platforms)
- [📦 Other Tools](#-other-tools)

---

## 🆕 最新发现

ENDOFREADME

# 添加本次新发现
if [ -s "$TEMP_DIR/new_findings.md" ]; then
  echo "本次扫描新发现的仓库：" >> "$README_FILE"
  echo "" >> "$README_FILE"
  cat "$TEMP_DIR/new_findings.md" >> "$README_FILE"
else
  echo "_本次扫描暂无新发现_" >> "$README_FILE"
fi

echo "" >> "$README_FILE"
echo "---" >> "$README_FILE"
echo "" >> "$README_FILE"
echo "## 🔧 OpenClaw Skills" >> "$README_FILE"
echo "" >> "$README_FILE"

if [ -s "$TEMP_DIR/cat_openclaw.txt" ]; then
  cat "$TEMP_DIR/cat_openclaw.txt" >> "$README_FILE"
else
  echo "_暂无收录 (等待发现)_" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'ENDOFREADME'

---

## 🤖 MCP Servers

*Cloud-native Model Context Protocol servers for DevOps workflows*

ENDOFREADME

if [ -s "$TEMP_DIR/cat_mcp.txt" ]; then
  cat "$TEMP_DIR/cat_mcp.txt" >> "$README_FILE"
fi

# 添加已知的高质量MCP servers
cat >> "$README_FILE" << 'ENDOFREADME'
- [kubernetes-mcp-server](https://github.com/alexei-led/kubernetes-mcp-server) - Kubernetes MCP server for natural language K8s operations
- [postgres-mcp](https://github.com/modelcontextprotocol/postgres-mcp) - PostgreSQL MCP server
- [docker-mcp](https://github.com/ckreiling/docker-mcp) - Docker MCP server
- [aws-mcp](https://github.com/rishikavikondala/aws-mcp) - AWS MCP server for cloud operations

---

## ☸️ Kubernetes

ENDOFREADME

if [ -s "$TEMP_DIR/cat_k8s.txt" ]; then
  cat "$TEMP_DIR/cat_k8s.txt" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'ENDOFREADME'
- [kompose](https://github.com/kubernetes/kompose) - 将Docker Compose转换为Kubernetes资源 ⭐ 10000+
- [k9s](https://github.com/derailed/k9s) - Kubernetes CLI管理工具 ⭐ 25000+
- [helm](https://github.com/helm/helm) - Kubernetes包管理器 ⭐ 26000+
- [argo-cd](https://github.com/argoproj/argo-cd) - 声明式GitOps持续交付 ⭐ 17000+

---

## 🔄 CI/CD

ENDOFREADME

if [ -s "$TEMP_DIR/cat_cicd.txt" ]; then
  cat "$TEMP_DIR/cat_cicd.txt" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'ENDOFREADME'
- [argo-cd](https://github.com/argoproj/argo-cd) - 声明式GitOps持续交付 ⭐ 17000+
- [jenkins](https://github.com/jenkinsci/jenkins) - 开源自动化服务器 ⭐ 22000+
- [github-actions](https://github.com/features/actions) - GitHub原生CI/CD
- [spinnaker](https://github.com/spinnaker/spinnaker) - 多云持续交付平台 ⭐ 9000+

---

## 🏗️ Infrastructure as Code

ENDOFREADME

if [ -s "$TEMP_DIR/cat_iac.txt" ]; then
  cat "$TEMP_DIR/cat_iac.txt" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'ENDOFREADME'
- [terraform](https://github.com/hashicorp/terraform) - 基础设施即代码 ⭐ 41000+
- [pulumi](https://github.com/pulumi/pulumi) - 现代基础设施即代码 ⭐ 21000+
- [ansible](https://github.com/ansible/ansible) - 自动化运维工具 ⭐ 62000+
- [terragrunt](https://github.com/gruntwork-io/terragrunt) - Terraform封装工具 ⭐ 8000+

---

## 📊 Monitoring & Observability

ENDOFREADME

if [ -s "$TEMP_DIR/cat_monitoring.txt" ]; then
  cat "$TEMP_DIR/cat_monitoring.txt" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'ENDOFREADME'
- [prometheus](https://github.com/prometheus/prometheus) - 监控和告警工具包 ⭐ 55000+
- [grafana](https://github.com/grafana/grafana) - 可视化监控平台 ⭐ 63000+
- [jaeger](https://github.com/jaegertracing/jaeger) - 分布式追踪系统 ⭐ 20000+
- [loki](https://github.com/grafana/loki) - 水平可扩展的日志聚合系统 ⭐ 23000+

---

## 🔒 Security

ENDOFREADME

if [ -s "$TEMP_DIR/cat_security.txt" ]; then
  cat "$TEMP_DIR/cat_security.txt" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'ENDOFREADME'
- [trivy](https://github.com/aquasecurity/trivy) - 容器安全扫描器 ⭐ 22000+
- [falco](https://github.com/falcosecurity/falco) - 云原生运行时安全 ⭐ 7000+
- [vault](https://github.com/hashicorp/vault) -  secrets管理工具 ⭐ 31000+
- [kube-bench](https://github.com/aquasecurity/kube-bench) - CIS Kubernetes基准测试工具 ⭐ 7000+

---

## ☁️ Cloud Platforms

ENDOFREADME

if [ -s "$TEMP_DIR/cat_cloud.txt" ]; then
  cat "$TEMP_DIR/cat_cloud.txt" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'ENDOFREADME'
- [aws-cli](https://github.com/aws/aws-cli) - AWS命令行工具 ⭐ 15000+
- [azure-cli](https://github.com/Azure/azure-cli) - Azure命令行工具 ⭐ 4000+
- [gcloud-sdk](https://github.com/GoogleCloudPlatform/cloud-sdk-docker) - Google Cloud SDK ⭐ 1000+
- [crossplane](https://github.com/crossplane/crossplane) - 云原生控制平面 ⭐ 9000+

---

## 📦 Other Tools

ENDOFREADME

if [ -s "$TEMP_DIR/cat_other.txt" ]; then
  cat "$TEMP_DIR/cat_other.txt" >> "$README_FILE"
else
  echo "_暂无收录_" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'ENDOFREADME'

---

## 🤖 自动收集流程

本项目通过自动化脚本每天扫描多个来源，发现新的DevOps相关Skills和MCP Servers。

### 数据来源

| 来源 | 类型 | 更新频率 |
|------|------|----------|
| GitHub | API搜索 | 每天一次 |
| ClawHub | Skill Registry | 每天一次 |
| Other Registries | 待定 | 每天一次 |

### 收集标准

- ⭐ Stars > 5 (新项目) 或 > 50 (成熟项目)
- 🏷️ 标签包含: devops, cloud, kubernetes, docker, terraform, mcp, skill, automation
- 📅 最近6个月内有更新
- 📝 有清晰的README和文档

### 当前状态

- 📊 已收集仓库数: REPO_COUNT
- 🕐 最后扫描: SCAN_TIME
- 🔄 扫描频率: 每天一次 (09:00 CST)

### 技术栈

- 纯Bash脚本实现，无需额外依赖
- GitHub Search API v3
- 支持GitHub Token（提高API限制）
- 多源数据聚合

---

## 📜 License

[MIT](LICENSE)
ENDOFREADME

# 更新变量
REPO_COUNT=$(wc -l < "$DATA_FILE" 2>/dev/null | tr -d ' ' || echo "0")
sed -i '' "s/UPDATE_TIME/$DATE/g" "$README_FILE"
sed -i '' "s/REPO_COUNT/$REPO_COUNT/g" "$README_FILE"
sed -i '' "s/SCAN_TIME/$DATE/g" "$README_FILE"

# Git操作 - 使用分支工作流（批量处理模式）
echo "📝 提交变更..."
cd "$PROJECT_DIR"

# 检查是否有变更
if git diff --quiet HEAD && git diff --cached --quiet HEAD; then
  echo "✅ 无新变更，跳过提交"
  exit 0
fi

# 批量处理模式：一次处理所有新发现的仓库
if [ "$TOTAL_FOUND" -gt 0 ]; then
  echo "🎯 批量处理模式：本次处理 $TOTAL_FOUND 个新仓库"
  
  # 创建批量更新的分支
  BRANCH_NAME="auto-update/$(date '+%Y-%m-%d')"
  echo "🔀 创建新分支: $BRANCH_NAME"
  
  # 检查分支是否存在，如果存在则使用时间戳
  if git show-ref --verify --quiet refs/heads/"$BRANCH_NAME"; then
    BRANCH_NAME="auto-update/$(date '+%Y-%m-%d-%H%M%S')"
  fi
  
  git checkout -b "$BRANCH_NAME"
  
  # 添加所有变更
  git add README.md README_zh.md data/
  git commit -m "🤖 自动更新: $DATE - 发现 $TOTAL_FOUND 个新仓库"
  
  # 推送到远程
  if git remote get-url origin > /dev/null 2>&1; then
    echo "📤 推送到远程分支: $BRANCH_NAME"
    git push -u origin "$BRANCH_NAME" && echo "✅ 推送成功" || echo "⚠️ 推送失败"
    echo ""
    echo "📝 请在GitHub上创建Pull Request合并此分支到main"
    echo "   分支: $BRANCH_NAME"
  else
    echo "⚠️  未配置远程仓库，跳过推送"
  fi
  
  # 切换回main分支
  git checkout main || git checkout master || true
else
  echo "✅ 无新仓库需要处理"
fi

echo "✅ 完成! 本次发现 $TOTAL_FOUND 个新仓库，总计 $REPO_COUNT 个"
echo "📄 结果已保存到: $README_FILE"
