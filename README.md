# Kali CTF 开发环境

面向小团队的 Docker 开发环境：精简 Kali、Claude Code 2.1.238、TSec Benchmark Python SDK 0.1.2，以及常用编译、调试和网络工具。源码在本机编辑，在 Linux 容器内运行，可通过 VS Code 连接，后续构建独立的比赛提交镜像。

## 1. 安装依赖

macOS/Windows 安装并启动 Docker Desktop；Linux 可使用 Docker Engine。需要 Git、Docker Buildx、Bash 和 Python 3。本项目的 `ctf` 脚本适用于 macOS/Linux；Windows 建议在 WSL2 中使用。

```bash
docker version
docker buildx version
python3 --version
```

使用 VS Code 时安装 Dev Containers 扩展，并确保 `code` 命令在 PATH 中：

```bash
code --install-extension ms-vscode-remote.remote-containers
```

## 2. 获取项目并配置凭证

```bash
git clone https://github.com/CBx-2023/ctf-kali.git
cd ctf-kali
cp .env.example .env
chmod 600 .env
```

在编辑器中填写 `.env`，使用个人模型服务的地址、凭证和模型名称：

```dotenv
ANTHROPIC_BASE_URL=你的模型服务地址
ANTHROPIC_AUTH_TOKEN=你的模型凭证
ANTHROPIC_MODEL=服务商支持的模型名称
BENCHMARK_TOKEN=
BENCHMARK_BASE_URL=
CTF_TASK_TIMEOUT=600
CTF_TOTAL_TIMEOUT=21000
CTF_MAX_BUDGET_USD=2
```

使用 Docker 环境文件格式 `KEY=value`，不要加 `export` 或包裹引号。若服务商使用 API Key 鉴权，可改用其要求的 `ANTHROPIC_API_KEY`。模型服务需要兼容 Claude Code 所需的 Anthropic 接口；仅兼容 OpenAI 接口并不保证可用。

比赛变量在获取平台本地接入配置后填写。每位队友使用自己的 `.env`；该文件不会进入 Git 或镜像。

## 3. 安装 ctf 命令并构建

在项目根目录执行：

```bash
mkdir -p "$HOME/.local/bin"
ln -s "$(pwd)/bin/ctf" "$HOME/.local/bin/ctf"
```

确保 shell 的 PATH 包含 `~/.local/bin`，必要时在 `~/.zshrc` 或 `~/.bashrc` 加入：

```bash
export PATH="$HOME/.local/bin:$PATH"
```

也可以跳过全局命令安装，使用 `./bin/ctf` 代替 `ctf`。

```bash
ctf build
ctf check
ctf test
```

构建会下载当前架构的 Linux Claude Code 并核对官方 SHA256，安装固定版本 Python 依赖，创建普通用户 `ctf`。不需要桌面、特权模式或 Docker socket。

`prompts/override.md` 按原文件保留；Claude 包装器每次调用均通过 `--append-system-prompt-file` 附加该文件。

## 4. 启动 Claude 与 VS Code

```bash
ctf                 # 交互启动 Claude，工作目录 /workspace
ctf shell           # 容器 Bash
ctf code            # VS Code 连接持久开发容器
ctf claude --version
ctf claude -p "检查当前目录结构"
```

首次进入 Claude 按界面完成主题和工作目录确认。VS Code 左下角应显示容器 `ctf-kali-dev`。也可在 VS Code 打开项目，执行 Dev Containers: Reopen in Container；该方式会创建单独的开发容器。

| 本机路径 | 容器路径 |
| --- | --- |
| 项目根目录 | `/workspaces/ctf-kali` |
| `workspace/` | `/workspace` |

Python 解释器为 `/opt/venv/bin/python`。容器内也有 `ctf`，支持 `ctf`、`ctf -p "任务"`、`ctf check` 和 `ctf run`。

## 5. 日常协作

源码通过目录挂载同步。每人使用自己的代码分支和 Docker 引擎，合并前运行离线检查和调度测试。

