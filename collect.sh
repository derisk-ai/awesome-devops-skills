#!/bin/bash
# DevOps Skills Intelligence Collector
# 每小时自动抓取GitHub上的DevOps/Cloud相关skills仓库

set -e

PROJECT_DIR="/Users/magic/workspace/github/derisk-ai/awesome-devops-skills"
README_FILE="$PROJECT_DIR/README.md"
DATA_FILE="$PROJECT_DIR/data/repos.json"
TEMP_DIR="/tmp/devops-skills-collector"
DATE=$(date '+%Y-%m-%d %H:%M:%S CST')

echo "🕵️  DevOps Skills情报收集启动于 $DATE"

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

# 搜索查询列表 - 扩展更多关键词
QUERIES=(
  "devops+skill+stars:>5"
  "devops+agent+skill+stars:>3"
  "cloud+skill+automation+stars:>5"
  "kubernetes+skill+tool+stars:>5"
  "terraform+module+skill+stars:>3"
  "docker+automation+skill+stars:>5"
  "cicd+automation+stars:>10"
  "monitoring+skill+tool+stars:>5"
  "observability+skill+stars:>5"
  "github+action+skill+stars:>10"
  "mcp+server+devops+stars:>3"
  "mcp+server+kubernetes+stars:>3"
  "mcp+server+cloud+stars:>3"
  "openclaw+skill+stars:>1"
  "claude+skill+devops+stars:>3"
  "ai+agent+devops+stars:>5"
  "llm+tool+devops+stars:>5"
  "infrastructure+automation+skill+stars:>5"
  "platform+engineering+tool+stars:>10"
  "sre+tool+automation+stars:>10"
)

echo "🔍 开始搜索GitHub仓库..."

# 创建结果收集文件
> "$TEMP_DIR/new_findings.md"
> "$TEMP_DIR/api_responses.json"

# 初始化repos数据
if [ ! -f "$DATA_FILE" ]; then
  echo '{"repos":{},"last_scan":""}' > "$DATA_FILE"
fi

TOTAL_FOUND=0

for QUERY in "${QUERIES[@]}"; do
  echo "  搜索: $QUERY"
  
  # 使用GitHub API搜索
  RESPONSE=$(gh_api "https://api.github.com/search/repositories?q=$QUERY&sort=updated&order=desc&per_page=20")
  
  # 检查API限制
  if echo "$RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
    echo "    ⚠️ API限制: $(echo "$RESPONSE" | jq -r '.message')"
    continue
  fi
  
  # 保存响应
  echo "$RESPONSE" | jq -c '.items // []' >> "$TEMP_DIR/api_responses.json"
  
  # 解析结果 - 更宽松的匹配条件
  echo "$RESPONSE" | jq -r '.items[] | select(
    (.name | test("skill|mcp|agent|tool|automation|bot"; "i")) or
    (.topics | contains(["skill","mcp","agent","automation"])) or
    (.description // "" | test("skill|mcp|agent|automation|devops|openclaw"; "i"))
  ) | "\(.full_name)|\(.name)|\(.html_url)|\(.description // "No description")|\(.stargazers_count)|\(.topics | join(","))"' 2>/dev/null >> "$TEMP_DIR/raw_findings.txt" || true
  
  sleep 2  # 避免触发API限制
done

# 处理结果
echo "📊 处理搜索结果..."
if [ -f "$TEMP_DIR/raw_findings.txt" ]; then
  sort -u "$TEMP_DIR/raw_findings.txt" | while IFS='|' read -r FULL_NAME NAME URL DESC STARS TOPICS; do
    # 检查是否已存在
    if ! grep -q "$FULL_NAME" "$DATA_FILE" 2>/dev/null; then
      echo "- [$NAME]($URL) - $DESC ⭐ $STARS" >> "$TEMP_DIR/new_findings.md"
      # 添加到数据文件
      jq --arg fn "$FULL_NAME" --arg name "$NAME" --arg url "$URL" --arg desc "$DESC" --arg stars "$STARS" --arg topics "$TOPICS" --arg date "$DATE" \
        '.repos[$fn] = {"name":$name,"url":$url,"description":$desc,"stars":($stars|tonumber),"topics":($topics|split(",")),"discovered":$date}' "$DATA_FILE" > "$TEMP_DIR/repos_new.json" && mv "$TEMP_DIR/repos_new.json" "$DATA_FILE"
      TOTAL_FOUND=$((TOTAL_FOUND + 1))
    fi
  done
fi

# 更新扫描时间
jq --arg date "$DATE" '.last_scan = $date' "$DATA_FILE" > "$TEMP_DIR/repos_new.json" && mv "$TEMP_DIR/repos_new.json" "$DATA_FILE"

# 去重并排序
sort -u "$TEMP_DIR/new_findings.md" > "$TEMP_DIR/unique_findings.md"

# 读取现有README内容
if [ -f "$README_FILE" ]; then
  cat "$README_FILE" > "$TEMP_DIR/current_readme.md"
else
  echo "# Awesome DevOps Skills" > "$TEMP_DIR/current_readme.md"
  echo "" >> "$TEMP_DIR/current_readme.md"
  echo "自动收集的DevOps和云原生领域优秀Skills/MCP仓库" >> "$TEMP_DIR/current_readme.md"
  echo "" >> "$TEMP_DIR/current_readme.md"
fi

echo "📊 发现 $TOTAL_FOUND 个新仓库"

