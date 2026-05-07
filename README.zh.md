# nestwork

[English](README.md) | 中文

版本：v0.3.0 | 协议：2.2

---

**把模板克隆到任意机器，所有 AI agent 共享同一个大脑。**
git 原生的 AI agent 记忆协议，灵感来自《安德的游戏》虫族蜂巢意识 —— 每个工蜂连到同一个女王，没有独立记忆，没有冲突自我，一个分布式智能体。

无插件、无服务器、无第三方依赖。只需要一个 git 仓。

---

## 目录

- [它解决什么问题](#它解决什么问题)
- [核心设计原则](#核心设计原则)
- [工作原理](#工作原理)
- [与其他方案对比](#与其他方案对比)
- [快速开始](#快速开始)
- [自定义你的 nest](#自定义你的-nest)
- [v2.2 新增：workflow/ 与 nestwork.config.json](#v22-新增workflow-与-nestworkconfigjson)
- [真实工作流示例](#真实工作流示例)
- [编译共享记忆（distillation）](#编译共享记忆distillation)
- [目录结构](#目录结构)
- [文件行数限制与拆分协议](#文件行数限制与拆分协议)
- [为什么不会产生冲突](#为什么不会产生冲突)
- [支持的工具](#支持的工具)
- [跟踪上游更新](#跟踪上游更新)
- [FAQ](#faq)
- [故障排查](#故障排查)
- [灵感来源](#灵感来源)

---

## 它解决什么问题

AI coding agent（Claude Code、Codex CLI、Gemini CLI 等）在以下场景会丢失记忆与上下文：

- 关闭 session 后，下次对话从零开始
- 换一台电脑，所有积累的上下文重新建立
- 从一个工具切到另一个（如 Claude → Codex），偏好和习惯失效
- 多个 agent 协作时，无法共享对项目与用户的理解
- 团队场景下，无法把"项目知识"沉淀给后续 agent

常见解决方案各有局限：

| 方案 | 局限 |
|---|---|
| 在 agent 配置文件塞长 system prompt | 跨设备不同步、跨工具不复用、维护痛苦 |
| MCP memory server | 需要跑服务、单点故障、跨机器要部署 |
| 厂商私有 memory（如 OpenAI Memory） | 锁定厂商、不开放、无法跨厂商迁移 |
| claude-mem 等托管 memory | 依赖第三方 worker、可能付费、隐私敏感 |
| 自建数据库 + API | 重资产、与 agent 解耦、维护成本高 |
| 在每个项目放 README/AGENT.md | 不跨项目共享、用户偏好无处可放 |

**nestwork 的答案：用 git 仓做 agent 大脑。** 每个 agent 把记忆写到 git 仓里特定目录，下次启动时 `git pull` 就能跨 session、跨机器、跨工具读到。

它不是一个工具，是一个**协议** —— 任何能读 markdown 文件作为 system prompt 的 agent 都可以接入。

---

## 核心设计原则

1. **git 即唯一基础设施**
   不引入服务器、不引入数据库、不引入第三方服务。git 已经解决了"分布式存储 + 版本控制 + 冲突解决"，重复造轮子是错误。

2. **读写隔离 = 结构上无冲突**
   每个 agent 独占一个目录（`agents/<host>/<agent-id>/`），正常记忆写入永远不会与其他 agent 撞。配合 hook 的"原子逐次写入"，单次 Write/Edit 之内的竞态窗口也被消除。

3. **记忆分层 + 严格优先级链**
   不同性质的内容放不同层。冲突时按优先级取，不合并。这避免了"所有信息糊在一起，agent 不知道听谁的"。

4. **模板化 + 私有实例**
   `nestwork`（公开模板）演进协议，每个用户用 `Use this template` 创建私有实例。私有数据永不外泄，协议演进选择性 pull。

5. **跨工具中立**
   AGENTS.md 是 bootstrap 唯一来源，CLAUDE.md / SOUL.md / GEMINI.md 等都是它的镜像或链接。换工具不用换记忆。

6. **协议本身可演进**
   `protocol-version` 头部标记 `MAJOR.MINOR`，私有仓可锁定信任版本。MAJOR 升级才需要下游动作；MINOR 是 additive 兼容。

---

## 工作原理

### 仓库结构（v2.2 协议）

```
nestwork 仓库（你的私有 queen）
├── queen/          ← 只读规则与策略（由你维护）
│   ├── agent-rules.md       # 行为边界，最高优先级
│   └── strategy.md          # 当前阶段战略
├── agents/         ← 每个 agent 只写自己的目录
│   └── <host>/<agent-id>/   # 一台机器一个 host，一个工具一个 agent-id
│       └── memory.md        # 该 agent 的私有记忆
├── shared/         ← 跨 agent 蒸馏出的共识（只读）
│   └── memory.md
├── projects/       ← 项目上下文文件
│   └── <项目名>.md
└── workflow/       ← v2.2+：跨项目可迁移的工作流知识
    ├── README.md
    └── <主题>.md
```

每台克隆了你的 queen 的机器都共享同一个大脑。每个 agent 实例只写自己的 `agents/<host>/<agent-id>/`，正常记忆写入彼此隔离。

### 优先级链

```
queen/agent-rules.md > queen/strategy.md > shared/memory.md > agents/*/*/memory.md > projects/*.md > workflow/*.md
```

冲突时取高优先级，**不合并**。

### Session 生命周期

```
Session 开始
  ↓
git pull --rebase                          (SessionStart hook 自动)
  ↓
按优先级链加载上下文                       (注入到 agent 的 system prompt)
  ↓
agent 自我定向（看 git log + strategy.md，给状态摘要 + 下一步建议）
  ↓
─── 工作中 ─────────────────────────────
  ↓
Write/Edit 触发 PreToolUse hook
  ↓
git pull --rebase（防止覆盖远程更新）
  ↓
执行写入
  ↓
PostToolUse hook：git add/commit/push
  ↓
（push 失败重试 3 次，每次重 pull）
─────────────────────────────────────
  ↓
Session 结束
  ↓
Stop hook 安全网 commit+push（clean 时无操作）
  ↓
SessionEnd hook：claude-mem export + 本地 history sync（如开启）
```

竞态窗口从"整场会话"压到"单次写入"。同机多 agent 几乎不会撞。

---

## 与其他方案对比

| 维度 | nestwork | MCP memory server | claude-mem | 厂商私有 memory | 自建数据库 |
|---|---|---|---|---|---|
| 基础设施 | git 仓 | 本地服务器 | 远程 worker | 厂商云 | 自建服务 |
| 跨设备 | ✅ git pull | ❌ 需要部署 | ✅ 但依赖 worker | ✅ 厂商账号 | 取决于实现 |
| 跨工具 | ✅ 任何 markdown-config agent | 部分（需 MCP 客户端） | 仅 Claude | ❌ 锁定厂商 | 取决于实现 |
| 跨账号迁移 | ✅ 改 remote 即可 | ✅ | 部分 | ❌ | ✅ |
| 多 agent 协作 | ✅ 协议级支持 | 需要协调 | 单 agent | 单厂商 | 取决于实现 |
| 离线可用 | ✅ | 取决于实现 | ❌ | ❌ | 取决于实现 |
| 数据所有权 | 100% 你的 git 仓 | 100% 本地 | 第三方 worker | 厂商 | 你的 |
| 维护成本 | 低（git 你已会） | 中（需懂 MCP） | 中（依赖 worker） | 零（但锁定） | 高 |
| 隐私 | 私有仓即可 | 看部署 | 第三方风险 | 看条款 | 看部署 |

详见 [docs/comparisons/claude-mem.md](docs/comparisons/claude-mem.md)。

---

## 快速开始

### 1. 创建你的私有 queen

在 GitHub 上点 **Use this template → Create a new repository**，visibility 选 **Private** —— 你的记忆只属于你。

> **为什么不用 Fork？**
> Fork 默认公开且与上游关联。从模板创建的私有仓完全归你所有。
> 当 nestwork 发布更新时，`git merge upstream/main` 会与你刻意定制的 `queen/strategy.md`、`agents/`、`shared/` 产生冲突。`update.sh` 脚本只同步协议层，你的私有数据完全不受影响。

### 2. Clone 到每台机器

```bash
git clone git@github.com:<你的用户名>/nestwork.git ~/nestwork
```

### 3. 安装到你的 agent 工具

**Claude Code（macOS / Linux）**
```bash
bash ~/nestwork/scripts/install/claude.sh
```

**Claude Code（Windows）**
```powershell
.\nestwork\scripts\install\claude.ps1
```

**Codex（macOS / Linux）**
```bash
bash ~/nestwork/scripts/install/codex.sh
```

**Codex（Windows）**
```powershell
.\nestwork\scripts\install\codex.ps1
```

**Gemini CLI / OpenClaw / Hermes / Aider** —— 用法相同，把 `claude` 换成对应工具名。完整列表见 [支持的工具](#支持的工具)。

每台机器执行一次。同一个 queen，不同的 agent ID，共享同一个大脑。

### Prompt 示例

懒得手动走流程？把下面任一条粘进 Claude Code 会话：

- **从零开始**
  > 阅读 https://github.com/songth1ef/nestwork 的 README，按 Quickstart 帮我从 template 新建私有 queen 仓库，clone 到本机，并完成 Claude Code 接入。

- **发现可配置功能**
  > 阅读 https://github.com/songth1ef/nestwork 的 README，列出 nestwork 所有可配置功能（hooks、可选同步、过滤等），并根据我当前机器场景建议要不要开启。

---

## 自定义你的 nest

### 你的规则
编辑 `queen/agent-rules.md` —— 适用于所有 agent 的行为边界（如"输出中文"、"先给结论后给细节"）。最高优先级，不可被任何后续上下文覆盖。

### 你的战略
编辑 `queen/strategy.md` —— 当前阶段目标与决策方向。例如"优先做小而可验证的工具型产品"、"不在没验证需求前堆复杂系统"。

### 你的项目
添加 `projects/<项目名>.md` —— 处理该项目时自动加载的上下文。命名、模块边界、技术栈选型理由、踩坑教训等。

### 你的工作流（v2.2+ 新增）
添加 `workflow/<主题>.md` —— 跨项目可迁移的工作流知识：编码纪律、工具偏好、方法论、迁移指南。详见下一节。

---

## v2.2 新增：workflow/ 与 nestwork.config.json

### 为什么需要 `workflow/`

v2.2 之前，nestwork 有 4 个上下文层：`queen/` `shared/` `agents/` `projects/`。但缺一个位置：

**跨项目可迁移的用户级知识**。

例如：
- 估时按 AI 速度，不按人月
- 加载态 UI 用骨架屏，已有数据再刷新用 v-loading
- 新 repo 初始化时建 5 文档骨架（AGENT.md + conventions.md + domain.md + architecture.md + lessons.md）
- 30 分钟跨设备复原工作流的清单

这些不是关于用户的事实（→ `shared/`），不是项目特定的（→ `projects/`），也不是行为规则（→ `queen/`），但它们**值得跨雇主、跨项目、跨设备保留**。`workflow/` 就是为这层准备的。

### `workflow/` 内容定位

| 应该放 | 不应该放 |
|---|---|
| 跨项目编码纪律、估时规则 | 项目特定业务规则 → `projects/` |
| 工具栈偏好与设置约定 | 跨 agent 稳定的用户事实 → `shared/` |
| Skill 资产、提示词模板 | 单 agent 的临时观察 → `agents/` |
| 迁移 / 跨机部署指南 | 一次性任务笔记 |
| 跨 repo 都用得上的方法论 | 雇主机密信息（不允许任何形式存在于本仓） |

判断标准：**"换雇主后还适用吗？"** —— 是 → `workflow/`；否 → 别的位置。

### `nestwork.config.json` —— 外部目录吸收契约

你的某个工作目录（如 `~/work/some-employer-project/`）里有内容值得吸收进 nestwork 的 `projects/` 或 `workflow/`，但里面包含雇主机密、客户名、内部代号 —— 不能直接复制。

`nestwork.config.json` 是放在**源工作目录**（不是 nestwork 内）的元数据文件，声明：

- 这个目录可被吸收到哪个分类
- 必须脱敏到什么级别
- 哪些词需要脱敏（雇主名、客户名、内部代号）

**最小示例**（放在你的工作目录根）：

```json
{
  "$schema": "https://github.com/songth1ef/nestwork/schemas/nestwork.config.schema.json",
  "version": "1.0",
  "ingest": {
    "target": "projects",
    "name": "some-project"
  },
  "desensitize": {
    "level": "strong",
    "custom_rules": [
      "<你的雇主名>",
      "<内部代号>",
      "<客户名>"
    ]
  }
}
```

**字段说明**：

| 字段 | 含义 |
|---|---|
| `ingest.target` | 吸收到哪个分类：`projects` / `workflow` / `null`（不可吸收） |
| `ingest.name` | 目标文件名 |
| `desensitize.level` | `none`（不处理）/ `weak`（按 custom_rules 模式替换）/ `strong`（AI 语义脱敏 + custom_rules） |
| `desensitize.custom_rules` | 用户自定义敏感词，覆盖在通用方法论之上 |

**关键约束**：
- 配置文件**只放在源目录**，从不进 nestwork 仓
- 默认 `desensitize.level: "strong"`
- agent 检测到要吸收但**没有 config** → 必须停下来提醒用户创建，绝不静默吸收
- 吸收方向**单向**：源目录 → 私有 nest（不会从私有 nest 反向流到 upstream）

完整规则见 [docs/workflow-protocol.md](docs/workflow-protocol.md) 与 `AGENTS.md` 第 8、9 节。

### 脱敏方法论

upstream nestwork 只提供方法论与提示词模板（[docs/desensitization-prompt.md](docs/desensitization-prompt.md)），**不含任何具体雇主名/客户名/代号**。具体名词放在每个用户的 `nestwork.config.json` `custom_rules` 里。

`strong` 级别脱敏会调用 AI（推荐 Claude Haiku，足够便宜快），按提示词模板：

1. 替换所有 `custom_rules` 命中词为占位符（`<EMPLOYER>`、`<CLIENT-A>` 等）
2. 识别"未直接命名但泄露机密"的内容（如内部 API 结构、未发布产品特性）并改写
3. 保留可迁移的方法论部分
4. 输出结构化 JSON（脱敏后内容 + 替换记录 + 待人工 review 的疑问点）
5. **必须经人工 review 后**才写入 nestwork

---

## 真实工作流示例

### 场景：多机器协作开发

你在 macOS 笔记本和 Windows 台式机上都用 Claude Code。两台机器都 clone 了你的私有 queen。

**周一上午（笔记本）**：
- 启动 Claude Code → SessionStart hook 自动 `git pull` 并注入上下文
- 你说"继续昨晚那个 NestJS 模块的事"
- Claude 读取 `agents/macbook/claude-xxx/memory.md` —— 看到昨晚的进度
- 同时加载 `shared/memory.md` —— 知道你的技术栈偏好（Vue 3 + NestJS）
- 直接接续工作，不需要重新解释

**当晚（台式机）**：
- 启动 Claude Code → 自动 pull
- agent 看到 `agents/macbook/claude-xxx/` 上午的更新（虽然这是另一台的 agent，但通过 git 同步过来）
- 你切换到不同任务，agent 继续在 `agents/desktop/claude-yyy/` 写它自己的记忆

**两个 agent 互相不写对方目录，但通过 git 共享所有上下文。**

### 场景：跨工具迁移

某天你想试试 Codex CLI。

```bash
bash ~/nestwork/scripts/install/codex.sh
```

Codex 启动时读 `~/.codex/AGENTS.md`，里面已经被 installer 注入了 nestwork bootstrap。它会：

- pull 你的 queen
- 读 `queen/`、`shared/`、自己的 `agents/<host>/codex/memory.md`
- 知道你的偏好、过去决策、当前项目状态

**记忆不在 Claude 厂商或 OpenAI 厂商，记忆在你的 git 仓。换工具的成本接近零。**

### 场景：把雇主项目知识沉淀进 nest（v2.2+）

你在某雇主项目里发现一个值得记录的架构模式（比如 NestJS 模块组织约定）。

1. 在项目根目录创建 `nestwork.config.json`（见上文示例），`custom_rules` 写上雇主名、内部代号
2. 让 Claude Code 把这段方法论吸收：
   > 把当前项目里的 XX 模式吸收到 mynestwork 的 `projects/<项目名>.md`，按 nestwork.config.json 脱敏
3. agent 读 config，调用脱敏提示词，生成草稿
4. 你 review 后才写入

雇主名永不出现在 nest 仓里；方法论保留下来。换雇主时这份方法论还在。

---

## 编译共享记忆（distillation）

当各 agent 积累了足够记忆后，用下面两种方式之一合入 `shared/memory.md`：

```bash
# 纯拼接：把 agents/*/memory.md 拼接，commit，push
bash ~/nestwork/scripts/maintenance/compile.sh

# LLM 版、与厂商无关：打印蒸馏 prompt，手动喂给任一 agent 会话
python3 ~/nestwork/scripts/maintenance/distill.py

# Codex 手动一键蒸馏：汇总所有 agent memory，写回 shared/memory.md，
# 然后 commit、push。把 <your-profile> 换成这台机器实际可用的 Codex
# profile；如果默认配置已经正确，也可以省略 --profile。
python3 ~/nestwork/scripts/maintenance/distill.py --run-codex --profile <your-profile>

# 只预览候选 shared/memory.md，不落盘
python3 ~/nestwork/scripts/maintenance/distill.py --run-codex --profile <your-profile> --dry-run
```

这些方式都不会修改原始的 agent memory。`--run-codex` 只更新 `shared/memory.md`，提交信息 `memory: distill shared`。所有 agent 在下次 `git pull` 时自动看到新的 `shared/memory.md`。

### 蒸馏的设计取舍

- **共享是 union 不是 intersection** —— 不丢任何 agent 的独特观察
- **非破坏性** —— 每个 agent 私有 memory 不变，蒸馏只读
- **要 sub-agent review** —— 检查敏感数据、事实错误、矛盾、过期项
- **要人工确认** —— sub-agent 只报告，人决定合并
- **绝不删** —— 只合并和增加，不删历史

---

## 目录结构

```
nestwork/
├── AGENTS.md                   bootstrap 唯一来源（Codex、OpenClaw、Gemini 等）
├── CLAUDE.md                   AGENTS.md 的逐行镜像（Claude Code 认这个名字）
├── SOUL.md                     Hermes 的简短人格文件
├── queen/
│   ├── agent-rules.md          行为规则 — agent 只读
│   └── strategy.md             决策方向 — agent 只读
├── agents/
│   └── <host>/<agent-id>/
│       └── memory.md           该 agent 的私有记忆
├── shared/
│   └── memory.md               跨 agent 编译记忆
├── projects/
│   └── <项目>.md               项目上下文
├── workflow/                   v2.2+：跨项目可迁移的工作流知识
│   ├── README.md
│   └── <主题>.md
├── docs/                       协议方法论与对外文档
│   ├── workflow-protocol.md       v2.2 workflow 详解
│   ├── desensitization-prompt.md  AI 脱敏提示词模板
│   ├── ai-agent-memory.md
│   ├── claude-code-memory.md
│   ├── codex-persistent-memory.md
│   ├── git-native-memory-protocol.md
│   ├── agents-md-best-practices.md
│   └── faq.md
├── schemas/
│   └── nestwork.config.schema.json   v2.2 配置 JSON Schema
└── scripts/
    ├── install/                   按工具分的安装器
    │   ├── claude.{sh,ps1}
    │   ├── codex.{sh,ps1}
    │   ├── gemini.{sh,ps1}
    │   ├── hermes.{sh,ps1}
    │   ├── openclaw.{sh,ps1}
    │   ├── aider.{sh,ps1}
    │   ├── generic.{sh,ps1}       任何 markdown-config CLI
    │   ├── _bootstrap.py          共享 bootstrap 注入器
    │   └── _hooks.py              共享 hook 注册器（Claude Code）
    ├── hooks/                     运行时 hook
    │   ├── nestwork.sh            pre/post/stop 统一入口
    │   ├── _match-file.py         stdin 文件匹配器
    │   ├── export-claude-mem.sh   claude-mem 可选桥接
    │   ├── sync-local-history.sh  本地历史同步（wrapper，可选）
    │   └── sync-local-history.py  本地历史同步（worker，可选）
    └── maintenance/               运维
        ├── compile.sh             聚合 agents/* 到 shared/（纯拼接）
        ├── distill.py             打印 prompt，或手动触发 Codex 蒸馏
        ├── sync-claude-md.sh      从 AGENTS.md 重新生成 CLAUDE.md
        └── update.sh              拉取 upstream 协议层
```

---

## 文件行数限制与拆分协议

### 通用规则（v2.2+）

仓库内**任意 markdown 文件**超限后都按同一模式拆分：原文件名变文件夹，原文件变索引（或 `<folder>/index.md`），内容按 topic 分文件。

例：`plan-all.md`(1200 行) → `plan-all.md`（索引）+ `plan/plan-a.md` / `plan/plan-b.md` / `plan/plan-c.md`。

未在下表列出的文件按默认阈值：**软限 500 行**（开始考虑拆），**硬限 1000 行**（下次写入前必须拆）。

### 具体限制

| 文件 | 最大行数 |
|---|---|
| `queen/agent-rules.md` | 80 |
| `queen/strategy.md` | 80 |
| `agents/<host>/<agent-id>/memory.md` | 200 |
| `shared/memory.md` | 500 |
| `projects/<name>.md` | 150 |
| `workflow/<topic>.md` | 200 |

**示例 —— `agents/macbook/claude/memory.md` 达到上限后拆分：**

```
agents/macbook/claude/
├── memory.md          ← 变为索引
├── user_profile.md
├── feedback_collab.md
└── project_nestwork.md
```

拆分后的 `memory.md`：
```markdown
# MEMORY — claude-macbook

- [用户档案](user_profile.md) — 角色、技术栈、偏好
- [协作习惯](feedback_collab.md) — 工作方式、修正记录
- [项目：nestwork](project_nestwork.md) — 目标、决策
```

agent 先读索引，按需跟进相关 topic 文件。

### 为什么有行数限制？

LLM 上下文窗口虽大，但**注意力随 token 数衰减**。把一个 5000 行的 memory.md 全塞进去，agent 实际利用率很低。把它拆成 5 个 200-400 行的 topic 文件 + 一个索引，agent 按需读，效果反而更好。

---

## 为什么不会产生冲突

每个 agent 独占 `agents/` 下的一个目录，没有两个 agent 写同一个文件。正常使用下，git 冲突从结构上就不可能发生。

| 路径 | 谁写 | 可能冲突？ |
|---|---|---|
| `queen/` | 你（人工） | 不会（你只有一双手） |
| `agents/<host>/<agent-id>/` | 仅该 agent | 正常记忆写入不会 |
| `shared/` | 仅显式 `compile.sh` / `distill.py --run-codex` | 正常 agent 写记忆时不会 |
| `projects/` | agent 或人工 | 多 agent 同时写同一项目文件**理论上**可能，但通过 PreToolUse hook 的 `git pull --rebase` 大幅降低 |
| `workflow/` | agent 或人工 | 同上 |

### Hook 架构（原子逐次写入，2026-04-17 引入）

竞态窗口从"整场会话"压缩到"单次 Write 执行"：

| Hook 事件 | 动作 | 作用 |
|---|---|---|
| **SessionStart** | pull + 注入 agent-rules/strategy/shared/agent memory 到 additionalContext | 替代手动启动协议 |
| **PreToolUse** (Write\|Edit, scoped to `agents/<id>/`) | `git pull --rebase`；冲突 `exit 2` 阻止写入 | 防止覆盖远程更新 |
| **PostToolUse** (同 scope) | `git add/commit/push`；push 失败 3 次重试（每次重 pull） | 即时同步 |
| **Stop** | 安全网 commit+push（clean 时为 no-op） | 兜底 |
| **SessionEnd** | claude-mem export + 本地 history sync | 跨机可达 |

---

## 支持的工具

### 原生安装器（配置路径明确）

| 工具 | 厂商 | 入口文件 | 安装方式 | 适配状态 |
|---|---|---|---|---|
| Claude Code | Anthropic | `~/.claude/CLAUDE.md` + hooks | `bash scripts/install/claude.sh` | 已适配，个人在用 |
| Codex CLI | OpenAI | `~/.codex/AGENTS.md` + 兼容入口 | `bash scripts/install/codex.sh` | 已适配，个人在用 |
| Gemini CLI | Google | `~/.gemini/GEMINI.md` | `bash scripts/install/gemini.sh` | 有入口，未亲测 |
| OpenClaw | 开源 | `~/.openclaw/workspace/AGENTS.md` | `bash scripts/install/openclaw.sh` | 有入口，未亲测 |
| Hermes Agent | 开源 | `~/.hermes/SOUL.md` | `bash scripts/install/hermes.sh` | 有入口，未亲测 |
| Aider | 开源 | `~/.aider-nestwork.md`（通过 `.aider.conf.yml` `read:` 接入） | `bash scripts/install/aider.sh` | 有入口，未亲测 |

只有 Claude Code 注册了 session hook 实现原子逐次写入。其他工具遵循 bootstrap config 里写入的"会话结束提交"协议。

### 可选：捕获本地工具历史

Claude Code 在 `~/.claude/` 下保留 prompt 历史和 plan 产物；Codex 在 `~/.codex/` 下保留 prompt 历史。可镜像进 `agents/<host>/<id>/local/`，跨机器携带。

按 host 独立启用，无需 env，无需重装。在 queen 里为当前机器对应的 host 目录创建 `agents/<host>/settings.json`：

```json
{ "sync_local_history": true }
```

默认 `false`。这个开关随 queen 进入 git 版本控制，每台机器独立。

启用后同步：

| 源 | 目标 | 说明 |
|---|---|---|
| `~/.claude/history.jsonl` | `local/history.jsonl` | 脱敏：删除 `pastedContents`，`$HOME` 路径归一化，`sk-*`/`ghp_*`/`Bearer …` 替换为 `<REDACTED>` |
| `~/.claude/plans/` | `local/plans/` | plan 模式产物，原样镜像 |
| `~/.codex/history.jsonl` | `local/history.jsonl` | 仅 Codex agent，同一套脱敏规则 |

`todos/` 和 `tasks/` 排除 —— 99% 是按 session UUID 预分配的空文件。

### 通过 `install/generic.sh` 接入（自行确认 config 路径）

任何"启动时读一份 markdown 作为 system prompt"的 CLI 都可以一行命令接入：

```bash
bash scripts/install/generic.sh <prefix> <config-path>
```

| 工具 | 厂商 | 推荐 prefix |
|---|---|---|
| Qwen Code | 阿里通义 | `qwen` |
| OpenCode | 开源 | `opencode` |
| CodeBuddy Code | 腾讯 | `codebuddy` |
| iFlow CLI | 阿里心流 | `iflow` |
| Trae CLI / Solo | 字节跳动 | `trae` |
| Qoder | 阿里 | `qoder` |
| Kimi Code CLI | 月之暗面 | `kimi` |
| 通义灵码 CLI | 阿里云 | `lingma` |

> **提示**：Qwen Code 是 Gemini CLI 的 fork，可能直接认 `~/.gemini/GEMINI.md` —— 先试 `install/gemini.sh`。

### Workspace 级（IDE 插件，软链接）

| 工具 | 目标路径 | 安装方式 |
|---|---|---|
| Cursor | `.cursor/rules/nestwork.md` | `ln -s AGENTS.md .cursor/rules/nestwork.md` |
| Windsurf | `.windsurf/rules/nestwork.md` | `ln -s AGENTS.md .windsurf/rules/nestwork.md` |
| Cline（VS Code） | `.clinerules/nestwork.md` | `ln -s AGENTS.md .clinerules/nestwork.md` |
| GitHub Copilot（repo 级） | `.github/copilot-instructions.md` | `ln -s AGENTS.md .github/copilot-instructions.md` |

### 不支持（原因）

| 工具 | 原因 |
|---|---|
| GitHub Copilot CLI（`gh copilot`） | Q&A 模式，无持久化指令文件机制 |
| Antigravity | IDE 为主，CLI 入口是项目级，对外 bootstrap 机制未公开 |
| CloudBase AI CLI | 网关型，调用下游 CLI —— 在下游工具上装 nestwork 即可 |
| ChatDev | 模拟"虚拟软件公司"工作流编排，不是持久化单 agent 循环 |

---

## 跟踪上游更新

两条路径，都不碰你的私有数据（`agents/`、`queen/`、`shared/`、`projects/`、`workflow/<topic>.md`）。

### 手动（默认推荐）

需要拉取最新协议层更新时，打开 **Actions → Sync Nestwork upstream → Run workflow**。

大多数仓库没必要每天追上游，手动 review 让协议层变更保持明确、可控。

### 自动（可选）

私有仓里的 `.github/workflows/sync-upstream.yml` 可以每周一 03:00 UTC 自动运行，发现差异就开 PR 到你的 `main`。你 review diff 后合并。

自动同步默认**关闭**。要启用：

1. **Settings → Secrets and variables → Actions → Variables**
2. 新建仓库变量 `NESTWORK_AUTO_SYNC`
3. 值填 `true`

PR 的 create/update/reopen 走的是 GitHub REST API，不再依赖 `gh pr ...` 的 GraphQL 路径。如果默认 token 被拦截，加一个名为 `NESTWORK_SYNC_TOKEN` 的 Actions secret，workflow 会优先使用。

GitHub 禁止 `GITHUB_TOKEN` push 修改 workflow 文件的 commit，所以 CI 路径**不覆盖** `.github/workflows/`，workflow 变更要走下面手动路径。

### 手动刷新协议层

```bash
bash ~/my-nest/scripts/maintenance/update.sh
```

覆盖 `scripts/`、`.github/workflows/`、`AGENTS.md`、`CLAUDE.md`、`SOUL.md`、双语 README、`docs/`、`schemas/`，以及 `workflow/README.md` + `workflow/_template.md`（**不动**你 workflow/ 下的私有内容）。

---

## FAQ

### 为什么不用 fork 而用 template？

Fork 默认公开，且与上游强关联。每次上游更新都会与你私有的 `queen/`、`agents/`、`shared/` 产生 merge 冲突。Template 创建的私有仓没有共同 git 历史，通过 `git checkout upstream/main -- <files>` 选择性同步协议层，私有数据完全不受影响。

### 我的雇主代码会被吸收进 nest 吗？

不会。除非你显式在雇主项目根目录创建 `nestwork.config.json` 并明确告诉 agent 吸收。即使吸收，`desensitize.level: "strong"` 会调用 AI 脱敏，雇主名/客户名/内部代号都会被替换为占位符，且**人工 review 后**才写入。

### Claude Code 之外的工具能用 nestwork 吗？

能。任何"启动时读 markdown 作为 system prompt"的 CLI 都能用 `install/generic.sh` 接入。但只有 Claude Code 有 hook 系统，能实现原子逐次写入。其他工具靠"会话结束提交"协议，竞态窗口稍大但实际很少出问题。

### 多台机器同时改同一个 `projects/<name>.md` 会冲突吗？

理论上可能，实际几乎不会。PreToolUse hook 在每次写入前 `git pull --rebase`，把竞态窗口压到单次写入。两台机器**同一秒**写同一文件才会撞，正常协作场景几乎不发生。万一发生，hook 会 `exit 2` 阻止写入并提示手动合并。

### `shared/memory.md` 是怎么来的？

不是自动来的。需要你显式触发蒸馏：

- `compile.sh` —— 纯拼接所有 agent memory
- `distill.py` —— LLM 蒸馏（推荐）

蒸馏过程会调用 sub-agent review，标记敏感数据、事实矛盾、过期项，最后由你确认合并。设计目标是**非破坏性**：每个 agent 私有 memory 不变。

### 我能在 nestwork 里存 API key 吗？

**不能**。即使是 private 仓也不建议。GitHub 漏洞、账号被攻破、合作者权限误授等都会泄漏。API key 用环境变量或专门的 secret store。

### 协议会经常 breaking change 吗？

不会。`protocol-version` 用 `MAJOR.MINOR`：MAJOR 改动需要下游动作，**应避免**；MINOR 是 additive 兼容。从 v1 → v2.0 → v2.1 → v2.2 都是 additive。

### 跨语言 / 中英文混用怎么处理？

- `queen/agent-rules.md` 可以写"默认中文交流"作为行为规则
- agent memory / shared memory 可以混着写，agent 会自然处理
- 协议本身的字段名、目录结构、文件名是英文，不可改
- 命名建议：技术术语保留英文，行为规则与领域知识用中文

### 如果我不喜欢 git，能换成别的存储吗？

不能。git 是 nestwork 的核心，不是可选项。如果你不熟悉 git，nestwork 不是合适的工具。

---

## 故障排查

### `bash scripts/install/claude.sh` 失败

- **macOS / Linux**：检查 `~/.claude/` 是否存在并可写。
- **Windows Git Bash**：`hostname -s` 不支持，installer 已 fallback 到 `hostname | cut -d. -f1`。如果还失败，手动设 `NESTWORK_HOST=desktop-xxx`。

### Hook 装了，但 commit 没自动 push

按以下顺序排查：

1. `git -C $NESTWORK_PATH remote -v` 看 remote 是否设对
2. `cat ~/.claude/settings.json` 看 hook 是否注册
3. `cat scripts/hooks/nestwork.sh` 末尾看是否调用了 push
4. 手动 `git push` 看是否需要凭据交互（hook 跑在非交互模式）

### Push 失败重试 3 次还是失败

通常是 GitHub 凭据过期。处理：

```bash
git -C $NESTWORK_PATH push  # 看具体错误
# 凭据问题：用 gh auth login 或重设 SSH key
```

### `agents/<host>/<agent-id>/memory.md` 有冲突

PreToolUse hook 应该已经阻止了。如果出现，说明 hook 没生效或者你手动改了。手动解决：

```bash
git -C $NESTWORK_PATH status         # 看冲突文件
# 编辑文件解决冲突
git -C $NESTWORK_PATH add agents/<host>/<agent-id>/
git -C $NESTWORK_PATH rebase --continue
```

按 v2.2 协议第 5 节，`agents/<host>/<agent-id>/` 目录冲突应取本地（这个 agent 是该目录的 owner）。

### Claude Code 启动后没自动 pull / 没注入上下文

检查 SessionStart hook 是否注册：

```bash
cat ~/.claude/settings.json | grep -A 5 SessionStart
```

如果没有，重跑 installer：`bash scripts/install/claude.sh`。

### 跨机器看到的 agent ID 不一致

检查 `~/.nestwork_id`：

```bash
cat ~/.nestwork_id
```

每台机器的 `~/.nestwork_id` 应该不同（`<tool>-<4字符随机>`）。如果一样，说明你复制了 dotfiles —— 在新机器上删掉这个文件让 installer 重新生成。

### 我想试一下但不想 commit 自己的私有信息到 GitHub

完全本地用：

```bash
git clone git@github.com:songth1ef/nestwork.git ~/local-nest
# 不 push 到任何 remote
```

或者把 remote 改到 self-hosted git：

```bash
git remote set-url origin <你的私有 git>
```

---

## 灵感来源

《安德的游戏》（Ender's Game）中虫族（Formic）的蜂巢意识。每个工蜂连到同一个女王，没有独立记忆，没有冲突自我，一个分布式智能体。

nestwork 把这个隐喻搬到 AI agent：你（人）就是 queen，你的所有 agent 实例（Claude、Codex、Gemini……）都是 worker，连到同一个 git 仓 = 同一个大脑。

---

## 协议演进与版本

- **v2.0**（2026-04-17）：`agents/` 改为按 host 分组（`agents/<host>/<agent-id>/`），原子逐次写入 hook 架构
- **v2.1**（2026-04-21）：SessionStart hook 自动注入上下文
- **v2.2**（2026-05-07）：新增 `workflow/` 上下文层 + `nestwork.config.json` 外部目录吸收契约 + 通用 markdown 拆分规则

完整协议规范见 [AGENTS.md](AGENTS.md)。

---

## 相关文档

- [AGENTS.md](AGENTS.md) —— 协议规范（最权威，agent 启动时读这个）
- [docs/workflow-protocol.md](docs/workflow-protocol.md) —— v2.2 workflow 详解
- [docs/desensitization-prompt.md](docs/desensitization-prompt.md) —— AI 脱敏方法论
- [schemas/nestwork.config.schema.json](schemas/nestwork.config.schema.json) —— `nestwork.config.json` JSON Schema
- [docs/ai-agent-memory.md](docs/ai-agent-memory.md)
- [docs/claude-code-memory.md](docs/claude-code-memory.md)
- [docs/codex-persistent-memory.md](docs/codex-persistent-memory.md)
- [docs/git-native-memory-protocol.md](docs/git-native-memory-protocol.md)
- [docs/agents-md-best-practices.md](docs/agents-md-best-practices.md)
- [docs/shared-context-for-ai-coding-agents.md](docs/shared-context-for-ai-coding-agents.md)
- [docs/faq.md](docs/faq.md)
- [docs/comparisons/claude-mem.md](docs/comparisons/claude-mem.md)
