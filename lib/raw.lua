---@class RawSQL
---@field _fragment string
---@field _params   table

local RawMeta        = {}
RawMeta.__index      = RawMeta
RawMeta._sleetRaw    = true

---@param fragment string  SQL 片段，可包含 ? 占位符
---@param params   table?  参数列表
---@return RawSQL
local function sql(fragment, params)
    return setmetatable({ _fragment = fragment, _params = params or {} }, RawMeta)
end

local function isRaw(val)
    local mt = getmetatable(val)
    return mt ~= nil and mt._sleetRaw == true
end

return { sql = sql, isRaw = isRaw }