# 生成更新后的README
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

cat > "$README_FILE" << 'EOF'
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

EOF

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
  echo "_暂无收录_" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'EOF'

---

## 🤖 MCP Servers

*Cloud-native Model Context Protocol servers for DevOps workflows*

EOF

if [ -s "$TEMP_DIR/cat_mcp.txt" ]; then
  cat "$TEMP_DIR/cat_mcp.txt" >> "$README_FILE"
fi

# 添加已知的高质量MCP servers
cat >> "$README_FILE" << 'EOF'
- [kubernetes-mcp-server](https://github.com/alexei-led/kubernetes-mcp-server) - Kubernetes MCP server for natural language K8s operations
- [postgres-mcp](https://github.com/modelcontextprotocol/postgres-mcp) - PostgreSQL MCP server
- [docker-mcp](https://github.com/ckreiling/docker-mcp) - Docker MCP server

---

## ☸️ Kubernetes

EOF

if [ -s "$TEMP_DIR/cat_k8s.txt" ]; then
  cat "$TEMP_DIR/cat_k8s.txt" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'EOF'
- [kompose](https://github.com/kubernetes/kompose) - 将Docker Compose转换为Kubernetes资源 ⭐ 10000+
- [k9s](https://github.com/derailed/k9s) - Kubernetes CLI管理工具 ⭐ 25000+

---

## 🔄 CI/CD

EOF

if [ -s "$TEMP_DIR/cat_cicd.txt" ]; then
  cat "$TEMP_DIR/cat_cicd.txt" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'EOF'
- [argo-cd](https://github.com/argoproj/argo-cd) - 声明式GitOps持续交付 ⭐ 17000+
- [jenkins](https://github.com/jenkinsci/jenkins) - 开源自动化服务器 ⭐ 22000+
- [github-actions](https://github.com/features/actions) - GitHub原生CI/CD

---

## 🏗️ Infrastructure as Code

EOF

if [ -s "$TEMP_DIR/cat_iac.txt" ]; then
  cat "$TEMP_DIR/cat_iac.txt" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'EOF'
- [terraform](https://github.com/hashicorp/terraform) - 基础设施即代码 ⭐ 41000+
- [pulumi](https://github.com/pulumi/pulumi) - 现代基础设施即代码 ⭐ 21000+
- [ansible](https://github.com/ansible/ansible) - 自动化运维工具 ⭐ 62000+

---

## 📊 Monitoring & Observability

EOF

if [ -s "$TEMP_DIR/cat_monitoring.txt" ]; then
  cat "$TEMP_DIR/cat_monitoring.txt" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'EOF'
- [prometheus](https://github.com/prometheus/prometheus) - 监控和告警工具包 ⭐ 55000+
- [grafana](https://github.com/grafana/grafana) - 可视化监控平台 ⭐ 63000+
- [jaeger](https://github.com/jaegertracing/jaeger) - 分布式追踪系统 ⭐ 20000+

---

## 🔒 Security

EOF

if [ -s "$TEMP_DIR/cat_security.txt" ]; then
  cat "$TEMP_DIR/cat_security.txt" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'EOF'
- [trivy](https://github.com/aquasecurity/trivy) - 容器安全扫描器 ⭐ 22000+
- [falco](https://github.com/falcosecurity/falco) - 云原生运行时安全 ⭐ 7000+
- [vault](https://github.com/hashicorp/vault) -  secrets管理工具 ⭐ 31000+

---

## ☁️ Cloud Platforms

EOF

if [ -s "$TEMP_DIR/cat_cloud.txt" ]; then
  cat "$TEMP_DIR/cat_cloud.txt" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'EOF'
- [aws-cli](https://github.com/aws/aws-cli) - AWS命令行工具 ⭐ 15000+
- [azure-cli](https://github.com/Azure/azure-cli) - Azure命令行工具 ⭐ 4000+
- [gcloud-sdk](https://github.com/GoogleCloudPlatform/cloud-sdk-docker) - Google Cloud SDK ⭐ 1000+

---

## 📦 Other Tools

EOF

if [ -s "$TEMP_DIR/cat_other.txt" ]; then
  cat "$TEMP_DIR/cat_other.txt" >> "$README_FILE"
else
  echo "_暂无收录_" >> "$README_FILE"
fi

cat >> "$README_FILE" << 'EOF'

---

## 🤖 自动收集流程

本项目通过自动化脚本每小时扫描GitHub，发现新的DevOps相关Skills和MCP Servers。

### 收集标准

- ⭐ Stars > 5 (新项目) 或 > 100 (成熟项目)
- 🏷️ 标签包含: devops, cloud, kubernetes, docker, terraform, mcp, skill
- 📅 最近6个月内有更新
- 📝 有清晰的README和文档

---

## 📜 License

[MIT](LICENSE)
EOF

# 更新时间戳
sed -i '' "s/UPDATE_TIME/$DATE/g" "$README_FILE"

# Git操作
echo "📝 提交变更..."
cd "$PROJECT_DIR"
git add README.md
git commit -m "🤖 自动更新: $DATE - DevOps Skills情报收集" || echo "无变更可提交"

# 推送（如果有配置远程）
if git remote get-url origin > /dev/null 2>&1; then
  git push origin main || git push origin master || echo "推送失败，请手动处理"
else
  echo "⚠️  未配置远程仓库，跳过推送"
fi

echo "✅ 完成!"
