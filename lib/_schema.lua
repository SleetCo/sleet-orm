-- Column metatable — 所有列类型共享此 metatable
-- 使用"绑定闭包"__index, 使链式调用可以全程使用点号:
--   sl.serial().primaryKey().notNull().default(0)
-- *** 注意：有意不兼容冒号语法(两者不能同时正确支持) ***
--
-- ColumnDef<T> 的类型声明在 lib/annotations.lua（meta 文件）中
-- 这样 LLS 不会被此处的 __index 函数干扰字段推断
local Column     = {}
Column._sleetCol = true

Column.__index = function(self, key)
    if type(key) ~= 'string' or key:sub(1, 1) == '_' then return nil end
    local fn = rawget(Column, key)
    if type(fn) == 'function' then
        return function(...) return fn(self, ...) end
    end
end

function Column.primaryKey(self)
    self._pk      = true
    self._notNull = true
    return self
end

function Column.notNull(self)
    self._notNull = true
    return self
end

function Column.unique(self)
    self._unique = true
    return self
end

---@param val any 默认值
function Column.default(self, val)
    self._default    = val
    self._hasDefault = true
    return self
end

function Column.defaultNow(self)
    self._defaultNow = true
    return self
end

function Column.autoIncrement(self)
    self._autoIncrement = true
    return self
end

---@param col table 引用的列 (maybe from sl.table)
function Column.references(self, col)
    self._references = col
    return self
end

---@param text string 列的描述文字: 传播到生成的 types.lua 注释和 SQL COMMENT
function Column.comment(self, text)
    self._comment = text
    return self
end

local function newCol(opts)
    return setmetatable(opts, Column)
end

local function isColumn(val)
    local mt = getmetatable(val)
    return mt ~= nil and mt._sleetCol == true
end

local M = {}

-- 整数类型 (AUTO_INCREMENT)
---@return ColumnDef<integer>
function M.serial()     return newCol({ _type = 'INT',      _autoIncrement = true }) end
---@return ColumnDef<integer>
function M.bigserial()  return newCol({ _type = 'BIGINT',   _autoIncrement = true }) end

-- 普通整数
---@return ColumnDef<integer>
function M.int()        return newCol({ _type = 'INT'      }) end
---@return ColumnDef<integer>
function M.bigint()     return newCol({ _type = 'BIGINT'   }) end
---@return ColumnDef<integer>
function M.smallint()   return newCol({ _type = 'SMALLINT' }) end
---@return ColumnDef<integer>
function M.tinyint()    return newCol({ _type = 'TINYINT'  }) end

-- 浮点
---@return ColumnDef<number>
function M.float()      return newCol({ _type = 'FLOAT'  }) end
---@return ColumnDef<number>
function M.double()     return newCol({ _type = 'DOUBLE' }) end

---@param precision integer?
---@param scale     integer?
---@return ColumnDef<number>
function M.decimal(precision, scale)
    return newCol({ _type = 'DECIMAL', _precision = precision or 10, _scale = scale or 2 })
end

-- 字符串
---@param len integer? 最大长度 (默认 255)
---@return ColumnDef<string>
function M.varchar(len) return newCol({ _type = 'VARCHAR', _len = len or 255 }) end

---@param len integer? 固定长度 (默认 1)
---@return ColumnDef<string>
function M.char(len)    return newCol({ _type = 'CHAR',    _len = len or 1   }) end

---@return ColumnDef<string>
function M.text()       return newCol({ _type = 'TEXT'       }) end
---@return ColumnDef<string>
function M.mediumtext() return newCol({ _type = 'MEDIUMTEXT' }) end
---@return ColumnDef<string>
function M.longtext()   return newCol({ _type = 'LONGTEXT'   }) end

-- 布尔 (注意: MySQL 仍然用 TINYINT(1) 表示)
---@return ColumnDef<boolean>
function M.boolean()    return newCol({ _type = 'BOOLEAN'   }) end

-- 时间
---@return ColumnDef<string>
function M.timestamp()  return newCol({ _type = 'TIMESTAMP' }) end
---@return ColumnDef<string>
function M.datetime()   return newCol({ _type = 'DATETIME'  }) end
---@return ColumnDef<string>
function M.date()       return newCol({ _type = 'DATE'      }) end

-- JSON (如果不支持JSON, 会自动转为 longtext)
---@return ColumnDef<table>
function M.json()       return newCol({ _type = 'JSON' }) end

M.isColumn = isColumn

return M
