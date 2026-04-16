# hivequeen

English | [中文](README.zh.md)

fork 即继承，clone 即连接，所有 agent 共用同一个大脑。git 原生记忆协议，无需插件，无需服务器。

---

## 工作原理

```
hivequeen 仓库（你的 fork）
├── queen/          ← 只读规则与策略（由你维护）
├── agents/         ← 每个 agent 只写自己的目录
├── shared/         ← 所有 agent 的编译记忆（只读）
└── projects/       ← 项目上下文文件
```

每台 clone 了你 fork 的机器都共享同一个大脑。
每个 agent 实例只写自己的 `agents/<agent-id>/` 目录——永远不会产生冲突。

```
session 开始  →  git pull  →  加载上下文
session 结束  →  git commit agents/<id>/  →  git push
```

---

## 快速开始

### 1. 创建你的私有母体

点击 GitHub 上的 **Use this template → Create a new repository**，
visibility 选 **Private** — 你的记忆只属于你。

> **为什么不用 Fork？** Fork 默认是公开的，且与上游仓库保持关联。
> 从模板创建的私有仓库完全归你所有。

### 2. Clone 到每台机器

```bash
git clone git@github.com:<你的用户名>/hivequeen.git ~/hivequeen
```

### 3. 安装到你的 agent 工具

**Claude Code（macOS / Linux）**
```bash
bash ~/hivequeen/scripts/install-claude.sh
```

**Claude Code（Windows）**
```powershell
.\hivequeen\scripts\install-claude.ps1
```

**Codex（macOS / Linux）**
```bash
bash ~/hivequeen/scripts/install-codex.sh
```

**Codex（Windows）**
```powershell
.\hivequeen\scripts\install-codex.ps1
```

**OpenClaw（macOS / Linux）**
```bash
bash ~/hivequeen/scripts/install-openclaw.sh
```

**OpenClaw（Windows）**
```powershell
.\hivequeen\scripts\install-openclaw.ps1
```

**Hermes Agent（macOS / Linux）**
```bash
bash ~/hivequeen/scripts/install-hermes.sh
```

**Hermes Agent（Windows）**
```powershell
.\hivequeen\scripts\install-hermes.ps1
```

每台机器都执行一次。相同的 fork，不同的 agent ID，共享同一个大脑。

---

## 自定义

### 你的规则
编辑 `queen/agent-rules.md` — 适用于所有 agent 的行为边界。

### 你的策略
编辑 `queen/strategy.md` — 当前目标与决策方向。

### 你的项目
添加 `projects/<项目名>.md` — 处理该项目时自动加载的上下文。

---

## 编译共享记忆

当各 agent 积累了足够记忆后，将其编译到 `shared/memory.md`：

```bash
bash ~/hivequeen/scripts/compile.sh
```

脚本聚合所有 `agents/*/memory.md` 并推送结果。
所有 agent 在下次 `git pull` 时自动同步。

---

## 目录结构

```
hivequeen/
├── AGENTS.md                   通用 bootstrap（Codex、OpenClaw 等）
├── CLAUDE.md                   Claude Code 专用 bootstrap
├── SOUL.md                     人格文件（OpenClaw、Hermes 读取）
├── queen/
│   ├── agent-rules.md          行为规则 — agent 只读
│   └── strategy.md             决策方向 — agent 只读
├── agents/
│   └── <工具>-<主机名>/
│       └── memory.md           该 agent 的私有记忆
├── shared/
│   └── memory.md               跨 agent 编译记忆
├── projects/
│   └── <项目>.md               项目上下文
└── scripts/
    ├── install-claude.sh / .ps1
    ├── install-codex.sh  / .ps1
    ├── install-openclaw.sh / .ps1
    ├── install-hermes.sh / .ps1
    ├── compile.sh
    └── update.sh
```

---

## 文件行数限制

每个文件有行数上限，超出后拆分为 topic 文件，原文件改为带链接的索引。

| 文件 | 最大行数 |
|---|---|
| `queen/agent-rules.md` | 80 |
| `queen/strategy.md` | 80 |
| `agents/<id>/memory.md` | 200 |
| `shared/memory.md` | 500 |
| `projects/<name>.md` | 150 |

**示例 — `agents/claude-macbook/memory.md` 达到上限后拆分：**

```
agents/claude-macbook/
├── memory.md          ← 变为索引
├── user_profile.md
├── feedback_collab.md
└── project_hivequeen.md
```

拆分后的 `memory.md`：
```markdown
# MEMORY — claude-macbook

- [用户档案](user_profile.md) — 角色、技术栈、偏好
- [协作习惯](feedback_collab.md) — 工作方式、修正记录
- [项目：hivequeen](project_hivequeen.md) — 目标、决策
```

agent 先读索引，按需跟进相关 topic 文件。

---

## 为什么不会产生冲突？

每个 agent 独占 `agents/` 下的一个目录，没有两个 agent 会写同一个文件。正常使用下，git 冲突从结构上就不可能发生。

| 路径 | 谁写 | 可能冲突？ |
|---|---|---|
| `queen/` | 你（人工） | 不会 |
| `agents/<id>/` | 仅该 agent | 不会 |
| `shared/` | 仅 `compile.sh` | 不会 |

---

## 支持的工具

| 工具 | 入口文件 | 安装方式 |
|---|---|---|
| Claude Code | `~/.claude/CLAUDE.md` | `bash scripts/install-claude.sh` |
| Codex | `~/.codex/instructions.md` | `bash scripts/install-codex.sh` |
| OpenClaw | `~/.openclaw/workspace/AGENTS.md` | `bash scripts/install-openclaw.sh` |
| Hermes Agent | `~/.hermes/SOUL.md` | `bash scripts/install-hermes.sh` |
| Gemini CLI | `GEMINI.md` | `ln -s AGENTS.md GEMINI.md` |
| Cursor | `.cursor/rules/` | 添加软链接 |
| Windsurf | `.windsurf/rules/` | 添加软链接 |
| Cline | `.clinerules/` | 添加软链接 |
| GitHub Copilot | `.github/copilot-instructions.md` | 添加软链接 |

为任何支持 markdown 配置文件的工具添加支持：
```bash
ln -s AGENTS.md <工具配置路径>
```

---

## 跟踪上游更新

当 hivequeen 发布新版本时，用以下命令把协议层同步到你的私有母体：

```bash
bash ~/my-queen/scripts/update.sh
```

只更新 `scripts/`、`AGENTS.md`、`CLAUDE.md`、`SOUL.md` 和文档。
**永远不会碰** `agents/`、`queen/`、`shared/`、`projects/` — 那些是你的。

---

## 灵感来源

《安德的游戏》中的虫族蜂巢意识。每个个体都连接到同一个女王。
没有独立记忆，没有冲突的自我。一个分布式智能体。
