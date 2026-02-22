local dialect = require 'lib.dialect'

local UpdateBuilder = {}
UpdateBuilder.__index = UpdateBuilder

---@param data table key-value 对, key: 列名
function UpdateBuilder:set(data)
    self._set = data
    return self
end

---@param cond table 条件 AST
function UpdateBuilder:where(cond)
    self._where = cond
    return self
end

---执行更新，返回受影响行数
function UpdateBuilder:execute()
    assert(self._set, '[Sleet] update():set() must be called before execute()')
    local sql, params = dialect.buildUpdate(self)
    return MySQL.update.await(sql, params)
end

---返回 SQL 字符串及参数
function UpdateBuilder:toSQL()
    assert(self._set, '[Sleet] update():set() must be called before toSQL()')
    return dialect.buildUpdate(self)
end

local M = {}

---@param tbl table 目标表定义
function M.new(tbl)
    return setmetatable({ _table = tbl }, UpdateBuilder)
end

return M
