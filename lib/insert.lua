local dialect = require 'lib.dialect'

local InsertBuilder = {}
InsertBuilder.__index = InsertBuilder

---@param data table 键值对: key - 列名
function InsertBuilder:values(data)
    self._values = data
    return self
end

---执行插入, 返回新行的 ID: insertId
function InsertBuilder:execute()
    assert(self._values, '[Sleet] insert():values() must be called before execute()')
    local sql, params = dialect.buildInsert(self)
    return MySQL.insert.await(sql, params)
end

---返回 SQL 字符串及参数
function InsertBuilder:toSQL()
    assert(self._values, '[Sleet] insert():values() must be called before toSQL()')
    return dialect.buildInsert(self)
end

local M = {}

---@param tbl table 目标表定义
function M.new(tbl)
    return setmetatable({ _table = tbl }, InsertBuilder)
end

return M
