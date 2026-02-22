[English] | [简体中文](README_CN.md)

# ❄ Sleet

> Elegant ORM for FiveM + oxmysql — inspired by Drizzle

Sleet brings the **schema-as-code** philosophy of [Drizzle ORM](https://orm.drizzle.team/) to FiveM's Lua scripting environment. Define your tables once in Lua, get type-safe queries with zero raw SQL strings.

```lua
local sl = Sleet
local s  = require 'server.schema'
local db = sl.connect()

-- Full type inference — no manual ---@type needed
local players = db.select()
    .from(s.players)
    .where(sl.eq(s.players.identifier, identifier))
    .execute()
-- players: PlayersRecord[]  ✓  (inferred by LuaLS automatically)
```

---

## Features

-   **Schema as code** — define tables in Lua, not SQL strings
-   **Chainable query builder** — SELECT / INSERT / UPDATE / DELETE with fluent dot-notation chaining
-   **Full type inference** — after running `sleet generate`, LuaLS infers `XxxRecord[]` from `.execute()` without any manual `---@type`
-   **Column comments** — `.comment('description')` propagates to IDE hover hints and SQL `COMMENT` clauses
-   **Safe by default** — all values use parameterized `?` placeholders; SQL injection is impossible
-   **Transparent** — every query has a `.toSQL()` debug method
-   **Raw SQL escape hatch** — `sl.sql()` for expressions like `COUNT(*)`, atomic increments, etc.
-   **Zero runtime dependencies** — only requires [oxmysql](https://github.com/overextended/oxmysql)
-   **Built-in `require` system** — ships its own `package`/`require` shim (modeled after ox_lib); works with or without ox_lib. Use `require 'server.schema'` natively in any script.
-   **CLI tooling** — single Go binary (`sleet`) generates EmmyLua type annotations and `CREATE TABLE` SQL

---

## Installation

### 1. Add the resource

```bash
git clone https://github.com/SleetCo/sleet-orm [sleet]/sleet
```

### 2. server.cfg

```cfg
ensure oxmysql
ensure your_sleet_user_resource
```

### 3. Your resource's fxmanifest.lua

```lua
fx_version 'cerulean'
game 'gta5'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@sleet/sleet.lua',    -- injects global `Sleet` + installs package/require shim
    'server/main.lua',     -- use require 'server.schema' inside scripts
}
```

---

## Quick Start

### Define your schema

```lua
-- server/schema.lua
local sl = Sleet  -- global injected by @sleet/sleet.lua

local players = sl.table('players', {
    id         = sl.serial().primaryKey().comment('Auto-increment player ID'),
    identifier = sl.varchar(64).notNull().unique().comment('Steam / Discord identifier'),
    name       = sl.varchar(255).notNull().comment('Player display name'),
    money      = sl.int().default(500).comment('Cash on hand'),
    bank       = sl.int().default(2500).comment('Bank balance'),
    is_admin   = sl.boolean().default(false).comment('Admin flag'),
    metadata   = sl.json().comment('Extended data'),
    last_seen  = sl.timestamp().defaultNow().comment('Last online'),
})

-- Return the module — loaded via require 'server.schema' from other scripts
return { players = players }
```

### Query

```lua
-- server/main.lua
local sl = Sleet
local s  = require 'server.schema'
local db = sl.connect()

-- SELECT — LuaLS infers PlayersRecord[] automatically after running `sleet generate`
local rows = db.select()
    .from(s.players)
    .where(sl.eq(s.players.identifier, identifier))
    .limit(1)
    .execute()

local player = rows[1]  -- player: PlayersRecord ✓

-- INSERT — returns insertId
local newId = db.insert(s.players)
    .values({ identifier = 'steam:xxx', name = GetPlayerName(source) })
    .execute()

-- UPDATE — returns rowsChanged
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

## Column Types

| Sleet              | MySQL DDL               | Lua type  |
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

### Column Modifiers (all dot-notation, chainable)

```lua
sl.serial().primaryKey()               -- PRIMARY KEY + NOT NULL
sl.varchar(64).notNull()               -- NOT NULL
sl.varchar(64).unique()                -- UNIQUE
sl.int().default(0)                    -- DEFAULT 0
sl.timestamp().defaultNow()            -- DEFAULT CURRENT_TIMESTAMP
sl.int().autoIncrement()               -- AUTO_INCREMENT
sl.int().references(other.id)          -- FOREIGN KEY (used by CLI)
sl.varchar(64).comment('description')  -- IDE hover hint + SQL COMMENT
```

---

## Query API

### SELECT

```lua
-- All rows
db.select().from(s.players).execute()

-- WHERE
db.select().from(s.players).where(sl.eq(s.players.id, 1)).execute()

-- Specific columns
db.select({ s.players.id, s.players.name }).from(s.players).execute()

-- ORDER BY + LIMIT + OFFSET (pagination)
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

-- Aggregate / raw SQL columns — annotate the result shape manually
---@type { total: integer }[]
local result = db.select({ sl.sql('COUNT(*) AS total') }).from(s.players).execute()
local total = result[1].total
```

### INSERT

```lua
local newId = db.insert(s.players)
    .values({ identifier = 'steam:xxx', name = 'John' })
    .execute()  -- returns insertId (integer)
```

### UPDATE

```lua
-- Plain values
local affected = db.update(s.players)
    .set({ money = 1000, bank = 5000 })
    .where(sl.eq(s.players.identifier, 'steam:xxx'))
    .execute()  -- returns rowsChanged (integer)

-- Atomic expression via sl.sql (safe for concurrent updates)
db.update(s.players)
    .set({ bank = sl.sql('`bank` + ?', { 500 }) })
    .where(sl.eq(s.players.id, 1))
    .execute()
```

### DELETE

```lua
db.delete(s.players)
    .where(sl.eq(s.players.id, playerId))
    .execute()  -- returns rowsChanged (integer)
```

### toSQL (debug)

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

## Operators

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

-- Logical
sl.and_(cond1, cond2, ...)   -- (cond1 AND cond2 AND ...)
sl.or_(cond1, cond2, ...)    -- (cond1 OR  cond2 OR  ...)
sl.not_(cond)                -- NOT (cond)
```

---

## CLI (`sleet`)

Single self-contained binary written in Go — no Node, no Python, no runtime.

### Install

**npm (recommended)** — global install:

```bash
npm install -g sleet-orm-cli
```

**Download a pre-built binary** from [GitHub Releases](https://github.com/SleetCo/sleet-orm-cli/releases):

| Platform    | File           |
| ----------- | -------------- |
| Windows x64 | `sleet.exe`    |
| Linux x64   | `sleet`        |
| macOS x64   | `sleet-darwin` |

Place it on your `PATH` (or run it directly from your project root).

**Or build from source** (requires Go 1.21+):

```bash
cd cli
go build -o sleet .
```

---

### `sleet generate` — EmmyLua type annotations

Executes your `schema.lua` in an embedded Lua VM, intercepts all `sl.table()` calls,
and outputs a `---@meta` file with:

-   `XxxRecord` — row shape for SELECT results (fields with Lua types + descriptions)
-   `XxxTable` — schema object with `ColumnDef<T>` fields (e.g. `s.players.money → ColumnDef<integer>`)
-   `XxxSelectBuilder` — concrete builder per table; `execute()` returns `XxxRecord[]`
-   `Sleet.table` `@overload` — `sl.table('players', {...})` returns `PlayersTable` automatically

```bash
sleet generate schema.lua
# → .sleet/types.lua

sleet generate schema.lua --out path/to/types.lua
```

After running this once, LuaLS infers full types throughout the chain with **zero manual annotations**:

```
db.select()          → SleetPreSelectBuilder
.from(s.players)     → PlayersSelectBuilder
.where(...)          → PlayersSelectBuilder
.execute()           → PlayersRecord[]  ✓
```

> **Note**: `from()` is only recognized by LuaLS after running `sleet generate`.
> This is by design — `from` is declared exclusively in the generated file to
> avoid LuaLS creating a union return type that would break inference.

---

### `sleet sql` — Generate CREATE TABLE SQL

```bash
sleet sql schema.lua
# → server/schema.sql

sleet sql schema.lua -o database/init.sql
sleet sql schema.lua --stdout
```

Column descriptions from `.comment()` are written as SQL `COMMENT` clauses:

```sql
`money` INT NULL DEFAULT 500 COMMENT 'Cash on hand',
```

---

### `sleet pull` — Reverse-engineer a live database

Connects to MySQL, reads `information_schema`, and generates a `schema.lua` that mirrors your existing tables.

```bash
sleet pull --host 127.0.0.1 --db myserver
# prints schema.lua to stdout

sleet pull --host 127.0.0.1 --user root --pass s3cr3t --db myserver -o schema.lua
```

---

## IDE Setup (Lua Language Server)

### Step 1 — Make sure LuaLS can see Sleet

**Scenario A — Sleet lives in the same workspace as your resources (recommended)**

If your workspace root is the `resources/` folder (or any parent that includes it), LuaLS will automatically scan and index `sleet/lib/` — **no extra configuration needed**.

**Scenario B — Sleet is installed in a separate directory**

Create or update `.luarc.json` at your project root:

```json
{
    "workspace": {
        "library": ["path/to/sleet/lib"]
    }
}
```

Restart LuaLS. You immediately get:

-   Autocomplete for all column types, operators, and builder methods
-   `ColumnDef<T>` recognized for each column (`s.players.money → ColumnDef<integer>`)
-   No "undefined global" warning for `Sleet`

### Step 2 — Generate types (required for SELECT inference)

```bash
sleet generate schema.lua
# → .sleet/types.lua
```

Commit the generated `.sleet/` directory to version control. If LuaLS doesn't pick it up automatically, add it to `.luarc.json` (Scenario B users):

```json
{
    "workspace": {
        "library": ["path/to/sleet/lib", "path/to/my-resource/.sleet"]
    }
}
```

After this, the full inference chain works without any `---@type`:

```lua
local rows = db.select().from(s.players).execute()
-- rows: PlayersRecord[]  ✓

local p = rows[1]
-- p.name:     string  ✓
-- p.money:    integer ✓
-- p.is_admin: boolean ✓
```

### When you still need manual `---@type`

Two cases always require a manual annotation:

| Query pattern                           | Reason                                                              |
| --------------------------------------- | ------------------------------------------------------------------- |
| `sl.sql('COUNT(*) AS total')` aggregate | Column names come from raw SQL — CLI cannot analyze them statically |
| Multi-table JOIN with selected columns  | Row shape is a mix of multiple `XxxRecord` types                    |

```lua
-- Aggregate
---@type { total: integer }[]
local result = db.select({ sl.sql('COUNT(*) AS total') }).from(s.players).execute()

-- JOIN result
---@type table[]
local rows = db.select({ s.orders.id, s.players.name })
    .from(s.orders)
    .leftJoin(s.players, sl.eq(s.orders.player_id, s.players.id))
    .execute()
```

### Step 3 (Optional) — LuaLS plugin for column type stabilization

In schema files, LuaLS sometimes shows column types as `ColumnDef<<T>>` instead of
`ColumnDef<integer>`. Sleet ships an optional plugin that rewrites the file text
_inside LuaLS only_ (your actual files are untouched) to stabilize these types.

```json
{
    "Lua.runtime.plugin": "${workspaceFolder}/resources/[sleet]/sleet/lls-plugin/sleet.lua"
}
```

> This plugin is a compatibility layer for LuaLS < 3.17. On modern LuaLS the
> generated `XxxTable` class already carries precise `ColumnDef<T>` fields.

---

## Type Inference at a Glance

| What you write                              | LuaLS infers                     |
| ------------------------------------------- | -------------------------------- |
| `sl.table('players', { money = sl.int() })` | `PlayersTable` (via `@overload`) |
| `s.players.money`                           | `ColumnDef<integer>`             |
| `db.select().from(s.players)`               | `PlayersSelectBuilder`           |
| `.where(...).limit(1).execute()`            | `PlayersRecord[]`                |
| `rows[1]`                                   | `PlayersRecord`                  |
| `rows[1].money`                             | `integer`                        |
| `sl.sql('COUNT(*) AS total')` aggregate     | `table[]` — annotate manually    |

---

## Contributing

Sleet is open source and community-driven.

1. Fork the repo
2. Create a feature branch: `git checkout -b feat/my-feature`
3. Commit your changes
4. Open a Pull Request

**Core philosophy: simple, efficient, elegant.** Avoid adding complexity unless it solves a real pain point.

### Development

**Lua library** — edit files in `lib/`, test with a local FiveM server.

**CLI** — requires Go 1.21+:

```bash
cd sleet/cli
go mod tidy
go run . generate ../server/schema.lua
```

---

## License

MIT — see [LICENSE](LICENSE)
