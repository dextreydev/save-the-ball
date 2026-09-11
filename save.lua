local love = require("love")

local Save = {}

-- save file name
local SAVE_FILE = "SAVE - DO NOT MODIFY.txt"

-- hey hacker, it seems you found out how to modify your save data so go ahead and cheat!

-- XOR helper for encryption/decryption
local function bxor(a, b)
    local r, m = 0, 1
    while a > 0 or b > 0 do
        local ab = (a % 2) ~= (b % 2) and 1 or 0
        r = r + ab * m
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        m = m * 2
    end
    return r
end

-- simple XOR encryption
local function encrypt(str, key)
    key = key or 0xAB
    local out = {}
    for i = 1, #str do
        local byte = str:byte(i)
        table.insert(out, string.char(bxor(byte, key)))
    end
    return table.concat(out)
end

local function decrypt(str, key)
    return encrypt(str, key)
end

-- serialize Lua table
local function serialize(val)
    local t = type(val)
    if t == "number" then
        return tostring(val)
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "table" then
        local parts = {}
        for k, v in pairs(val) do
            local key = type(k) == "number" and "[" .. k .. "]" or "[" .. string.format("%q", k) .. "]"
            table.insert(parts, key .. " = " .. serialize(v))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    else
        return "nil"
    end
end

local savePending = false
local saveDataCache = nil
local SAVE_DEBOUNCE = 0.5
local saveTimer = 0

-- schedule a save (debounced)
function Save:scheduleSave(data)
    saveDataCache = data
    savePending = true
    saveTimer = SAVE_DEBOUNCE
end

-- call this in love.update(dt) to flush pending saves
function Save:update(dt)
    if savePending then
        saveTimer = saveTimer - dt
        if saveTimer <= 0 then
            self:_doSave(saveDataCache)
            savePending = false
        end
    end
end

-- internal save function (immediate)
function Save:_doSave(data)
    local ok, err = pcall(function()
        local cleanData = {}

        -- keep numeric values as-is, or round to 2 decimals if you want
        for k, v in pairs(data) do
            if type(v) == "number" then
                cleanData[k] = math.floor(v * 100) / 100  -- rounds to 2 decimals
            else
                cleanData[k] = v
            end
        end

        local serialized = "return " .. serialize(cleanData)
        local encrypted = encrypt(serialized, 0xAB)
        love.filesystem.write(SAVE_FILE, encrypted)
    end)
    if not ok then
        print("[Save] ERROR: Could not write save file -", err)
        return false
    end
    print("[Save] Saved successfully to", SAVE_FILE)
    return true
end

-- immediate save (bypasses debounce)
function Save:save(data)
    savePending = false
    return self:_doSave(data)
end

-- load table
function Save:load()
    if not love.filesystem.getInfo(SAVE_FILE) then
        print("[Save] No save file found, returning empty table")
        return {}
    end

    local content, size = love.filesystem.read(SAVE_FILE)
    if not content then
        print("[Save] ERROR: Could not read save file")
        return {}
    end

    local decrypted = decrypt(content, 0xAB)
    local chunk, err = load(decrypted)
    if not chunk then
        print("[Save] ERROR: Could not parse save -", err)
        return {}
    end

    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then
        print("[Save] ERROR: Invalid save data -", result)
        return {}
    end

    print("[Save] Loaded data successfully")
    return result
end

return Save
