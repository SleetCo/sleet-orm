local dialect = require 'lib.dialect'

local SelectBuilder = {}
SelectBuilder.__index = SelectBuilder

---@param tbl table 目标表定义
function SelectBuilder:from(tbl)
    self._from = tbl
    return self
end

---@param cond table 条件 AST
function SelectBuilder:where(cond)
    self._where = cond
    return self
end

---@param n integer
function SelectBuilder:limit(n)
    self._limit = n
    return self
end

---@param n integer
function SelectBuilder:offset(n)
    self._offset = n
    return self
end

---@param col table 列定义
---@param dir string? 'asc' | 'desc': 默认 'asc'
function SelectBuilder:orderBy(col, dir)
    self._orderBy = { col = col, dir = dir or 'asc' }
    return self
end

---@param col table 列定义
function SelectBuilder:groupBy(col)
    self._groupBy = col
    return self
end

---@param tbl table 要 JOIN 的表定义
---@param on  table ON 条件 AST
function SelectBuilder:leftJoin(tbl, on)
    if not self._joins then self._joins = {} end
    table.insert(self._joins, { type = 'LEFT', tbl = tbl, on = on })
    return self
end

---@param tbl table
---@param on  table
function SelectBuilder:innerJoin(tbl, on)
    if not self._joins then self._joins = {} end
    table.insert(self._joins, { type = 'INNER', tbl = tbl, on = on })
    return self
end

---@param tbl table
---@param on  table
function SelectBuilder:rightJoin(tbl, on)
    if not self._joins then self._joins = {} end
    table.insert(self._joins, { type = 'RIGHT', tbl = tbl, on = on })
    return self
end

---执行查询，返回结果数组
function SelectBuilder:execute()
    local sql, params = dialect.buildSelect(self)
    return MySQL.query.await(sql, params)
end

---返回 SQL 字符串及参数
function SelectBuilder:toSQL()
    return dialect.buildSelect(self)
end

local M = {}

---@param cols table? 指定返回的列，nil 或 {} 表示 SELECT *
function M.new(cols)
    return setmetatable({ _cols = cols or {} }, SelectBuilder)
end

return M
