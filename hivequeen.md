---
name: hivequeen
status: planning
created: 2026-04-16
---

## 一句话描述

Fork it, clone it anywhere — your agents share one brain. A git-native memory protocol for AI agents, like Formic workers wired to their queen. No plugins, no servers. Just git. // fork 即继承，clone 即连接，所有 agent 共用同一个大脑。git 原生记忆协议，无需插件，无需服务器。

---

## 核心隐喻

来自《安德的游戏》中的虫族（Formic）：

- 所有虫族个体没有独立意识，共享女王的思维
- 女王死，个体失去方向；女王在，个体即延伸
- **git 仓库 = Hive Queen**（母体大脑，唯一真相来源）
- **每个 fork/clone 出去的 agent 实例 = 虫族个体**（执行者）
- **git pull/push = 意识回路**（个体与母体的实时连接）

---

## 解决什么问题

AI agent（如 Claude Code、Codex）在不同机器、不同环境下运行时，彼此之间没有共享上下文：

- 规则不同步：一台机器调整了协作规则，另一台不知道
- 记忆不共享：一个会话积累的偏好，下个会话从头开始
- 身份不一致：同一个人的不同 agent 实例像陌生人一样合作

hivequeen 让所有实例从同一个母体继承上下文，通过 git 实现意识同步。

---

## 分发模型

```
用户 fork hivequeen
  └── clone 到机器 A → 运行 install-claude.sh → Claude Code 接入母体
  └── clone 到机器 B → 运行 install-codex.sh  → Codex 接入母体
  └── clone 到机器 C → 任意新环境，fork 即继承
```

- 每个用户拥有自己的 fork，数据完全私有
- 无中心服务器，无第三方依赖
- 跨环境同步 = 普通的 `git pull / git push`

---

## 目录结构

```
hivequeen/
├── queen/                        ← 只读层，人工维护，agent 不写
│   ├── agent-rules.md            ← 行为边界（最高优先级）
│   └── strategy.md               ← 当前阶段决策方向
│
├── agents/                       ← 写入层，每个 agent 只写自己的目录
│   ├── claude-macbook/
│   │   └── memory.md
│   ├── codex-server1/
│   │   └── memory.md
│   └── claude-vps/
│       └── memory.md
│
└── shared/                       ← 编译层，从 agents/* 聚合而来
    └── memory.md                 ← 所有 agent 可读的共享记忆
```

---

## 读写分离原则

| 目录 | 谁写 | 谁读 | 冲突可能性 |
|---|---|---|---|
| `queen/` | 人工 | 所有 agent | 无 |
| `agents/自己的目录/` | 该 agent 独占 | 该 agent | 无 |
| `shared/` | 编译步骤 | 所有 agent | 可控 |

**每个 agent 只写自己目录下的文件，从根本上消除并发写冲突。**

---

## Session 生命周期

```
session 开始
  └── git pull
  └── 按顺序加载上下文：
        1. queen/agent-rules.md     ← 行为约束（最高优先级）
        2. queen/strategy.md        ← 当前阶段决策方向
        3. shared/memory.md         ← 共享长期记忆
        4. agents/自己目录/memory.md ← 本实例私有记忆
        5. projects/*.md            ← 当前任务约束

session 过程中
  └── agent 按规则执行
  └── 记忆更新只写入 agents/自己目录/

session 结束
  └── git add agents/自己目录/ → commit → push（永不冲突）
  └── 触发编译（可选）：聚合 agents/* → 更新 shared/memory.md
```

---

## 上下文优先级

```
queen/agent-rules.md   最高优先级，行为边界，不可被覆盖
queen/strategy.md      当前阶段目标与决策方向
shared/memory.md       跨 agent 共享的长期事实
agents/自己/memory.md  本实例私有记忆
projects/*.md          当前任务约束，最低优先级
```

冲突处理规则：`agent-rules > strategy > shared > private > projects`  
不允许自行融合冲突内容，必须按优先级选择。

