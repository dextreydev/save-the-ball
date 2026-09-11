local love = require("love")

BUTTON_HEIGHT = 50
local button_width = 250
local margin = 10
local BASE_WIDTH, BASE_HEIGHT = 1280, 720
local fontCache = {}

local sfxVolume = 0.3

local sounds = {
    hover = {
        play = function()
            local source = love.audio.newSource("sounds/sfx/hover.mp3", "static")
            source:setVolume(sfxVolume)
            source:play()
        end
    },
    click = {
        play = function()
            local source = love.audio.newSource("sounds/sfx/blip.wav", "static")
            source:setVolume(sfxVolume)
            source:play()
        end
    }
}
local sfx_play = true
local music_play = true

local function getButtonFont(size)
    size = math.floor(size)
    if not fontCache[size] then
        fontCache[size] = love.graphics.newFont(size)
    end
    return fontCache[size]
end

local function newButton(screen, text, fn, color1, color2, tble,
    customX, customY, customTxt, customXP, customYP, custom)

    local btn = {
        text = text,
        customText = customTxt,
        fn = fn,

        now = false,
        last = false,
        targetScale = 1,
        scale = 1,

        lastHot = false,
        newHot = false,
        hot = false,

        color1 = color1,
        color2 = color2,

        -- ratio-based positions
        rx = customX,
        ry = customY,

        -- scaled pixel positions
        x = customXP,
        y = customYP,

        x1 = 1,
        y1 = 1,

        nav = (custom and custom.nav) or "vertical",
        group = (custom and custom.group) or "default",
    }

    table.insert(tble[screen], btn)
end

local Button = {}

function Button:create(screen, text, fn, color1, color2, tble, customX, customY, customTxt, customXP, customYP, custom)
    newButton(screen, text, fn, color1, color2, tble, customX, customY, customTxt, customXP, customYP, custom)
end

function Button:setSfx(val) sfx_play = val end
function Button:getSfx() return sfx_play end

function Button:setMusic(val) music_play = val end
function Button:getMusic() return music_play end

function Button:update(dt, buttons, _sfxVolume)
    sfxVolume = _sfxVolume and _sfxVolume or 0.3
    local speed = 12
    for _, btn in ipairs(buttons) do
        btn.scale = btn.scale + (btn.targetScale - btn.scale) * speed * dt
    end
end

function Button:draw(table, scaleX, scaleY, font, startY)
    local mx, my = love.mouse.getPosition()
    local avgScale = (scaleX + scaleY) / 2

    for i, btn in ipairs(table) do
        local scaledButtonWidth = button_width * avgScale
        local scaledButtonHeight = BUTTON_HEIGHT * avgScale
        local scaledMargin = margin * avgScale

        local bx

        if btn.rx ~= nil then
            bx = btn.rx * love.graphics.getWidth()
        elseif btn.x ~= nil then
            bx = btn.x * avgScale
        else
            bx = love.graphics.getWidth() * 0.5 - scaledButtonWidth * 0.5
        end

        local by

        if btn.ry ~= nil then
            by = btn.ry * love.graphics.getHeight()
        elseif btn.y ~= nil then
            by = btn.y * avgScale
        elseif startY then
            by = startY + (i - 1) * (scaledButtonHeight + scaledMargin)
        else
            by =
                love.graphics.getHeight() * 0.5
                - (#table * (scaledButtonHeight + scaledMargin) * 0.5)
                + (i - 1) * (scaledButtonHeight + scaledMargin)
        end

        btn.x1 = bx
        btn.y1 = by


        local scaledW = scaledButtonWidth * btn.scale
        local scaledH = scaledButtonHeight * btn.scale

        local mouseHot =
            mx > bx + (scaledButtonWidth - scaledW) / 2 and
            mx < bx + (scaledButtonWidth + scaledW) / 2 and
            my > by + (scaledButtonHeight - scaledH) / 2 and
            my < by + (scaledButtonHeight + scaledH) / 2

        local hot = false

        if inputMode == "mouse" then
            hot = mouseHot
        elseif inputMode == "controller" then
            hot = btn.hot
        end            
        btn.newHot = hot

        local color =
            hot and (btn.color2 or {0.2, 0.1, 0.7}) or
            (btn.color1 or {0.25, 0.15, 0.75})

        if hot and not btn.now then
            btn.targetScale = 1.1
        elseif not hot and not btn.now then
            btn.targetScale = 1
        end

        if hot and not btn.lastHot and sfx_play then
            sounds.hover.play()
        end

        btn.now = love.mouse.isDown(1)

        if btn.last and not btn.now and hot then
            btn.fn()
            if sfx_play then sounds.click.play() end
        end

        if btn.now and hot then
            btn.targetScale = 0.95
        end

        if inputMode == "controller" and btn.hot and btn.newHot and not btn.lastHot then
            btn.targetScale = 0.95
        end

        btn.cx = bx + scaledButtonWidth * 0.5
        btn.cy = by + scaledButtonHeight * 0.5

        if btn.hot and inputMode == "controller" then
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.setLineWidth(3)
        
            love.graphics.rectangle(
                "line",
                bx + (scaledButtonWidth - scaledW) / 2 - 6,
                by + (scaledButtonHeight - scaledH) / 2 - 6,
                scaledW + 12,
                scaledH + 12,
                14, 14
            )
        end
        
        love.graphics.setColor(unpack(color))
        love.graphics.rectangle(
            "fill",
            bx + (scaledButtonWidth - scaledW) / 2,
            by + (scaledButtonHeight - scaledH) / 2,
            scaledW,
            scaledH,
            10, 10, 5
        )

        love.graphics.setColor(1, 1, 1)

        local txt = btn.customText or btn.text
        love.graphics.setFont(font)

        local tw = font:getWidth(txt)
        local th = font:getHeight(txt)

        love.graphics.print(
            txt,
            bx + (scaledButtonWidth - tw) / 2,
            by + (scaledButtonHeight - th) / 2
        )

        btn.lastHot = btn.newHot
        btn.last = btn.now
    end
end

return Button