local schema = require 'lib._schema'

local TableMeta          = {}
TableMeta.__index        = TableMeta
TableMeta._sleetTable    = true

local M = {}

---定义一张数据库表
---@param name    string 表名
---@param columns table  列定义 map, key 为列名
---@return table
function M.define(name, columns)
    local tbl = setmetatable({
        _tableName = name,
        _columns   = {},
    }, TableMeta)

    for colName, colDef in pairs(columns) do
        if schema.isColumn(colDef) then
            local clonedCol = {}
            for k, v in pairs(colDef) do clonedCol[k] = v end
            setmetatable(clonedCol, getmetatable(colDef))

            clonedCol._name      = colName
            clonedCol._tableName = name

            tbl[colName] = clonedCol
            table.insert(tbl._columns, { name = colName, def = clonedCol })
        end
    end

    return tbl
end

function M.isTable(val)
    local mt = getmetatable(val)
    return mt ~= nil and mt._sleetTable == true
end

return M