---

## 共享记忆编译

agents 各自积累的私有记忆，通过编译步骤聚合为 `shared/memory.md`：

- **触发方式**：session 结束后可选触发，或定期手动运行
- **执行者**：一个专用 Claude Code session 读取所有 `agents/*/memory.md`，提炼合并
- **未来扩展**：可做成 GitHub Actions，自动定期编译

---

## 自动更新授权边界

- agent 只允许写入 `agents/自己目录/` 下的文件
- 允许自动执行 `git add / commit / push`（仅限自己目录）
- `queen/` 和 `shared/` 不允许 agent 直接写入
- 仅在有明确沉淀价值时执行，不记录一次性噪音

---

## 支持工具

| 工具 | 安装脚本 | 状态 |
|---|---|---|
| Claude Code | `scripts/install-claude.sh` / `install-claude.ps1` | 已支持 |
| Codex | `scripts/install-codex.sh` / `install-codex.ps1` | 已支持 |
| 其他工具 | 待扩展 | 规划中 |

---

## 核心特性对比

| 特性 | hivequeen | 其他方案 |
|---|---|---|
| git 作为 session 同步协议 | ✅ | ❌ 大多把 git 当存储实现 |
| 分层上下文 + 优先级规则 | ✅ | ❌ 无 |
| session 开始自动 git pull | ✅ | ❌ 无 |
| 记忆更新自动 commit+push | ✅ | 部分有 |
| 多 AI 工具支持 | ✅ | ❌ 大多只支持 Claude Code |
| fork 即拥有，数据私有 | ✅ | ❌ 大多是插件/订阅模式 |
| 零中心依赖 | ✅ | ❌ 大多需要服务或 API |

---

## 竞品分析

| 项目 | Stars | 本质 | 与 hivequeen 的差距 |
|---|---|---|---|
| claude-mem | 58.7k | 录像回放式记忆插件 | 无协议层、无分层规则、无 git sync |
| DiffMem | 851 | git 记忆后端库 | 是库不是协议，无 session 生命周期管理 |
| claude-memory-compiler | 754 | LLM 提炼 + 结构化知识库 | 记忆插件，不支持多工具，无优先级规则 |
| hippo-memory | 555 | 仿生记忆衰减模型 | 哲学相反：记忆衰减 vs 持久化优先 |
| claude-code-auto-memory | 134 | 自动维护 CLAUDE.md | 功能单一，无同步机制 |

**真正的差异化**：hivequeen 是唯一把 git 当作**会话级同步协议**、有**分层规则**、支持**多工具**、以**fork+clone 作为分发模型**的方案。现有方案都是插件思维，hivequeen 是协议思维。

---

## 目标用户

- 在多台机器上使用 AI 编码工具的开发者
- 同时使用多种 AI agent 工具（Claude Code + Codex 等）的开发者
- 有一定工程背景，愿意 own 自己 AI 工作流的人
- 关注 AI agent 长期记忆与上下文治理的人

不适合：需要开箱即用、不想碰 git 的用户。

---

## 当前阶段目标

1. 完善 README，让陌生人 fork 后 10 分钟内跑起来
2. 补全 install 脚本，确保 Claude Code + Codex 都能一键接入
3. 建立 GitHub repo，开放 fork
4. 找到第一批真实用户验证核心流程

---

## 待解决的问题

- [ ] 是否需要 LLM 自动提炼记忆层（目前是手动结构化）
- [ ] install 脚本的跨平台兼容性（Windows/macOS/Linux）
- [ ] 如何处理多人共用同一个 fork 的场景（团队协作）
- [x] git conflict 的自动处理策略 → 读写分离：agent 只写自己目录，从根本上消除冲突

---

## 不做的事

- 不做中心化服务器或 SaaS
- 不做向量数据库或语义检索
- 不在需求未验证前引入 LLM 提炼层
- 不追求支持所有 AI 工具，先把 Claude Code + Codex 做好
