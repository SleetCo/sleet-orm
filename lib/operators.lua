-- ...

local function node(kind, data)
    data._kind = kind
    return data
end

local M = {}

-- 比较操作符
function M.eq(col, val)  return node('op', { _op = '=',    _col = col, _val = val }) end
function M.ne(col, val)  return node('op', { _op = '!=',   _col = col, _val = val }) end
function M.gt(col, val)  return node('op', { _op = '>',    _col = col, _val = val }) end
function M.gte(col, val) return node('op', { _op = '>=',   _col = col, _val = val }) end
function M.lt(col, val)  return node('op', { _op = '<',    _col = col, _val = val }) end
function M.lte(col, val) return node('op', { _op = '<=',   _col = col, _val = val }) end

-- 模糊匹配 注意: MySQL 默认大小写不敏感
function M.like(col, val)  return node('op', { _op = 'LIKE',     _col = col, _val = val }) end
function M.ilike(col, val) return node('op', { _op = 'LIKE',     _col = col, _val = val }) end
function M.notLike(col, val) return node('op', { _op = 'NOT LIKE', _col = col, _val = val }) end

-- NULL 判断
function M.isNull(col)    return node('is_null',     { _col = col }) end
function M.isNotNull(col) return node('is_not_null', { _col = col }) end

-- IN / NOT IN
---@param col  table 列定义
---@param vals table 值列表
function M.inArray(col, vals)    return node('in',     { _col = col, _vals = vals }) end
function M.notInArray(col, vals) return node('not_in', { _col = col, _vals = vals }) end

-- BETWEEN
function M.between(col, a, b) return node('between', { _col = col, _a = a, _b = b }) end

-- 逻辑组合: 接受其他参数?
function M.and_(...) return node('and', { _conditions = { ... } }) end
function M.or_(...)  return node('or',  { _conditions = { ... } }) end
function M.not_(cond) return node('not', { _condition = cond }) end

return M
