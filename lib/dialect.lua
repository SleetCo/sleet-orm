local raw = require 'lib.raw'

local M = {}

-- 标识符加反引号
local function q(name)
    return '`' .. tostring(name):gsub('`', '``') .. '`'
end

-- 将列定义或 RawSQL 转换为 SQL 片段
local function colRef(col)
    if raw.isRaw(col) then
        return col._fragment
    end
    if col._tableName and col._name then
        return q(col._tableName) .. '.' .. q(col._name)
    elseif col._name then
        return q(col._name)
    end
    return tostring(col)
end

-- 递归构建 WHERE 条件, 参数追加到 params 表
local function buildCond(cond, params)
    if not cond then return nil end

    local kind = cond._kind

    if kind == 'op' then
        -- 列对列比较: _val 为列定义时用 colRef, 否则作为参数
        local val = cond._val
        if val and type(val) == 'table' and val._tableName and val._name then
            return colRef(cond._col) .. ' ' .. cond._op .. ' ' .. colRef(val)
        end
        table.insert(params, val)
        return colRef(cond._col) .. ' ' .. cond._op .. ' ?'

    elseif kind == 'is_null' then
        return colRef(cond._col) .. ' IS NULL'

    elseif kind == 'is_not_null' then
        return colRef(cond._col) .. ' IS NOT NULL'

    elseif kind == 'in' or kind == 'not_in' then
        local ph = {}
        for _, v in ipairs(cond._vals) do
            table.insert(params, v)
            table.insert(ph, '?')
        end
        local keyword = kind == 'in' and 'IN' or 'NOT IN'
        return colRef(cond._col) .. ' ' .. keyword .. ' (' .. table.concat(ph, ', ') .. ')'

    elseif kind == 'between' then
        table.insert(params, cond._a)
        table.insert(params, cond._b)
        return colRef(cond._col) .. ' BETWEEN ? AND ?'

    elseif kind == 'and' then
        local parts = {}
        for _, c in ipairs(cond._conditions) do
            local s = buildCond(c, params)
            if s then table.insert(parts, s) end
        end
        return '(' .. table.concat(parts, ' AND ') .. ')'

    elseif kind == 'or' then
        local parts = {}
        for _, c in ipairs(cond._conditions) do
            local s = buildCond(c, params)
            if s then table.insert(parts, s) end
        end
        return '(' .. table.concat(parts, ' OR ') .. ')'

    elseif kind == 'not' then
        local inner = buildCond(cond._condition, params)
        return inner and ('NOT (' .. inner .. ')') or nil
    end

    return nil
end

-- SELECT 列列表
local function selectCols(cols)
    if not cols or #cols == 0 then return '*' end
    local parts = {}
    for _, col in ipairs(cols) do
        if raw.isRaw(col) then
            table.insert(parts, col._fragment)
        else
            table.insert(parts, colRef(col))
        end
    end
    return table.concat(parts, ', ')
end

function M.buildSelect(b)
    local params = {}
    local sql = 'SELECT ' .. selectCols(b._cols)

    sql = sql .. ' FROM ' .. q(b._from._tableName)

    if b._joins then
        for _, j in ipairs(b._joins) do
            local onSql = buildCond(j.on, params)
            sql = sql .. ' ' .. j.type .. ' JOIN ' .. q(j.tbl._tableName) .. ' ON ' .. onSql
        end
    end

    if b._where then
        local w = buildCond(b._where, params)
        if w then sql = sql .. ' WHERE ' .. w end
    end

    if b._groupBy then
        sql = sql .. ' GROUP BY ' .. colRef(b._groupBy)
    end

    if b._orderBy then
        local dir = (b._orderBy.dir or 'ASC'):upper()
        sql = sql .. ' ORDER BY ' .. colRef(b._orderBy.col) .. ' ' .. dir
    end

    if b._limit  then sql = sql .. ' LIMIT '  .. tostring(b._limit)  end
    if b._offset then sql = sql .. ' OFFSET ' .. tostring(b._offset) end

    return sql, params
end

function M.buildInsert(b)
    local params = {}
    local cols, ph = {}, {}

    for k, v in pairs(b._values) do
        table.insert(cols, q(k))
        table.insert(ph,   '?')
        table.insert(params, v)
    end

    local sql = 'INSERT INTO ' .. q(b._table._tableName)
        .. ' (' .. table.concat(cols, ', ') .. ')'
        .. ' VALUES (' .. table.concat(ph, ', ') .. ')'

    return sql, params
end

function M.buildUpdate(b)
    local params = {}
    local sets = {}

    for k, v in pairs(b._set) do
        if raw.isRaw(v) then
            table.insert(sets, q(k) .. ' = ' .. v._fragment)
            if v._params then
                for _, p in ipairs(v._params) do
                    table.insert(params, p)
                end
            end
        else
            table.insert(sets, q(k) .. ' = ?')
            table.insert(params, v)
        end
    end

    local sql = 'UPDATE ' .. q(b._table._tableName) .. ' SET ' .. table.concat(sets, ', ')

    if b._where then
        local w = buildCond(b._where, params)
        if w then sql = sql .. ' WHERE ' .. w end
    end

    return sql, params
end

function M.buildDelete(b)
    local params = {}
    local sql = 'DELETE FROM ' .. q(b._table._tableName)

    if b._where then
        local w = buildCond(b._where, params)
        if w then sql = sql .. ' WHERE ' .. w end
    end

    return sql, params
end

return M
