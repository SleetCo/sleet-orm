[English](README.md) | [简体中文]

[Docs](https://sleet.ls-rp.cn/zh)

# ❄ Sleet

> 优雅的 FiveM + oxmysql ORM — 灵感来自 Drizzle

Sleet 将 [Drizzle ORM](https://orm.drizzle.team/) 的 **Schema 即代码** 理念带入 FiveM 的 Lua 脚本环境。告别裸 SQL 字符串，用 Lua 定义表结构，让 Sleet 生成干净的参数化查询。

```lua
local sl = Sleet
local s  = require 'server.schema'
local db = sl.connect()

-- 完整类型推断，无需手写 ---@type
local players = db.select()
    .from(s.players)
    .where(sl.eq(s.players.identifier, identifier))
    .execute()
-- players: PlayersRecord[]  ✓（LuaLS 自动推断）
```

> QQ 交流群: 914053352

---

## 特性

-   **Schema 即代码** — 在 Lua 里定义表结构，无需 SQL 字符串
-   **链式查询构建器** — SELECT / INSERT / UPDATE / DELETE 全部支持点号链式调用
-   **完整类型推断** — 运行 `sleet generate` 后，LuaLS 无需任何手写 `---@type` 即可推断 `XxxRecord[]`
-   **列注释** — `.comment('描述')` 同步到 IDE hover 提示和 SQL `COMMENT` 子句
-   **安全** — 所有值使用 `?` 参数占位符，彻底防止 SQL 注入
-   **透明** — 每个查询都有 `.toSQL()` 调试方法
-   **原始 SQL 转义口** — `sl.sql()` 用于 `COUNT(*)` 等聚合表达式和原子更新
-   **零运行时依赖** — 仅需 [oxmysql](https://github.com/overextended/oxmysql)
-   **内置 `require` 系统** — 自带 `package`/`require` shim（设计参考 ox_lib），有无 ox_lib 均可使用，在任何脚本中直接 `require 'server.schema'`
-   **CLI 工具** — 单个 Go 二进制（`sleet`），生成 EmmyLua 类型注解和建表 SQL

---

## 安装

### 1. 下载资源

```bash
git clone https://github.com/SleetCo/sleet-orm [sleet]/sleet
```

### 2. server.cfg

```cfg
ensure oxmysql
ensure your_sleet_user_resource
```

### 3. 你的资源 fxmanifest.lua

```lua
fx_version 'cerulean'
game 'gta5'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@sleet/sleet.lua',    -- 注入全局 Sleet + 安装 package/require shim
    'server/main.lua',     -- 在脚本内用 require 'server.schema' 加载 schema
}
```

---

## 快速开始

### 定义 Schema

```lua
-- server/schema.lua
local sl = Sleet  -- @sleet/sleet.lua 注入的全局变量

local players = sl.table('players', {
    id         = sl.serial().primaryKey().comment('玩家自增ID'),
    identifier = sl.varchar(64).notNull().unique().comment('Steam / Discord 标识符'),
    name       = sl.varchar(255).notNull().comment('玩家名称'),
    money      = sl.int().default(500).comment('现金'),
    bank       = sl.int().default(2500).comment('银行余额'),
    is_admin   = sl.boolean().default(false).comment('管理员标志'),
    metadata   = sl.json().comment('扩展数据'),
    last_seen  = sl.timestamp().defaultNow().comment('最后在线时间'),
})

-- return 后可在其他脚本通过 require 'server.schema' 获取
return { players = players }
```

### 查询

```lua
-- server/main.lua
local sl = Sleet
local s  = require 'server.schema'
local db = sl.connect()

-- SELECT — 运行 `sleet generate` 后 LuaLS 自动推断 PlayersRecord[]
local rows = db.select()
    .from(s.players)
    .where(sl.eq(s.players.identifier, identifier))
    .limit(1)
    .execute()

local player = rows[1]  -- player: PlayersRecord ✓

-- INSERT — 返回 insertId
local newId = db.insert(s.players)
    .values({ identifier = 'steam:xxx', name = GetPlayerName(source) })
    .execute()

-- UPDATE — 返回受影响行数
db.update(s.players)
    .set({ money = sl.sql('`money` + 500') })
    .where(sl.eq(s.players.id, player.id))
    .execute()

-- DELETE
db.delete(s.players)
    .where(sl.eq(s.players.id, newId))
    .execute()
```

---

## 列类型

| Sleet              | MySQL DDL               | Lua 类型  |
| ------------------ | ----------------------- | --------- |
| `sl.serial()`      | `INT AUTO_INCREMENT`    | `integer` |
| `sl.bigserial()`   | `BIGINT AUTO_INCREMENT` | `integer` |
| `sl.int()`         | `INT`                   | `integer` |
| `sl.bigint()`      | `BIGINT`                | `integer` |
| `sl.smallint()`    | `SMALLINT`              | `integer` |
| `sl.tinyint()`     | `TINYINT`               | `integer` |
| `sl.float()`       | `FLOAT`                 | `number`  |
| `sl.double()`      | `DOUBLE`                | `number`  |
| `sl.decimal(p, s)` | `DECIMAL(p, s)`         | `number`  |
| `sl.varchar(len)`  | `VARCHAR(len)`          | `string`  |
| `sl.char(len)`     | `CHAR(len)`             | `string`  |
| `sl.text()`        | `TEXT`                  | `string`  |
| `sl.longtext()`    | `LONGTEXT`              | `string`  |
| `sl.boolean()`     | `TINYINT(1)`            | `boolean` |
| `sl.timestamp()`   | `TIMESTAMP`             | `string`  |
| `sl.datetime()`    | `DATETIME`              | `string`  |
| `sl.date()`        | `DATE`                  | `string`  |
| `sl.json()`        | `JSON`                  | `table`   |

### 列修饰符（全部点号，可链式）

```lua
sl.serial().primaryKey()               -- PRIMARY KEY + NOT NULL
sl.varchar(64).notNull()               -- NOT NULL
sl.varchar(64).unique()                -- UNIQUE
sl.int().default(0)                    -- DEFAULT 0
sl.timestamp().defaultNow()            -- DEFAULT CURRENT_TIMESTAMP
sl.int().autoIncrement()               -- AUTO_INCREMENT
sl.int().references(other.id)          -- 外键（CLI 使用）
sl.timestamp().softDelete()            -- 软删除字段标记
sl.timestamp().onUpdate(sl.sql('NOW()')) -- 更新时自动设置值
sl.varchar(64).comment('描述')         -- IDE hover + SQL COMMENT
```

---

## 查询 API

### SELECT

```lua
-- 查询所有行
db.select().from(s.players).execute()

-- WHERE 条件
db.select().from(s.players).where(sl.eq(s.players.id, 1)).execute()

-- 指定列
db.select({ s.players.id, s.players.name }).from(s.players).execute()

-- 排序 + 分页
db.select()
    .from(s.players)
    .orderBy(s.players.name, 'asc')
    .limit(20)
    .offset(40)
    .execute()

-- JOIN
db.select()
    .from(s.orders)
    .leftJoin(s.players, sl.eq(s.orders.player_id, s.players.id))
    .execute()

-- 聚合 / 原始 SQL 列 — 需手动标注结果行形状
---@type { total: integer }[]
local result = db.select({ sl.sql('COUNT(*) AS total') }).from(s.players).execute()
local total = result[1].total
```

### INSERT

```lua
local newId = db.insert(s.players)
    .values({ identifier = 'steam:xxx', name = 'John' })
    .execute()  -- 返回 insertId（integer）
```

### UPDATE

```lua
-- 普通字段赋值
local affected = db.update(s.players)
    .set({ money = 1000, bank = 5000 })
    .where(sl.eq(s.players.identifier, 'steam:xxx'))
    .execute()  -- 返回受影响行数（integer）

-- 原子表达式（sl.sql，适合并发安全的余额操作）
db.update(s.players)
    .set({ bank = sl.sql('`bank` + ?', { 500 }) })
    .where(sl.eq(s.players.id, 1))
    .execute()
```

### DELETE

```lua
db.delete(s.players)
    .where(sl.eq(s.players.id, playerId))
    .execute()  -- 返回受影响行数（integer）
```

### toSQL（调试）

```lua
local sql, params = db.select()
    .from(s.players)
    .where(sl.eq(s.players.id, 1))
    .toSQL()
-- sql    = "SELECT * FROM `players` WHERE `players`.`id` = ?"
-- params = { 1 }
print(sql, json.encode(params))
```

---

## 高级功能

### 软删除 (Soft Delete)

Sleet 支持自动软删除功能。当你标记一个字段为软删除字段时，所有的 DELETE 操作会自动转换为 UPDATE 操作，设置删除时间戳而不是真正删除数据。

#### 定义软删除字段

```lua
local players = sl.table('players', {
    id         = sl.serial().primaryKey(),
    name       = sl.varchar(255).notNull(),
    deleted_at = sl.timestamp().softDelete().comment('软删除时间戳'),
})
```

#### 使用软删除

```lua
-- 删除操作（实际执行 UPDATE deleted_at = NOW()）
db.delete(s.players)
    .where(sl.eq(s.players.id, playerId))
    .execute()

-- 查询时自动过滤已删除记录
local activePlayers = db.select().from(s.players).execute()  -- 只返回未删除的

-- 查询包含已删除记录
local allPlayers = db.select().from(s.players).withDeleted().execute()  -- 包含已删除的

-- 恢复已删除记录
db.update(s.players)
    .set({ deleted_at = nil })
    .where(sl.eq(s.players.id, playerId))
    .execute()
```

### onUpdate 自动更新

`onUpdate` 功能允许字段在每次 UPDATE 操作时自动设置为指定值，常用于 `last_modified` 时间戳字段。

#### 定义 onUpdate 字段

```lua
local players = sl.table('players', {
    id         = sl.serial().primaryKey(),
    name       = sl.varchar(255).notNull(),
    last_seen  = sl.timestamp().defaultNow().onUpdate(sl.sql('NOW()')).comment('最后活动时间'),
})
```

#### onUpdate 自动触发

```lua
-- 任何 UPDATE 操作都会自动更新 last_seen 字段
db.update(s.players)
    .set({ name = 'New Name' })
    .where(sl.eq(s.players.id, playerId))
    .execute()
-- last_seen 会自动设置为当前时间

-- 也可以显式触发 onUpdate（不修改其他字段）
db.update(s.players)
    .set({ name = sl.sql('`name`') })  -- 用原值更新，仅触发 onUpdate
    .where(sl.eq(s.players.id, playerId))
    .execute()
```

#### 支持的 onUpdate 值类型

```lua
-- 原始 SQL 表达式（推荐）
.onUpdate(sl.sql('NOW()'))                    -- 当前时间戳
.onUpdate(sl.sql('UNIX_TIMESTAMP()'))         -- Unix 时间戳
.onUpdate(sl.sql('`version` + 1'))            -- 版本号自增

-- 静态值
.onUpdate('2024-01-01 00:00:00')              -- 固定时间
.onUpdate(1)                                  -- 固定数值
```

---

## 条件操作符

```lua
sl.eq(col, val)              -- col = ?
sl.ne(col, val)              -- col != ?
sl.gt(col, val)              -- col > ?
sl.gte(col, val)             -- col >= ?
sl.lt(col, val)              -- col < ?
sl.lte(col, val)             -- col <= ?
sl.like(col, val)            -- col LIKE ?
sl.notLike(col, val)         -- col NOT LIKE ?
sl.isNull(col)               -- col IS NULL
sl.isNotNull(col)            -- col IS NOT NULL
sl.inArray(col, { 1,2,3 })  -- col IN (?,?,?)
sl.notInArray(col, { ... })  -- col NOT IN (...)
sl.between(col, a, b)        -- col BETWEEN ? AND ?

-- 逻辑组合
sl.and_(cond1, cond2, ...)   -- (cond1 AND cond2 AND ...)
sl.or_(cond1, cond2, ...)    -- (cond1 OR  cond2 OR  ...)
sl.not_(cond)                -- NOT (cond)
```

---

## CLI（`sleet`）

单个 Go 二进制，无需 Node / Python / 任何运行时。

### 安装

**npm（推荐）** — 全局安装：

```bash
npm install -g sleet-orm-cli
```

**下载预构建二进制**（[GitHub Releases](https://github.com/SleetCo/sleet-orm-cli/releases)）：

| 平台        | 文件        |
| ----------- | ----------- |
| Windows x64 | `sleet.exe` |

放入 `PATH` 或直接在项目根目录调用。

**从源码构建**（需要 Go 1.21+）：

```bash
cd cli
go build -o sleet .
```

---

### `sleet generate` — 生成 EmmyLua 类型注解

在内置 Lua VM 中执行 `schema.lua`，拦截所有 `sl.table()` 调用，输出 `---@meta` 文件，包含：

-   `XxxRecord` — SELECT 结果行形状（字段 Lua 类型 + 列描述）
-   `XxxTable` — Schema 对象（`ColumnDef<T>` 字段，如 `s.players.money → ColumnDef<integer>`）
-   `XxxSelectBuilder` — 每张表专属的查询构建器，`execute()` 直接返回 `XxxRecord[]`
-   `Sleet.table @overload` — `sl.table('players', {...})` 自动推断为 `PlayersTable`

```bash
sleet generate schema.lua
# → .sleet/types.lua

sleet generate schema.lua --out path/to/types.lua
```

生成后，完整推断链无需任何手写注解：

```
db.select()          → SleetPreSelectBuilder
.from(s.players)     → PlayersSelectBuilder
.where(...)          → PlayersSelectBuilder
.execute()           → PlayersRecord[]  ✓
```

> **注意**：`from()` 只有在运行 `sleet generate` 之后才会被 LuaLS 识别。
> 这是有意的设计 — `from` 仅在生成文件中声明，以防 LuaLS 产生联合返回类型破坏推断链。

---

### `sleet sql` — 生成建表 SQL

```bash
sleet sql schema.lua
# → server/schema.sql

sleet sql schema.lua -o database/init.sql
sleet sql schema.lua --stdout
```

`.comment()` 的描述会写入 SQL `COMMENT` 子句：

```sql
`money` INT NULL DEFAULT 500 COMMENT '现金',
```

---

### `sleet pull` — 逆向工程现有数据库

连接 MySQL，读取 `information_schema`，生成与现有表对应的 `schema.lua`。

```bash
sleet pull --host 127.0.0.1 --db myserver
# 打印 schema.lua 到 stdout

sleet pull --host 127.0.0.1 --user root --pass s3cr3t --db myserver -o schema.lua
```

---

## IDE 配置（Lua Language Server）

### 第一步 — 确保 LuaLS 能索引到 Sleet

**场景 A：sleet 与你的资源在同一工作区（推荐）**

如果你的工作区根目录就是 `resources/` 文件夹（或包含它的父目录），LuaLS 会自动扫描并识别 `sleet/lib/` 下的所有注解——**无需任何额外配置**。

**场景 B：sleet 安装在独立目录**

在项目根目录创建或更新 `.luarc.json`：

```json
{
    "workspace": {
        "library": ["path/to/sleet/lib"]
    }
}
```

配置完成后重启 LuaLS，即可获得：

-   所有列类型、操作符、构建器方法的自动补全
-   每列的 `ColumnDef<T>` 类型（如 `s.players.money → ColumnDef<integer>`）
-   `Sleet` 全局变量不再报"未定义"

### 第二步 — 生成类型（SELECT 推断必需）

```bash
sleet generate schema.lua
# → .sleet/types.lua
```

将生成的 `.sleet/` 目录提交到版本控制。如果 LuaLS 未自动识别，再将其加入 `.luarc.json`（场景 B 用户需要）：

```json
{
    "workspace": {
        "library": ["path/to/sleet/lib", "path/to/my-resource/.sleet"]
    }
}
```

之后完整推断链全程生效，**零手写注解**：

```lua
local rows = db.select().from(s.players).execute()
-- rows: PlayersRecord[]  ✓

local p = rows[1]
-- p.name:     string  ✓
-- p.money:    integer ✓
-- p.is_admin: boolean ✓
```

### 仍需手写 `---@type` 的场景

| 查询模式                             | 原因                               |
| ------------------------------------ | ---------------------------------- |
| `sl.sql('COUNT(*) AS total')` 等聚合 | 列名来自原始 SQL，CLI 无法静态分析 |
| JOIN 多表混合查询且指定了列          | 行形状是多个 `XxxRecord` 的混合    |

```lua
-- 聚合查询
---@type { total: integer }[]
local result = db.select({ sl.sql('COUNT(*) AS total') }).from(s.players).execute()
local total  = result[1].total  -- ✓

-- JOIN 结果
---@type table[]
local rows = db.select({ s.orders.id, s.players.name })
    .from(s.orders)
    .leftJoin(s.players, sl.eq(s.orders.player_id, s.players.id))
    .execute()
```

### 第三步（可选）— LuaLS 插件

在 Schema 文件中，LuaLS 有时将列类型显示为 `ColumnDef<<T>>` 而非 `ColumnDef<integer>`。Sleet 附带一个可选插件，在 LuaLS 内部重写文件文本（不修改实际文件）来稳定这些类型：

```json
{
    "Lua.runtime.plugin": "${workspaceFolder}/resources/[sleet]/sleet/lls-plugin/sleet.lua"
}
```

> 该插件是 LuaLS < 3.17 的兼容层。现代 LuaLS 上生成的 `XxxTable` 类已携带精确的 `ColumnDef<T>` 字段，通常无需此插件。

---

## 类型推断速览

| 你写的代码                                  | LuaLS 推断为                       |
| ------------------------------------------- | ---------------------------------- |
| `sl.table('players', { money = sl.int() })` | `PlayersTable`（通过 `@overload`） |
| `s.players.money`                           | `ColumnDef<integer>`               |
| `db.select().from(s.players)`               | `PlayersSelectBuilder`             |
| `.where(...).limit(1).execute()`            | `PlayersRecord[]`                  |
| `rows[1]`                                   | `PlayersRecord`                    |
| `rows[1].money`                             | `integer`                          |
| `sl.sql('COUNT(*) AS total')` 聚合          | `table[]` — 需手动标注             |

---

## 贡献

Sleet 是开源的，欢迎社区贡献。

1. Fork 仓库
2. 创建特性分支：`git checkout -b feat/my-feature`
3. 提交修改
4. 发起 Pull Request

**核心理念：简单、高效、优雅。** 只有解决真实痛点时才增加复杂度。

### 开发环境

**Lua 库** — 编辑 `lib/` 下的文件，在本地 FiveM 服务器测试。

**CLI** — 需要 Go 1.21+：

```bash
cd sleet/cli
go mod tidy
go run . generate ../server/schema.lua
```

---

## 许可证

MIT — 详见 [LICENSE](LICENSE)
