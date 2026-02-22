--[[
    Sleet ORM v1.0.0
    Elegant ORM for FiveM + oxmysql, inspired by Drizzle
    https://github.com/SleetCo/sleet-orm

    Usage (in consuming resource's fxmanifest.lua):
        server_scripts {
            '@oxmysql/lib/MySQL.lua',
            '@sleet/sleet.lua',
            'server/*.lua',
        }

    Then in your server scripts:
        local sl = Sleet
        local users = sl.table('users', { id = sl.serial():primaryKey() })
--]]

local _debug = true

local _version = GetResourceMetadata('sleet', 'version', -1) or '0.1.0'

local _sleetRes = (debug.getinfo(1, 'S').source or ''):match('^@@([^/]+)') or 'sleet'

local _log = function(msg)
    if not _debug then return end
    print(("^5[%s-Sleet]^7 "):format(_version) .. msg)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- package / require shim
-- 仅在当前环境没有 `package` 全局时安装 (用于 ox_lib 未加载的情况)
-- 实现方式参考了 ox_lib 的 require 模块设计, 感谢 ox_lib 的开源贡献!!!
--   https://github.com/overextended/ox_lib
--
-- 核心特性 (与 ox_lib 兼容，两者可混用)：
--   · 支持 '@resource/mod.name' 跨资源语法
--   · 通过 debug 调用栈自动识别调用方资源名
--   · package.path / package.preload / package.searchers / package.loaded
-- ─────────────────────────────────────────────────────────────────────────────
if not rawget(_G, 'package') then
    local _native  = require
    local _modules = {}

    local _shimMark = ('@@%s/sleet'):format(_sleetRes)
    local function resolveResource(modName)
        local res = modName:match('^@(.-)/.+')
        if res then
            return res, modName:sub(#res + 3) -- '@res/a.b' → res, 'a/b'
        end
        local idx = 4 -- 跳过?
        while true do
            local info = debug.getinfo(idx, 'S')
            if not info or not info.source then
                return GetCurrentResourceName(), modName -- 继续兜底?
            end
            local src = info.source
            local r   = src:match('^@@([^/]+)/')
            if r and not src:find(_shimMark, 1, true) then
                return r, modName
            end
            idx = idx + 1
        end
    end

    package = {
        path    = './?.lua;./?/init.lua',
        preload = {},
        loaded  = setmetatable({}, {
            __index     = _modules,
            __newindex  = function() end,
            __metatable = false,
        }),
    }

    local function _loadChunk(modName)
        local resource, relPath = resolveResource(modName:gsub('%.', '/'))
        local tried = {}
        for tpl in package.path:gmatch('[^;]+') do
            local fileName = tpl:gsub('^%./', ''):gsub('%?', relPath)
            local src = LoadResourceFile(resource, fileName)
            if src then
                return assert(load(src, ('@@%s/%s'):format(resource, fileName), 't', _ENV))
            end
            tried[#tried + 1] = ("no file '@%s/%s'"):format(resource, fileName)
        end
        return nil, table.concat(tried, '\n\t')
    end

    -- function package.searchpath(name, path)
    --     local resource, relPath = resolveResource(name:gsub('%.', '/'))
    --     local tried = {}
    --     for tpl in (path or package.path):gmatch('[^;]+') do
    --         local fileName = tpl:gsub('^%./', ''):gsub('%?', relPath)
    --         if LoadResourceFile(resource, fileName) then
    --             return fileName
    --         end
    --         tried[#tried + 1] = ("no file '@%s/%s'"):format(resource, fileName)
    --     end
    --     return nil, table.concat(tried, '\n\t')
    -- end

    package.searchers = {
        function(mod)
            local ok, r = pcall(_native, mod)
            -- fix?: tostring(r) or nil
            return ok and r or nil, not ok and tostring(r) or ''
        end,
        function(mod)
            if package.preload[mod] then return package.preload[mod] end
            return nil, ("no field package.preload['%s']"):format(mod)
        end,
        function(mod)
            return _loadChunk(mod)
        end,
    }

    require = function(modName)
        assert(type(modName) == 'string',
            ("require wanna string, but get '%s'"):format(type(modName)))

        local m = _modules[modName]
        if m == '__loading' then
            error(("Dependency looped: '%s'"):format(modName), 2)
        end
        if m ~= nil then return m end

        _modules[modName] = '__loading'
        local errs = {}

        for _, searcher in ipairs(package.searchers) do
            local result, err = searcher(modName)
            if result then
                if type(result) == 'function' then result = result() end
                _modules[modName] = result ~= nil and result or true
                return _modules[modName]
            end
            if err then errs[#errs + 1] = tostring(err) end
        end

        _modules[modName] = nil
        error(("Module '%s' not found: \n\t%s"):format(modName, table.concat(errs, '\n\t')), 2)
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Sleet 内部模块加载器
-- ─────────────────────────────────────────────────────────────────────────────
local _sleetCache = {}

local function _sleetRequire(name)
    if _sleetCache[name] ~= nil then return _sleetCache[name] end

    local path = name:gsub('%.', '/') .. '.lua'
    local src  = LoadResourceFile(_sleetRes, path)
    assert(src, ('[Sleet] Module %s/%s not found'):format(_sleetRes, path))

    local function modRequire(n)
        if n:match('^lib%.') then return _sleetRequire(n) end
        return require(n)
    end
    local env = setmetatable({ require = modRequire }, { __index = _G, __newindex = _G })
    local fn  = assert(load(src, ('@@%s/%s'):format(_sleetRes, path), 't', env))

    _sleetCache[name] = fn() or true
    return _sleetCache[name]
end

local raw      = _sleetRequire 'lib.raw'
local schema   = _sleetRequire "lib._schema"
local tablemod = _sleetRequire 'lib.table'
local ops      = _sleetRequire 'lib.operators'
local select_  = _sleetRequire 'lib.select'
local insert_  = _sleetRequire 'lib.insert'
local update_  = _sleetRequire 'lib.update'
local delete_  = _sleetRequire 'lib.delete'

local function wrapDot(obj)
    local wrapper
    local meta = getmetatable(obj)
    wrapper = setmetatable({}, {
        __index = function(_, key)
            local fn = rawget(meta, key)
            if type(fn) == 'function' then
                return function(...)
                    local r = fn(obj, ...)
                    if r == obj then return wrapper end
                    return r
                end
            end
        end
    })
    return wrapper
end

-- DB 对象 — 查询构建器的入 (闭包)
local DB = {}
DB.__index = function(self, key)
    local fn = rawget(DB, key)
    if type(fn) == 'function' then
        return function(...) return fn(self, ...) end
    end
end

---开始一个 SELECT 查询
---@param cols table? 指定列: 如 { s.users.id, s.users.name }, nil 为 SELECT *
function DB.select(self, cols)
    return wrapDot(select_.new(cols))
end

---开始一个 INSERT 查询
---@param tbl table 目标表定义
function DB.insert(self, tbl)
    return wrapDot(insert_.new(tbl))
end

---开始一个 UPDATE 查询
---@param tbl table 目标表定义
function DB.update(self, tbl)
    return wrapDot(update_.new(tbl))
end

---开始一个 DELETE 查询
---@param tbl table 目标表定义
function DB.delete(self, tbl)
    return wrapDot(delete_.new(tbl))
end

local dbInstance = setmetatable({}, DB)

local Sleet = {}

-- 返回查询构建器
function Sleet.connect()
    return dbInstance
end

-- 表定义
---@generic T: table
---@param name string
---@param columns T
---@return T
function Sleet.table(name, columns)
    return tablemod.define(name, columns)
end

-- 列类型
Sleet.serial     = schema.serial
Sleet.bigserial  = schema.bigserial
Sleet.int        = schema.int
Sleet.bigint     = schema.bigint
Sleet.smallint   = schema.smallint
Sleet.tinyint    = schema.tinyint
Sleet.float      = schema.float
Sleet.double     = schema.double
Sleet.decimal    = schema.decimal
Sleet.varchar    = schema.varchar
Sleet.char       = schema.char
Sleet.text       = schema.text
Sleet.mediumtext = schema.mediumtext
Sleet.longtext   = schema.longtext
Sleet.boolean    = schema.boolean
Sleet.timestamp  = schema.timestamp
Sleet.datetime   = schema.datetime
Sleet.date       = schema.date
Sleet.json       = schema.json

-- 操作符
Sleet.eq         = ops.eq
Sleet.ne         = ops.ne
Sleet.gt         = ops.gt
Sleet.gte        = ops.gte
Sleet.lt         = ops.lt
Sleet.lte        = ops.lte
Sleet.like       = ops.like
Sleet.ilike      = ops.ilike
Sleet.notLike    = ops.notLike
Sleet.isNull     = ops.isNull
Sleet.isNotNull  = ops.isNotNull
Sleet.inArray    = ops.inArray
Sleet.notInArray = ops.notInArray
Sleet.between    = ops.between
Sleet.and_       = ops.and_
Sleet.or_        = ops.or_
Sleet.not_       = ops.not_

-- 原始 SQL 转义口
Sleet.sql = raw.sql

---@type Sleet
local SleetAPI = Sleet
_G.Sleet = SleetAPI

-- 注册到 package.loaded / package.preload, 支持 require 'sleet'
if rawget(_G, 'package') then
    package.preload['sleet'] = function() return SleetAPI end
end

local _resource = GetCurrentResourceName() or 'unknown'
_log(("Loaded in resource: ^2%s^7"):format(_resource))


return SleetAPI