| 修改内容 | 操作 |
| --- | --- |
| Python 源码 | 本机 `ctf run` 读取当前源码 |
| `.env` | `ctf recreate`，然后重新连接 VS Code |
| Dockerfile、依赖、提示词或容器脚本 | `ctf build`、`ctf recreate`，然后 `ctf code` |

`ctf recreate` 重建容器，挂载源码和 workspace 文件保留。`ctf down` 停止开发容器。

当前固定容器名为 `ctf-kali-dev`，用户数据卷为 `ctf-kali-home`。多人共用同一 Docker 引擎或需要多份项目同时运行时，应先修改 `bin/ctf` 中的容器名和数据卷名。

不要提交 `.env`、任务日志、运行数据或导出的镜像；`.gitignore` 已排除这些内容。

## 6. 本地接入比赛

接入说明：[TSecBench 本地模式](https://tsecbench.zc.tencent.com/benchmark/prepare/4?mode=local&evaluation_type=agent)。

获取平台配置，在宿主机连接平台 VPN，并填写 `.env` 中的两个比赛变量：

```bash
ctf recreate
ctf doctor          # 检查容器到 VPN 和平台 API 的连通性
ctf run             # 调用模型、执行任务并提交结果
```

SDK 不负责建立 VPN。宿主机连通不代表容器一定连通；如果 doctor 失败，检查 Docker/VPN 路由及平台配置。

调度程序串行列题、启动靶场、调用 Claude、解析结构化结果、提交并关闭靶场。模型子进程不继承 `BENCHMARK_*` 环境变量。每题超时默认 600 秒，模型预算默认 2 美元；实际费用受服务商计费和预算统计支持情况影响。总调度时间默认 21000 秒，每题开始时根据剩余时间限制执行时间。

日志位于 `workspace/runs/`。每题失败后尝试关闭靶场，关闭失败则停止程序，避免持续占用活跃名额。当前是串行基线，尚未完成真实比赛验证。

## 7. 打包提交

```bash
ctf pack
```

默认构建 Linux AMD64 镜像并导出 `dist/agent-amd64.tar.gz`。如果平台确认使用 ARM64：

```bash
CTF_PLATFORM=linux/arm64 ctf pack
```

打包会重建镜像、进行断网安装检查、导出 gzip 镜像包，并检查是否超过 3GB。镜像启动入口自动运行调度程序，包含源码、提示词和依赖，不依赖本机源码挂载。密钥和动态配置在比赛平台运行时注入。

[托管模式要求](https://tsecbench.zc.tencent.com/benchmark/prepare/4?mode=hosted&evaluation_type=agent)：无法直接访问公网，模型调用需要使用平台白名单网关。按页面规则将允许的域名追加 `.tsecbench.gw` 并使用 `http`；这不适用于任意自定义域名。提交前确认 CPU 架构、Anthropic 协议兼容性及最新平台限制，并先跑通本地模式。不要内置针对题目的历史解题记忆。

## 文件与验证

```text
Dockerfile              Kali、Claude 和必要工具
requirements.lock       Python 依赖版本
bin/ctf                 本机管理命令
docker/                 容器入口与 Claude/ctf 包装器
app/runner.py           比赛调度程序
app/check.py            离线安装检查
prompts/override.md     原样保留的提示词
tests/                  调度关键行为测试
.devcontainer/          VS Code 配置
workspace/              本地任务文件与日志（不提交）
```

Kali 基础镜像通过 digest 固定，但 APT 软件源仍是 rolling，重新构建时系统包版本可能变化。构建时包清单保存在 `/usr/local/share/ctf-system-packages.txt`。

初始 ARM64 镜像约 391MB，实际大小随架构和依赖变化。已验证 Claude 2.1.238 交互启动、override 文件一致性、SDK 安装，以及超时进程清理、输出解析和平台凭证变量隔离测试。离线检查不代表模型服务、VPN 或真实比赛已验证。
