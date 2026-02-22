local dialect = require 'lib.dialect'

local DeleteBuilder = {}
DeleteBuilder.__index = DeleteBuilder

---@param cond table 条件 AST
function DeleteBuilder:where(cond)
    self._where = cond
    return self
end

---执行删除, 返回受影响行数
function DeleteBuilder:execute()
    local sql, params = dialect.buildDelete(self)
    return MySQL.update.await(sql, params)
end

---返回 SQL 字符串及参数, 不执行（调试用）
function DeleteBuilder:toSQL()
    return dialect.buildDelete(self)
end

local M = {}

---@param tbl table 目标表定义
function M.new(tbl)
    return setmetatable({ _table = tbl }, DeleteBuilder)
end

return M
