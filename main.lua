local love = require("love")
print("[DEBUG] : Loading Modules")
local Enemy = require("Enemy")
local Button = require("Button")
local Save = require("save")
local Slider = require("Slider")
local Distraction = require("Distraction")

-- for anybody reading this code, this may be the messiest code ive ever Made
-- and for the record, yes i did use a LITTLE bit of AI maybe like 10% for some hard bits 
-- but most if it was me which is probably why it looks so bad, variable names are NEVER consistent
-- one point its ABC_DEF and the other is abcDEF and the other ABC_DEF

local VERSION_NUMBER = "0.7.1"

math.randomseed(os.time())

local BASE_WIDTH, BASE_HEIGHT = 1280, 720

local game = {
    difficulty = 1,
    state = {
        menu = true,
        paused = false,
        running = false,
        ended = false
    },
    points = 0,
    highscores = {0, 0, 0, 0, 0}
}
local difficultyNames = {"EASY", "MEDIUM", "HARD", "IMPOSSIBLE", "DEMON"}

local difficultyColors = {{0, .9, 0, 1}, {.8, .9, 0, 1}, {.9, 0, 0, 1}, {0.6, 0, 0.6, 1}, {0.15, 0.15, 0.15}}

local difficultyConfig = {
    EASY = {
        spawnRate = 8,
        pointRate = 1,
        enemySpeed = 100,
        coinMultiplier = 1,
    },
    MEDIUM = {
        spawnRate = 6,
        pointRate = 1.25,
        enemySpeed = 150,
        coinMultiplier = 1.2,
    },
    HARD = {
        spawnRate = 4,
        pointRate = 1.5,
        enemySpeed = 200,
        coinMultiplier = 1.6,
    },
    IMPOSSIBLE = {
        spawnRate = 3,
        pointRate = 2,
        enemySpeed = 250,
        coinMultiplier = 2.5,
    },
    DEMON = {
        spawnRate = 2,
        pointRate = 2.2,
        enemySpeed = 300,
        coinMultiplier = 3,
    }
}

local message

-- input

KEYBINDS = {
    MoveUp = {
        Keyboard = "w",
        Keyboard2 = "up"
    },
    MoveDown = {
        Keyboard = "s",
        Keyboard2 = "down"
    },
    MoveLeft = {
        Keyboard = "a",
        Keyboard2 = "left"
    },
    MoveRight = {
        Keyboard = "d",
        Keyboard2 = "right"
    },
    Back = {
        Controller = "b",
        Keyboard = "escape"
    },
    Fullscreen = {
        Keyboard = "f11"
    },
    Distraction = {
        Controller = "dpup",
        Keyboard = "g"
    },
    Menu = {
        Controller = "menu",
        Keyboard = "escape"
    }
}

local DEFAULT_FONT_FILE = "fonts/default_regular.ttf"
local DEFAULT_BOLD_FONT_FILE = "fonts/default_bold.ttf"
local BIT_FONT_FILE = "fonts/8bit_regular.ttf"
local BIT_BOLD_FONT_FILE = "fonts/8bit_bold.ttf"

local fonts = {}
local fontCache = {}

local function getFont(size, bold)
    size = math.floor(size)
    bold = bold or false

    if bitfont then
        size = math.floor(size * 1.12)
    else
        size = math.floor(size * 0.9)
    end

    local key = size .. "_" .. tostring(bold) .. "_" .. tostring(bitfont)
    if fontCache[key] then
        return fontCache[key]
    end

    local fontFile
    if bitfont then
        fontFile = bold and BIT_BOLD_FONT_FILE or BIT_FONT_FILE
    else
        fontFile = bold and DEFAULT_BOLD_FONT_FILE or DEFAULT_FONT_FILE
    end

    if fontFile then
        fontCache[key] = love.graphics.newFont(fontFile, size)
    else
        fontCache[key] = love.graphics.newFont(size)
    end
    return fontCache[key]
end

local player = {
    radius = 20,
    colliderFactor = 1.07,
    padding = 1.15,
    x = 30,
    y = 30,
    baseSpeed = 150,
    speed = 150,
    velx = 0,
    vely = 0,
    rotation = 0
}

function player:getColliderRadius(scale)
    if not scale then
        local _, _scale = getScale()
        scale = _scale
    end
    return self.radius * self.colliderFactor
end


local enemies = {}
local distractions = {}
local buttons = {
    main_menu = {},
    settings = {},
    ended = {},
    difficulty = {},
    highscores = {},
    credits = {},
    update_log = {},
    paused = {},
    shop = {},
    resolution = {}
}
local GUI_SCREEN = "main_menu"
fps_counter = true
fullscreen = true
vsync = true
bitfont = true
musicVolume = 0.25
sfxVolume = 0.3
coins = 0
local nextLevelIndex = 0
local new_highscore = false

shop = {
    distractions = 0
}

-- save status display
local saveStatus = {
    message = "",
    timer = 0
}

-- helper to save settings
local function saveSettings()
    local dataToSave = {
        coins = math.floor(coins),
        shop = shop,
        difficulty = game.difficulty,
        sfx = Button:getSfx(),
        music = Button:getMusic(),
        volume = musicVolume,
        sfx_volume = sfxVolume,
        fpsCounter = fps_counter,
        fullscreen = fullscreen,
        vsync = vsync,
        bitfont = bitfont,
        highscore_easy = game.highscores[1],
        highscore_medium = game.highscores[2],
        highscore_hard = game.highscores[3],
        highscore_impossible = game.highscores[4],
        highscore_demon = game.highscores[5],
    }
    local success = Save:save(dataToSave)
    saveStatus.message = success and "Data Saved" or "Save Failed"
    saveStatus.timer = 2
end

-- load saved data
local data = Save:load() or {}
-- only override defaults when saved values are present (not nil)
game.highscores = {(data.highscore_easy ~= nil) and data.highscore_easy or game.highscores[1],
                   (data.highscore_medium ~= nil) and data.highscore_medium or game.highscores[2],
                   (data.highscore_hard ~= nil) and data.highscore_hard or game.highscores[3],
                   (data.highscore_impossible ~= nil) and data.highscore_impossible or game.highscores[4],
                   (data.highscore_demon ~= nil) and data.highscore_demon or game.highscores[5]}
if type(data.difficulty) == "number" then
    game.difficulty = data.difficulty
end
if data.sfx ~= nil then
    Button:setSfx(data.sfx)
end
if data.music ~= nil then
    Button:setMusic(data.music)
end
if type(data.fullscreen) == "boolean" then
    fullscreen = data.fullscreen
end
if type(data.vsync) == "boolean" then
    vsync = data.vsync
end
if type(data.fpsCounter) == "boolean" then
    fps_counter = data.fpsCounter
end
if type(data.bitfont) == "boolean" then
    bitfont = data.bitfont
end
if type(data.volume) == "number" then
    musicVolume = data.volume
end
if type(data.sfx_volume) == "number" then
    sfxVolume = data.sfx_volume
end
if type(data.coins) == "number" then
    coins = math.floor(data.coins)
end
if data.shop then
    shop = data.shop
end

function getScale()
    local w, h = love.graphics.getDimensions()
    return w / BASE_WIDTH, h / BASE_HEIGHT
end

local function getPlayerRadius()
    local _, scaleY = getScale()
    return player:getColliderRadius() * scaleY
end

local function changeGameState(state)
    game.state.menu = state == "menu"
    game.state.paused = state == "paused"
    game.state.running = state == "running"
    game.state.ended = state == "ended"
end

local function switchScreen(screen)
    message = ""
    changeGameState(screen)
    for _, tbl in pairs(buttons) do
        for _, btn in pairs(tbl) do
            btn.scale, btn.targetScale = 1, 1
            btn.now, btn.last, btn.nowHot, btn.lastHot = false, false, false, false
        end
    end
end

-- switch menu
function SwitchMenuScreen(screen)
    GUI_SCREEN = screen
    uiIndex = 1
    for _, tbl in pairs(buttons) do
        for _, btn in pairs(tbl) do
            btn.scale, btn.targetScale = 1, 1
            btn.now, btn.last, btn.nowHot, btn.lastHot = false, false, false, false
        end
    end
end

local function removeDistraction(target)
    for i = #distractions, 1, -1 do
        if distractions[i] == target then
            table.remove(distractions, i)
            return
        end
    end
end

local errors = {}
local DISPLAY_TIME = 2.5
local FADE_TIME = 0.4
local FADE_IN_TIME = 0.3

local errorSound = love.audio.newSource("sounds/sfx/error.mp3", "static")

local function createNewError(msg)
    errorSound:setVolume(sfxVolume)
    table.insert(errors, {
        msg = msg,
        alpha = 0,
        timer = 0
    })
    errorSound:stop()
    errorSound:play()
end

local function updateErrors(dt)
    for i = #errors, 1, -1 do
        local e = errors[i]
        e.timer = e.timer + dt

        if e.timer < FADE_IN_TIME then
            e.alpha = e.timer / FADE_IN_TIME
        elseif e.timer > DISPLAY_TIME then
            e.alpha = math.max(0, 1 - (e.timer - DISPLAY_TIME) / FADE_TIME)
            if e.alpha <= 0 then
                table.remove(errors, i)
            end
        else
            e.alpha = 1
        end
    end
end

local function drawErrors()
    local scaleX, scaleY = getScale()
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    
    local notifFont = getFont(math.max(14 * scaleY, 10))
    love.graphics.setFont(notifFont)
    
    for idx, e in ipairs(errors) do
        local yOffset = (25 * scaleY) * (idx - 1)
        local x = w - (190 * scaleX)
        local y = h - (16 * scaleY) - (35 * scaleY) - yOffset
        local boxWidth = 190 * scaleX
        local boxHeight = 22 * scaleY
        
        love.graphics.setColor(0.15, 0.05, 0.05, e.alpha * 0.8)
        love.graphics.rectangle("fill", x - (5 * scaleX), y - (2 * scaleY), boxWidth, boxHeight, 5, 5)
        
        love.graphics.setColor(0.6, 0.15, 0.15, e.alpha * 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x - (5 * scaleX), y - (2 * scaleY), boxWidth, boxHeight, 5, 5)
        
        love.graphics.setColor(0.9, 0.2, 0.2, e.alpha)
        love.graphics.print(e.msg, x, y)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

PREVIOUS_WIDTH, PREVIOUS_HEIGHT = nil, nil

local function startNewGame()
    inputModeLocked = true
    local w, h = love.graphics.getDimensions()
    PREVIOUS_WIDTH, PREVIOUS_HEIGHT = w, h
    player.x = w / 2
    player.y = h / 2
    switchScreen("running")
    game.points = 0
    local cfg = difficultyConfig[difficultyNames[game.difficulty]]
    local scaleX, scaleY = getScale()
    enemies = {Enemy(game.difficulty, distractions, scaleY, enemies)}
    nextLevelIndex = 0
    new_highscore = false
end

local function findButtonByText(tbl, text)
    for _, btn in pairs(tbl) do
        if btn.text == text then
            return btn
        end
    end
end

local function playerDied()
    inputModeLocked = false
    switchScreen("menu")
    SwitchMenuScreen("ended")
    local diff = game.difficulty
    game.points = math.floor(game.points)
    if game.points > (game.highscores[diff] or 0) then
        game.highscores[diff] = game.points
        new_highscore = true
        saveSettings()
    end
    distractions = {}
    distractionCountdown = 0    -- calc coins given
    local diffName = difficultyNames[game.difficulty]
    local Multiplier = difficultyConfig[diffName].coinMultiplier
    local CoinsGiven = math.floor(game.points * Multiplier)
    print("ORIGINAL COINS GIVEN: "..tostring(game.points))
    print("TOTAL COINS GIVEN (x"..tostring(Multiplier).."): "..tostring(CoinsGiven))
    coins = coins + CoinsGiven
    local _,scaleY = getScale()
    spawnCoinAnimation(BASE_WIDTH*0.9, BASE_HEIGHT*0.9, 1, CoinsGiven, false)
end

function playerMenu()
    switchScreen("menu")
    SwitchMenuScreen("main_menu")
    distractions = {}
    distractionCountdown = 0
end

images = {}

images.saving = love.graphics.newImage("images/saving.png")
images.coin = love.graphics.newImage("images/coin.png")
images.distraction = love.graphics.newImage("images/distraction.png")
images.shopborder = love.graphics.newImage("images/shopborder.png")

local sounds = {
    coin = {
        play = function()
            local source = love.audio.newSource("sounds/sfx/coin.mp3", "static")
            source:setVolume(sfxVolume)
            source:play()
        end
    },
    purchase = {
        play = function()
            local source = love.audio.newSource("sounds/sfx/purchase.mp3", "static")
            source:setVolume(sfxVolume)
            source:play()
        end
    }
}

-- music
local musics = {
    game = {
        easy = {love.audio.newSource("sounds/music/easy1.mp3", "stream")},
        medium = {love.audio.newSource("sounds/music/easy1.mp3", "stream")},
        hard = {love.audio.newSource("sounds/music/hard1.mp3", "stream")},
        impossible = {love.audio.newSource("sounds/music/impossible1.mp3", "stream")},
        demon = {love.audio.newSource("sounds/music/demon1.mp3", "stream")},
        --love.audio.newSource("sounds/music/game_music.mp3", "stream"),
        --love.audio.newSource("sounds/music/game_music_2.mp3", "stream"),
        --love.audio.newSource("sounds/music/game_music_3.mp3", "stream"),
    },
    menu = {
        love.audio.newSource("sounds/music/menu_music.mp3", "stream"),
        love.audio.newSource("sounds/music/menu_music_2.mp3", "stream"),
        love.audio.newSource("sounds/music/menu_music_3.mp3", "stream"),
    }
}

for _, list in pairs(musics) do
    for _, src in ipairs(list) do
        src:setLooping(true)
        src:setVolume(0)
    end
end
local currentMusic = nil
local targetMusic = nil
local currentType = nil

local MUSIC_VOLUME = 0.7
local targetVolume = MUSIC_VOLUME
local FADE_SPEED = 0.8
local transitioning = false

local function updateMusic(dt)
    if not Button:getMusic() then
        if currentMusic then
            musicVolume = math.max(0, musicVolume - FADE_SPEED * dt)
            currentMusic:setVolume(musicVolume)
            if musicVolume == 0 then
                currentMusic:stop()
                currentMusic = nil
                currentType = nil
            end
        end
        return
    end

    local wantedType
    local wantedList

    if game.state.running then
        local diffName = string.lower(difficultyNames[game.difficulty])
        wantedType = "game_" .. tostring(diffName)
        wantedList = musics.game[diffName]
    else
        wantedType = "menu"
        wantedList = musics.menu
    end
    if not wantedList or #wantedList == 0 then
        return
    end

    if currentType ~= wantedType then
        currentType = wantedType
        targetMusic = wantedList[math.random(#wantedList)]
    end

    if currentMusic and currentMusic ~= targetMusic then
        musicVolume = math.max(0, musicVolume - FADE_SPEED * dt)
        currentMusic:setVolume(musicVolume)
        if musicVolume == 0 then
            currentMusic:stop()
            currentMusic = nil
        end
        return
    end

    if not currentMusic and targetMusic then
        currentMusic = targetMusic
        currentMusic:setVolume(0)
        currentMusic:play()
        musicVolume = 0
    end

    if currentMusic then
        local tv = tonumber(musicVolumeSlider.value) / 100
        if musicVolume < tv then
            musicVolume = math.min(tv, musicVolume + FADE_SPEED * dt)
        else
            musicVolume = math.max(tv, musicVolume - FADE_SPEED * dt)
        end
        currentMusic:setVolume(musicVolume)
    end
end

function setMusicVolume(vol)
    musicVolume = vol
    musics.menu:setVolume(vol)
    musics.game:setVolume(vol)
end


local distractionTime = 15
distractionCountdown = 0

local function updateColor(btn, var)
    if _G[var] then
        btn.color1, btn.color2 = {0, 0.9, 0, 1}, {0.4, 1, 0.4, 1}
    else
        btn.color1, btn.color2 = {0.9, 0, 0, 1}, {1, 0.4, 0.4, 1}
    end
end

coinImages = {}

function spawnCoinAnimation(x, y, duration, amount, minus)
    local coin = {
        x = x,
        y = y,
        timer = duration or 1,
        alpha = 1,
        yOffset = 0,
        amount = amount or 1,
        minus = minus,
    }
    if minus then sounds.purchase:play() else sounds.coin:play() end
    table.insert(coinImages, coin)
end

function updateCoinAnimations(dt)
    for i = #coinImages, 1, -1 do
        local coin = coinImages[i]
        coin.timer = coin.timer - dt

        coin.yOffset = coin.yOffset - 50 * dt  

        coin.alpha = math.max(0, coin.timer)

        if coin.timer <= 0 then
            table.remove(coinImages, i)
        end
    end
end

function drawCoinAnimations()
    for _, coin in ipairs(coinImages) do
        local scaleX, scaleY = getScale()
        love.graphics.setColor(1, 1, 1, coin.alpha)

        local coinScale = 0.1
        local coinWidth = images.coin:getWidth() * coinScale
        local coinHeight = images.coin:getHeight() * coinScale

        love.graphics.draw(
            images.coin,
            coin.x * scaleX,
            (coin.y + coin.yOffset) * scaleY,
            0,
            coinScale * scaleY,
            coinScale * scaleY
        )

        local font = getFont(25*scaleY)
        love.graphics.setFont(font)
        love.graphics.setColor(0,1,0, coin.alpha)
        local sub = "-"
        if not coin.minus then sub = "+" end
        local text = sub.."$"..tostring(coin.amount)

        local textX = (coin.x + coinWidth + 5) * scaleX

        local textY = (coin.y + coin.yOffset) * scaleY + (coinHeight * scaleY) / 2 - font:getHeight(text) / 2

        love.graphics.print(text, textX, textY)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local UPDATE_LOG_SCREEN = "0.7"


DISTRACTION_COINS = 1000
MAX_DISTRACTIONS = 3

function BuyDistraction()
    if (coins >= DISTRACTION_COINS) and (shop.distractions < MAX_DISTRACTIONS) then
        coins = coins - DISTRACTION_COINS
        shop.distractions = shop.distractions + 1
        print("BOUGHT")
        spawnCoinAnimation(BASE_WIDTH*0.9, BASE_HEIGHT*0.9, 1, DISTRACTION_COINS, true)
    elseif not (coins >= DISTRACTION_COINS) then
        print("NOT ENOUGH MONEY")
        createNewError("not enough money")
    elseif not (shop.distractions < MAX_DISTRACTIONS) then
        print("MAX DISTRACTIONS AMOUNT")
        createNewError("max distractions")
    end
end

function normalize(vx, vy, maxSpeed)
    local length = math.sqrt(vx * vx + vy * vy)
    if length == 0 then
        return 0, 0
    end
    local factor = math.min(length, maxSpeed) / length
    return vx * factor, vy * factor
end

function checkWallCollision(x, y, r)
    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()

    if x - r < 0 then
        x = r
    elseif x + r > w then
        x = w - r
    end

    if y - r < 0 then
        y = r
    elseif y + r > h then
        y = h - r
    end

    return x, y
end

local enemyLogicTimer = 0

local previousBadResolution = false
local badResolution = false

local function deadzone(v)
    return math.abs(v) < 0.1 and 0 or v
end

local function updateControllerUI(dt, list)
    local js = love.joystick.getJoysticks()[1]
    if not js or not list or #list == 0 then return end

    local ax = js:getGamepadAxis("leftx")
    local ay = js:getGamepadAxis("lefty")
    
    if math.abs(ax) > 0.1 or math.abs(ay) > 0.1 then
        inputMode = "controller"
    end

    local numButtons = #buttons[GUI_SCREEN]
    local isOnSlider = GUI_SCREEN == "settings" and uiIndex > numButtons
    
    local dx, dy = 0, 0

    if js:isGamepadDown("dpleft")  then dx = -1 end
    if js:isGamepadDown("dpright") then dx =  1 end
    if js:isGamepadDown("dpup")    then dy = -1 end
    if js:isGamepadDown("dpdown")  then dy =  1 end

    if math.abs(ax) > 0.5 then dx = ax > 0 and 1 or -1 end
    if math.abs(ay) > 0.5 then dy = ay > 0 and 1 or -1 end

    if isOnSlider then
        if dy ~= 0 then
            if not stickHeld then
                navigateUI(list, 0, dy)
                stickHeld = true
                repeatTimer = uiInitialDelay
            else
                repeatTimer = repeatTimer - dt
                if repeatTimer <= 0 then
                    navigateUI(list, 0, dy)
                    repeatTimer = uiRepeatDelay
                end
            end
        else
            stickHeld = false
        end
    else
        if dx ~= 0 or dy ~= 0 then
            if not stickHeld then
                navigateUI(list, dx, dy)
                stickHeld = true
                repeatTimer = uiInitialDelay
            else
                repeatTimer = repeatTimer - dt
                if repeatTimer <= 0 then
                    navigateUI(list, dx, dy)
                    repeatTimer = uiRepeatDelay
                end
            end
        else
            stickHeld = false
        end
    end
end

local function findNextButton(list, current, dx, dy)
    local function centerOf(btn)
        if btn.cx and btn.cy then return btn.cx, btn.cy end
        local w, h = love.graphics.getDimensions()
        local cx = btn.cx or (btn.rx and btn.rx * w) or (btn.x and btn.x) or (w * 0.5)
        local cy = btn.cy or (btn.ry and btn.ry * h) or (btn.y and btn.y) or (h * 0.5)
        return cx, cy
    end

    local cx, cy = centerOf(current)
    local best, bestScore

    for i, btn in ipairs(list) do
        if btn ~= current and btn.group == current.group then
            local bx, by = centerOf(btn)
            local vx = bx - cx
            local vy = by - cy

            if (dx ~= 0 and vx * dx > 0) or (dy ~= 0 and vy * dy > 0) then
                local dist = math.sqrt(vx * vx + vy * vy)
                local dirPenalty = math.abs(vx * dy - vy * dx) * 0.1
                local score = dist + dirPenalty

                if not best or score < bestScore then
                    best = i
                    bestScore = score
                end
            end
        end
    end

    return best
end

function navigateUI(list, dx, dy)
    local cur = list[uiIndex]
    
    if GUI_SCREEN == "settings" then
        local numButtons = #buttons.settings
        local isOnMusicSlider = uiIndex == (numButtons + 1)
        local isOnSfxSlider = uiIndex == (numButtons + 2)
        
        if isOnMusicSlider then
            if dy > 0 then
                uiIndex = numButtons + 2
            elseif dy < 0 then
                uiIndex = numButtons
            end
            return
        elseif isOnSfxSlider then
            if dy > 0 then
                uiIndex = 1
            elseif dy < 0 then
                uiIndex = numButtons + 1
            end
            return
        elseif cur and cur.text == "back" then
            if dy > 0 then
                uiIndex = numButtons + 1
            elseif dy < 0 then
                uiIndex = numButtons - 1
            end
            return
        end
    elseif GUI_SCREEN == "update_log" then
        if cur and cur.group == "update_log" then
            if dy > 0 then
                local backBtn = findButtonByText(buttons.update_log, "back")
                if backBtn then
                    for i, btn in ipairs(buttons.update_log) do
                        if btn == backBtn then
                            uiIndex = i
                            return
                        end
                    end
                end
            end
        elseif cur and cur.text == "back" then
            if dy < 0 then
                uiIndex = 1
            end
            return
        end
    end
    
    if not cur then
        uiIndex = 1
        return
    end

    if cur.nav == "vertical" then
        dy = dy ~= 0 and dy or 0
        dx = 0
    elseif cur.nav == "horizontal" then
        dx = dx ~= 0 and dx or 0
        dy = 0
    end

    local nextIndex = findNextButton(list, cur, dx, dy)
    if nextIndex then
        uiIndex = nextIndex
    else
        if dy > 0 then
            uiIndex = math.min(uiIndex + 1, #list)
        elseif dy < 0 then
            uiIndex = math.max(uiIndex - 1, 1)
        elseif dx > 0 then
            uiIndex = math.min(uiIndex + 1, #list)
        elseif dx < 0 then
            uiIndex = math.max(uiIndex - 1, 1)
        end
    end
end

-- vvvvvvvvvvvvvvvvvvvvvv ---
--- LOAD FUNCTION BELOW ---
-- vvvvvvvvvvvvvvvvvvvvvv ---

function love.load()
    print("[DEBUG] : Loaded")
    love.window.setTitle("Save The Ball!")
    love.window.setMode(BASE_WIDTH, BASE_HEIGHT, {
        fullscreen = fullscreen,
        vsync = vsync,
    })

    fonts.medium = getFont(16)
    fonts.large = getFont(24)
    fonts.massive = getFont(60)

    images.player = love.graphics.newImage("images/player.png")
    images.enemy = love.graphics.newImage("images/enemy.png")

    Button:create("main_menu", "play", function()
        SwitchMenuScreen("difficulty")
    end, nil, nil, buttons)
    Button:create("main_menu", "shop", function()
        SwitchMenuScreen("shop")
    end, nil, nil, buttons)
    Button:create("main_menu", "settings", function()
        SwitchMenuScreen("settings")
    end, nil, nil, buttons)
    Button:create("main_menu", "highscores", function()
        SwitchMenuScreen("highscores")
    end, nil, nil, buttons)
    Button:create("main_menu", "update log", function()
        SwitchMenuScreen("update_log")
    end, nil, nil, buttons)
    Button:create("main_menu", "credits", function()
        SwitchMenuScreen("credits")
    end, nil, nil, buttons)
    Button:create("main_menu", "quit", function()
        love.event.quit()
    end, nil, nil, buttons)
    Button:create("highscores", "back", function()
        SwitchMenuScreen("main_menu")
    end, nil, nil, buttons, nil, 0.9)

    for i, name in ipairs(difficultyNames) do
        Button:create("difficulty", name, function()
            game.difficulty = i
            saveSettings()
            startNewGame()
        end, difficultyColors[i], difficultyColors[i], buttons)
    end
    Button:create("difficulty", "back", function()
        SwitchMenuScreen("main_menu")
    end, nil, nil, buttons)

    -- settings toggles
    local function createToggleButton(name, var)
        Button:create("settings", name, function()
            _G[var] = not _G[var]
            local btn = findButtonByText(buttons.settings, name)
            updateColor(btn, var)
            if name == "fullscreen" then
                love.window.setFullscreen(_G[var])
            end
            if name == "vsync" then
                love.window.setVSync(_G[var])
            end
            saveSettings()
        end, nil, nil, buttons)
        local btn = findButtonByText(buttons.settings, name)
        updateColor(btn, var)
    end
    createToggleButton("fps counter", "fps_counter")
    createToggleButton("fullscreen", "fullscreen")
    createToggleButton("vsync", "vsync")

    Button:create("settings", "sfx", function()
        Button:setSfx(not Button:getSfx())
        local btn = findButtonByText(buttons.settings, "sfx")
        if Button:getSfx() then
            btn.color1, btn.color2 = {0, 0.9, 0, 1}, {0.4, 1, 0.4, 1}
            sfxVolumeSlider.value = 0.5 * 100
        else
            btn.color1, btn.color2 = {0.9, 0, 0, 1}, {1, 0.4, 0.4, 1}
            sfxVolumeSlider.value = 0
        end
        saveSettings()
    end, Button:getSfx() and {0, 0.9, 0, 1} or {0.9, 0, 0, 1}, Button:getSfx() and {0.4, 1, 0.4, 1} or {1, 0.4, 0.4, 1},
        buttons)

    Button:create("settings", "music", function()
        local btn = findButtonByText(buttons.settings, "music")
        
        if Button:getMusic() then
            -- turn off
            Button:setMusic(false)
            musicVolumeSlider.value = 0
            btn.color1, btn.color2 = {0.9, 0, 0, 1}, {1, 0.4, 0.4, 1}
        else
            -- turn on
            Button:setMusic(true)
            musicVolumeSlider.value = 0.5 * 100
            btn.color1, btn.color2 = {0, 0.9, 0, 1}, {0.4, 1, 0.4, 1}
        end
    
        saveSettings()
    end, Button:getMusic() and {0, 0.9, 0, 1} or {0.9, 0, 0, 1}, 
        Button:getMusic() and {0.4, 1, 0.4, 1} or {1, 0.4, 0.4, 1}, 
        buttons)
    

    Button:create("settings", "8-bit font", function()
        bitfont = not bitfont
        local btn = findButtonByText(buttons.settings, "8-bit font")
        if bitfont then
            btn.color1, btn.color2 = {0, 0.9, 0, 1}, {0.4, 1, 0.4, 1}
        else
            btn.color1, btn.color2 = {0.9, 0, 0, 1}, {1, 0.4, 0.4, 1}
        end
        saveSettings()
    end, bitfont and {0, 0.9, 0, 1} or {0.9, 0, 0, 1}, bitfont and {0.4, 1, 0.4, 1} or {1, 0.4, 0.4, 1},
        buttons)

    Button:create("settings", "back", function()
        SwitchMenuScreen("main_menu")
    end, nil, nil, buttons)

    Button:create("ended", "replay", function()
        startNewGame()
    end, nil, nil, buttons)
    Button:create("ended", "menu", function()
        switchScreen("menu")
        SwitchMenuScreen("main_menu")
    end, nil, nil, buttons)
    Button:create("ended", "quit", function()
        love.event.quit()
    end, nil, nil, buttons)
    Button:create("credits", "back", function()
        SwitchMenuScreen("main_menu")
    end, nil, nil, buttons, nil, 0.9)

    Button:create("update_log", "v0.1-v0.3.1", function()
        UPDATE_LOG_SCREEN = "0.1"
    end, nil, nil, buttons, 0.04, 0.25, nil, nil, nil,
        {nav = "horizontal", group = "update_log"})

    Button:create("update_log", "v0.4-v0.6.1", function()
        UPDATE_LOG_SCREEN = "0.4"
    end, nil, nil, buttons, 0.28, 0.25, nil, nil, nil,
    {nav = "horizontal", group = "update_log"})

    Button:create("update_log", "v0.7-v0.7.1", function()
        UPDATE_LOG_SCREEN = "0.7"
    end, nil, nil, buttons, 0.52, 0.25, nil, nil, nil,
    {nav = "horizontal", group = "update_log"})

    --[[Button:create("update_log", "v0.10-v0.12", function()
        UPDATE_LOG_SCREEN = "0.10"
    end, nil, nil, buttons, 0.76, 0.25, nil, nil, nil,
    {nav = "horizontal", group = "update_log"})
    ]]

    Button:create("update_log", "back", function()
        SwitchMenuScreen("main_menu")
    end, nil, nil, buttons, nil, 0.9)

    Button:create("paused", "resume", function()
        GUI_SCREEN = "difficulty"
    end, nil, nil, buttons)
    Button:create("paused", "menu", function()
        playerMenu()
    end, nil, nil, buttons)
    Button:create("paused", "quit", function()
        love.event.quit()
    end, nil, nil, buttons)

    Button:create("resolution", "continue", function()
        SwitchMenuScreen("main_menu")
    end, nil, nil, buttons)

    Button:create("resolution", "fullscreenRes", function()
        _G.fullscreen = not _G.fullscreen
        local btn2 = findButtonByText(buttons.settings, "fullscreen")
        updateColor(btn2, "fullscreen")
        love.window.setFullscreen(_G.fullscreen)
        saveSettings()
        SwitchMenuScreen("main_menu")
    end, nil, nil, buttons, nil, nil, "disable fullscreen")
    local btn2 = findButtonByText(buttons.settings, "fullscreen")
    updateColor(btn2, "fullscreen")

    Button:create("resolution", "quit", function()
        love.event.quit()
    end, nil, nil, buttons)

    musicVolumeSlider = Slider:create(300, 0, 100, musicVolume*100, "MUSIC VOLUME", 0.5, 0.88)
    sfxVolumeSlider = Slider:create(300, 0, 100, sfxVolume*100, "SFX VOLUME", 0.5, 0.95)

    Button:create("shop", "back", function()
        SwitchMenuScreen("main_menu")
    end, nil, nil, buttons, nil, 0.9)

    local canDistraction = false

    if coins >= DISTRACTION_COINS and shop.distractions < MAX_DISTRACTIONS then canDistraction = true end

    -- shop button
    Button:create("shop", "distraction", function()
        local btn = findButtonByText(buttons.shop, "distraction")
        BuyDistraction()
        local canDistraction2 = false
        if coins >= DISTRACTION_COINS and shop.distractions < MAX_DISTRACTIONS then canDistraction2 = true end
        if canDistraction2 then
            btn.color1, btn.color2 = {0, 0.9, 0, 1}, {0.4, 1, 0.4, 1}
        else
            btn.color1, btn.color2 = {0.9, 0, 0, 1}, {1, 0.4, 0.4, 1}
        end
    end, canDistraction and {0, 0.9, 0, 1} or {0.9, 0, 0, 1}, canDistraction and {0.4, 1, 0.4, 1} or {1, 0.4, 0.4, 1},
     buttons, nil, nil, "buy", 103.5, 400)
end

-- vvvvvvvvvvvvvvvvvvvvvv ---
--- UPDATE FUNCTION BELOW ---
-- vvvvvvvvvvvvvvvvvvvvvv ---

DT = 0
inputMode = "mouse"
inputModeLocked = false
gamepadAPressed = false
uiIndex = 1
repeatTimer = 0
repeatDelay = 0.22
stickHeld = false
uiHeld = false
uiRepeatTimer = 0
uiRepeatDelay = 0.15
uiInitialDelay = 0.4

function love.update(dt)
    dt = math.min(dt, 0.1)
    DT = dt
    local scaleX, scaleY = getScale()
    updateMusic(dt)
    targetVolume = tonumber(musicVolumeSlider.value) / 100
    sfxVolume = tonumber(sfxVolumeSlider.value) / 100
    updateErrors(dt)
    updateCoinAnimations(dt)

    if inputMode ~= "mouse" then
        love.mouse.setVisible(false)
    else
        love.mouse.setVisible(true)
    end

    if distractionCountdown > 0 and GUI_SCREEN ~= "paused" and game.state.running then
        distractionCountdown = distractionCountdown - dt
    end

    local joysticks = love.joystick.getJoysticks()

    local w, h = love.graphics.getDimensions()

    local aspect = w / h
    local TARGET = 16 / 9
    local TOLERANCE = 0.02

    local goodResolution = math.abs(aspect - TARGET) < TOLERANCE
    
    badResolution = not goodResolution

    if badResolution and not previousBadResolution and not game.state.running then
        GUI_SCREEN = "resolution"
    end

    previousBadResolution = badResolution

    -- sync music slider to toggle

    if musicVolumeSlider.value <= 0 then
        if Button:getMusic() then
            Button:setMusic(false)
            local btn = findButtonByText(buttons.settings, "music")
            btn.color1, btn.color2 = {0.9, 0, 0, 1}, {1, 0.4, 0.4, 1}
        end
    else
        if not Button:getMusic() then
            Button:setMusic(true)
            local btn = findButtonByText(buttons.settings, "music")
            btn.color1, btn.color2 = {0, 0.9, 0, 1}, {0.4, 1, 0.4, 1}
        end
    end

    -- sync sfx slider to toggle
    if sfxVolumeSlider.value <= 0 then
        if Button:getSfx() then
            Button:setSfx(false)
            local btn = findButtonByText(buttons.settings, "sfx")
            btn.color1, btn.color2 = {0.9, 0, 0, 1}, {1, 0.4, 0.4, 1}
        end
    else
        if not Button:getSfx() then
            Button:setSfx(true)
            local btn = findButtonByText(buttons.settings, "sfx")
            btn.color1, btn.color2 = {0, 0.9, 0, 1}, {0.4, 1, 0.4, 1}
        end
    end

    if game.state.running and GUI_SCREEN ~= "paused" then

        if #joysticks > 0 then
            local xaxis = deadzone(joysticks[1]:getAxis(1))
            local yaxis = deadzone(joysticks[1]:getAxis(2))
            if xaxis and yaxis then
                if math.abs(xaxis) > 0.1 or math.abs(yaxis) > 0.1 then
                    inputMode = "controller" 
                end
            end
            player.velx = player.speed * xaxis
            player.vely = player.speed * yaxis
        end

        if love.keyboard.isDown(KEYBINDS.MoveLeft.Keyboard) or love.keyboard.isDown(KEYBINDS.MoveLeft.Keyboard2) then
            player.velx = -player.speed
        end
        if love.keyboard.isDown(KEYBINDS.MoveRight.Keyboard) or love.keyboard.isDown(KEYBINDS.MoveRight.Keyboard2) then
            player.velx = player.speed
        end
        if love.keyboard.isDown(KEYBINDS.MoveUp.Keyboard) or love.keyboard.isDown(KEYBINDS.MoveUp.Keyboard2) then
            player.vely = -player.speed
        end
        if love.keyboard.isDown(KEYBINDS.MoveDown.Keyboard) or love.keyboard.isDown(KEYBINDS.MoveDown.Keyboard2) then
            player.vely = player.speed
        end

        local vx, vy = normalize(player.velx, player.vely, player.speed)

        scaleX, scaleY = getScale() -- rename this to local if theres scaling errors

        player.x = player.x + vx * dt * scaleX
        player.y = player.y + vy * dt * scaleY

        player.x, player.y = checkWallCollision(
            player.x,
            player.y,
            getPlayerRadius()
        )


        if player.velx ~= 0 or player.vely ~= 0 then
            local distance = math.sqrt((player.velx * dt) ^ 2 + (player.vely * dt) ^ 2)

            local spinDir = 1
            if player.velx < 0 then
                spinDir = -1
            end

            local speedFactor = 0.5

            player.rotation = player.rotation + spinDir * distance / player.radius * speedFactor
        end

        local decay = 8

        player.velx = player.velx * math.exp(-decay * dt)
        player.vely = player.vely * math.exp(-decay * dt)

        local cfg = difficultyConfig[difficultyNames[game.difficulty]]

        local ENEMY_TICK = 1 / 60

        enemyLogicTimer = enemyLogicTimer + dt

        local w, h = love.graphics.getDimensions()

        if w ~= PREVIOUS_WIDTH or h ~= PREVIOUS_HEIGHT then
            createNewError("change in resolution")
            playerDied()
            message = "maybe don't change your resolution mid-game to break it?"
        end

        while enemyLogicTimer >= ENEMY_TICK do
            for _, e in ipairs(enemies) do
                if e:checkTouched(player.x, player.y, player:getColliderRadius(), scaleY) then
                    playerDied()
                else
                    local diffName = difficultyNames[game.difficulty]
                    local difficulty = difficultyConfig[diffName]
                    e:move(player.x, player.y, ENEMY_TICK, difficulty.enemySpeed)
                end
            end
            enemyLogicTimer = enemyLogicTimer - ENEMY_TICK
        end

        for i, d in ipairs(distractions) do
            if d then
                d:move(dt, distractions, player, enemies, scaleY)

                if d.dead then
                    table.remove(distractions, distractions[d])
                    distractionCountdown = 0
                end
            end
        end

        local scaleX, scaleY = getScale()

        local increment = dt * cfg.pointRate
        local speedMult = 1 + (#enemies * 0.05)
        player.speed = (player.baseSpeed * (speedMult * 1.2)) * 2
        game.points = game.points + increment * speedMult
        nextLevelIndex = nextLevelIndex + dt

        if nextLevelIndex >= cfg.spawnRate then
            table.insert(enemies, Enemy(#enemies + 1, distractions, scaleY, enemies))
            nextLevelIndex = 0
        end
    end  

    local list = buttons[GUI_SCREEN]

    if not (game.state.running and GUI_SCREEN ~= "paused") then
        updateControllerUI(dt, list)
    end

    for i, btn in ipairs(list) do
        btn.hot = (inputMode == "controller" and i == uiIndex)
        if btn.hot and gamepadAPressed then
            btn.targetScale = 0.95
        end
    end

    Button:update(dt, buttons[GUI_SCREEN], sfxVolume)
    if saveStatus.timer > 0 then
        saveStatus.timer = saveStatus.timer - dt
    end

    if GUI_SCREEN == "settings" then
        local numButtons = #buttons.settings
        local settingMusicSliderActive = inputMode == "controller" and uiIndex == (numButtons + 1)
        local settingSfxSliderActive = inputMode == "controller" and uiIndex == (numButtons + 2)
        
        musicVolumeSlider:update(dt, scaleX, scaleY, settingMusicSliderActive)
        sfxVolumeSlider:update(dt, scaleX, scaleY, settingSfxSliderActive)
        
        musicVolumeSlider.controllerActive = settingMusicSliderActive
        sfxVolumeSlider.controllerActive = settingSfxSliderActive
    end
end

local TITLE_Y_DISTANCE = 80

local function drawMenuTitle(text)
    local scaleX, scaleY = getScale()
    local titleFont = getFont(math.max(80 * scaleY, 40))
    local titleY = love.graphics.getHeight() * 0.1
    love.graphics.setFont(titleFont)
    
    love.graphics.printf(text, 0, titleY, love.graphics.getWidth(), "center")
    
    local textWidth = titleFont:getWidth(text)
    local textX = (love.graphics.getWidth() - textWidth) / 2
    
    return titleY + titleFont:getHeight(), textX + textWidth
end

-- vvvvvvvvvvvvvvvvvvvvvv ---
--- DRAW FUNCTION BELOW ---
-- vvvvvvvvvvvvvvvvvvvvvv ---

function love.draw()
    local scaleX, scaleY = getScale()
    local buttonFont = getFont(math.max(24 * scaleY, 14))

    drawCoinAnimations()

    if game.state.running then
        love.graphics.setColor(1, 1, 1)
        for _, e in ipairs(enemies) do
            e:draw(scaleY)
        end

        for i, d in ipairs(distractions) do
            d:draw(scaleY)
        end        
        love.graphics.setColor(1, 1, 1)

        local padding = 1.15
        local imgWidth = images.player:getWidth()
        local imgHeight = images.player:getHeight()
        local scaleX, scaleY = getScale()
        local radius = player.radius * scaleY
        local drawScaleX = (radius * 2 * player.padding) / imgWidth
        local drawScaleY = (radius * 2 * player.padding) / imgHeight
        love.graphics.draw(images.player, player.x, player.y, player.rotation, drawScaleX, drawScaleY, imgWidth/2, imgHeight/2)
        
        local scaleX, scaleY = getScale()
        local pointsFont = getFont(math.max(24 * scaleY, 14))
        love.graphics.setFont(pointsFont)
        love.graphics.setColor(unpack(difficultyColors[game.difficulty]))
        love.graphics.printf(math.floor(game.points), 0, 20 * scaleY, love.graphics.getWidth(), "center")
        love.graphics.setColor(1,1,1)

        -- draw distraction box on the right

        if shop.distractions > 0 or distractionCountdown > 0 then
            local avgScale = (scaleX + scaleY) / 2
            love.graphics.draw(images.shopborder, (BASE_WIDTH-50)*scaleX, BASE_HEIGHT/2*scaleY, nil, 0.1*avgScale)
            love.graphics.draw(images.distraction, ((BASE_WIDTH-50)+5)*scaleX, ((BASE_HEIGHT/2) + 5)*scaleY, nil, 0.08*avgScale)

            local font = getFont(math.max(32 * avgScale, 16))
            love.graphics.setFont(font)

            local cx = (BASE_WIDTH-50) * scaleX
            local cy = (BASE_HEIGHT/2) * scaleY
            local r  = 12 * avgScale

            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.circle("fill", cx, cy, r)
            love.graphics.setColor(1, 1, 1, 1)

            -- text inside circle
            local font = getFont(math.max(15 * scaleY, 12))
            love.graphics.setFont(font)

            love.graphics.printf(
                shop.distractions,
                cx - r,
                cy - font:getHeight() / 2,
                r * 2,
                "center"
            )

            -- control circle

            local cx = (BASE_WIDTH-50) * scaleY
            local cy = ((BASE_HEIGHT/2)+50) * scaleY
            local r  = 12 * scaleY

            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.circle("fill", cx, cy, r)
            love.graphics.setColor(1, 1, 1, 1)

            -- text inside circle
            local font = getFont(math.max(15 * avgScale, 12))
            love.graphics.setFont(font)

            love.graphics.printf(
                inputMode == "controller" and "dUp" or "G",
                cx - r,
                cy - font:getHeight() / 2,
                r * 2,
                "center"
            )

            if distractionCountdown > 0 then
                love.graphics.setColor(1,0,0,1)
                love.graphics.printf(tostring(math.floor(distractionCountdown)).."s",(BASE_WIDTH-30) * scaleX,((BASE_HEIGHT/2)+60) * scaleY,250,"left")
            end
        end
            
        love.graphics.setColor(1,1,1,1)

        -- pause menu

        if GUI_SCREEN == "paused" then
            local guiScaleX, guiScaleY = getScale()
            local buttonsStartY = drawMenuTitle("paused") + 20 * guiScaleY
            Button:draw(buttons.paused, guiScaleX, guiScaleY, buttonFont)
        end
    else
        local titleFont = getFont(math.max(80 * scaleY, 40))
        love.graphics.setFont(titleFont)
        if GUI_SCREEN == "main_menu" then
            if GUI_SCREEN == "main_menu" then
                local buttonsStartY = drawMenuTitle("save the ball!") + 20 * scaleY
                Button:draw(buttons.main_menu, scaleX, scaleY, getFont(math.max(24 * scaleY, 14)), buttonsStartY)
            end
        elseif GUI_SCREEN == "resolution" then
            local buttonsStartY = drawMenuTitle("unsupported resolution") + 90 * scaleY

            love.graphics.setFont(getFont(24*scaleY))
            love.graphics.printf(
                "only 16:9 resolutions are supported. please exit fullscreen or things may break if you continue",
                0,
                170 * scaleY,
                love.graphics.getWidth(),
                "center"
            )

            Button:draw(buttons.resolution, scaleX, scaleY, getFont(math.max(24 * scaleY, 14)), buttonsStartY)
        elseif GUI_SCREEN == "shop" then
            local buttonsStartY, titleEndX = drawMenuTitle("shop")
            buttonsStartY = buttonsStartY + 20 * scaleY

            local btn = findButtonByText(buttons.shop, "distraction")
            local canDistraction = false
            if coins >= DISTRACTION_COINS and shop.distractions < MAX_DISTRACTIONS then canDistraction = true end
            if canDistraction then
                print("can")
                btn.color1, btn.color2 = {0, 0.9, 0, 1}, {0.4, 1, 0.4, 1}
            else
                print("cant")
                btn.color1, btn.color2 = {0.9, 0, 0, 1}, {1, 0.4, 0.4, 1}
            end

            love.graphics.draw(images.coin, titleEndX + 20*scaleX, 100*scaleY, 0, 0.1*scaleX)
            local coinFont = getFont(math.max(32*scaleY, 16))
            love.graphics.setFont(coinFont)
            love.graphics.setColor(0, 0.9, 0)
            love.graphics.printf("$"..tostring(coins), titleEndX + 80*scaleX, 105*scaleY, 720*scaleX, "left")
            love.graphics.setColor(1,1,1)

            local avgScale = (scaleX + scaleY) / 2
            love.graphics.draw(images.shopborder, 100*scaleX, 200*scaleY, nil, 0.5*avgScale)
            love.graphics.draw(images.distraction, 175*scaleX, 225*scaleY, nil, 0.2*avgScale)

            local font = getFont(math.max(32 * scaleY, 16))
            love.graphics.setFont(font)

            local boxX = 100 * scaleX
            local boxY = 200 * scaleY
            local boxSize = 256 * avgScale
            local boxCenterX = boxX + boxSize / 2

            love.graphics.printf(
                "DISTRACTION",
                boxCenterX - 200 * scaleX,
                boxY + 125 * scaleY,
                400 * scaleX,
                "center"
            )

            love.graphics.printf(
                "$" .. DISTRACTION_COINS,
                boxCenterX - 200 * scaleX,
                boxY + 160 * scaleY,
                400 * scaleX,
                "center"
            )

            local cx = 328 * scaleX
            local cy = 227 * scaleY
            local r  = 15 * avgScale

            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.circle("fill", cx, cy, r)
            love.graphics.setColor(1, 1, 1, 1)

            local font = getFont(math.max(18 * scaleY, 12))
            love.graphics.setFont(font)

            love.graphics.printf(
                shop.distractions,
                cx - r,
                cy - font:getHeight() / 2,
                r * 2,
                "center"
            )

            Button:draw(buttons.shop, scaleX, scaleY, buttonFont, buttonsStartY)
        elseif GUI_SCREEN == "settings" then
            local buttonsStartY = drawMenuTitle("settings") + 20 * scaleY
            Button:draw(buttons.settings, scaleX, scaleY, buttonFont, buttonsStartY)
            musicVolumeSlider:draw(scaleX, scaleY)
            sfxVolumeSlider:draw(scaleX, scaleY)
        elseif GUI_SCREEN == "ended" then
            love.graphics.printf("game over", titleFont, 0, TITLE_Y_DISTANCE * scaleY, love.graphics.getWidth(),
                "center")
            local subFont = getFont(math.max(24 * scaleY, 16))
            love.graphics.setFont(subFont)
            love.graphics.setColor(unpack(difficultyColors[game.difficulty]))
            love.graphics.printf("score: " .. math.floor(game.points), subFont, 0, 175 * scaleY,
                love.graphics.getWidth(), "center")
            love.graphics.printf("highscore: " .. game.highscores[game.difficulty], subFont, 0, 205 * scaleY,
                love.graphics.getWidth(), "center")
            love.graphics.setColor(1, 1, 1)
            Button:draw(buttons.ended, scaleX, scaleY, buttonFont)
            love.graphics.printf(message, subFont, 0, 600 * scaleY,
                love.graphics.getWidth(), "center")
        elseif GUI_SCREEN == "difficulty" then
            local buttonsStartY = drawMenuTitle("select difficulty") + 20 * scaleY
            Button:draw(buttons.difficulty, scaleX, scaleY, buttonFont, buttonsStartY)
        elseif GUI_SCREEN == "highscores" then
    
            local buttonsStartY = drawMenuTitle("highscores") + 20 * scaleY
            
            local textFont = getFont(math.max(50 * scaleY, 14))
            love.graphics.setFont(textFont)
        
            local scoreColor = {1,1,1}
            
            local difficulties = {
                {text = "easy", score = game.highscores[1], color = difficultyColors[1]},
                {text = "medium", score = game.highscores[2], color = difficultyColors[2]},
                {text = "hard", score = game.highscores[3], color = difficultyColors[3]},
                {text = "impossible", score = game.highscores[4], color = difficultyColors[4]},
                {text = "demon", score = game.highscores[5], color = difficultyColors[5]},
            }
            
            local yStart = 203 * scaleY
            local yStep = 80 * scaleY
            local scoreOffset = 20 * scaleY
            
            for i, diff in ipairs(difficulties) do
                local label = diff.text .. ": "
                local score = tostring(diff.score)
                
                local labelWidth = textFont:getWidth(label)
                local scoreWidth = textFont:getWidth(score)
                
                local totalWidth = labelWidth + scoreWidth + scoreOffset
                local x = (love.graphics.getWidth() - totalWidth) / 2  -- center block
            
                -- draw label
                love.graphics.setColor(unpack(diff.color))
                love.graphics.print(label, x, yStart + (i-1)*yStep)
            
                -- draw score
                love.graphics.setColor(unpack(scoreColor))
                love.graphics.print(score, x + labelWidth + scoreOffset, yStart + (i-1)*yStep)
            end            

            Button:draw(buttons.highscores, scaleX, scaleY, buttonFont, buttonsStartY)
            love.graphics.setColor(1,1,1)
        elseif GUI_SCREEN == "credits" then
            local buttonsStartY = drawMenuTitle("credits") + 20 * scaleY
            
            local titleFont = getFont(math.max(32 * scaleY, 14))
            local titleColor = {0, 1, 0}
            local textFont = getFont(math.max(22 * scaleY, 14))
            local textColor = {1, 1, 1}

            love.graphics.setFont(titleFont)
            love.graphics.setColor(unpack(titleColor))

            love.graphics.printf(
                "developers",
                0,
                200 * scaleY,
                love.graphics.getWidth(),
                "center"
            )

            love.graphics.setFont(textFont)
            love.graphics.setColor(unpack(textColor))
            
            love.graphics.printf(
                "@dextreydev",
                0,
                240 * scaleY,
                love.graphics.getWidth(),
                "center"
            )

            love.graphics.setFont(titleFont)
            love.graphics.setColor(unpack(titleColor))
            --[[
            love.graphics.printf(
                "assets",
                0,
                300 * scaleY,
                love.graphics.getWidth(),
                "center"
            )
            
            love.graphics.setFont(textFont)
            love.graphics.setColor(unpack(textColor))
            
            love.graphics.printf(
                "Main Menu Music 1 - Fesliyan Studios",
                0,
                340 * scaleY,
                love.graphics.getWidth(),
                "center"
            )
                ]]

            love.graphics.setColor(0.91, 0.19, 0.43)
            love.graphics.setFont(getFont(37*scaleY))
            love.graphics.printf(
                "Made using LÖVE2D",
                0,
                (BASE_HEIGHT-150) * scaleY,
                love.graphics.getWidth(),
                "center"
            )

            local btnFont = getFont(24 * scaleY)
            Button:draw(buttons.credits, scaleX, scaleY, btnFont)
        elseif GUI_SCREEN == "update_log" then
            local buttonsStartY = drawMenuTitle("update log") + 20 * scaleY
        
            local textFont = getFont(18*scaleY)
            love.graphics.setFont(textFont)

            local text1, text2, text3 = "", "", ""
            local current = 0

            -- PAGE 1 (V0.1-V0.3)
            if UPDATE_LOG_SCREEN == "0.1" then
                current = 0
            
                text1 =
                    "v0.1.0\n" ..
                    "- First game version"
            
                text2 =
                    "v0.2.0\n" ..
                    "- Changed UI\n" ..
                    "- Added demon difficulty\n" ..
                    "- Added enemy rolling\n" ..
                    "- Added optimizations\n" ..
                    "- Changed controls to WASD"
            
                text3 =
                    "v0.3.1\n" ..
                    "- Bug fixes"
            
            -- PAGE 2 (V0.4-V0.6)
            elseif UPDATE_LOG_SCREEN == "0.4" then
                current = 0
            
                text1 =
                    "v0.4.0\n" ..
                    "- Added music\n" ..
                    "- Added credits & update log screens\n" ..
                    "- Added new fonts"
            
                text2 =
                    "v0.5.0\n" ..
                    "- Fix credits screen scaling\n" ..
                    "- Added collisions for enemies\n" ..
                    "- Prevent enemies from wandering off the screen\n" ..
                    "- Added autosaving\n" ..
                    "- Added game simulation to the main menu"
            
                text3 =
                    "v0.6.0\n" ..
                    "- Added music and sound effect volume sliders\n" ..
                    "- Fix enemy and player image rendering/collisions\n" ..
                    "- Implemented F11 and ESC keybinds\n" ..
                    "- Added pause menu\n" ..
                    "- Added save icon in top right\n" ..
                    "- Score now renders over player/enemies\n" ..
                    "- Added coins\n" ..
                    "- Added shop\n" ..
                    "- Added distractions\n" ..
                    "- Removed menu simulation due to bugs\n" ..
                    "- Updated credits screen\n" ..
                    "- Updated highscores screen\n" ..
                    "- Updated update log screen\n" ..
                    "- Changed difficulty system\n\n\n" ..
                    "v0.6.1\n" ..
                    "- Fixed shop bug\n" ..
                    "- Fixed console showing with game"
            -- PAGE 3 (V0.7)
            elseif UPDATE_LOG_SCREEN == "0.7" then
            current = 1
                text1 =
                    "v0.7.0\n" ..
                    "- Added menu for unsupported resolutions\n" ..
                    "- Fixed a few resolution glitches\n" ..
                    "- Published to itch.io\n\n\n"..
                    "v0.7.1 (CURRENT)\n" ..
                    "- Added playlists and more music\n" ..
                    "- Added different music for different gamemodes\n" ..
                    "- Added controller compatability\n"
            end

            love.graphics.setColor(1, 1, 1)
            print(current)
            if current == 1 then love.graphics.setColor(0, 1, 0, 1) end

            love.graphics.printf(
                text1,
                50 * scaleX,
                250 * scaleY,
                love.graphics.getWidth() - 200 * scaleY,
                "left"
            )

            love.graphics.setColor(1, 1, 1)
            if current == 2 then love.graphics.setColor(0, 1, 0, 1) end

            love.graphics.printf(
                text2,
                450 * scaleX,
                250 * scaleY,
                love.graphics.getWidth() - 200 * scaleY,
                "left"
            )

            love.graphics.setColor(1, 1, 1)
            if current == 3 then love.graphics.setColor(0, 1, 0, 1) end

            love.graphics.printf(
                text3,
                850 * scaleX,
                250 * scaleY,
                love.graphics.getWidth() - 200 * scaleY,
                "left"
            )

            love.graphics.setColor(1,1,1)
            Button:draw(buttons.update_log, scaleX, scaleY, buttonFont)        
        end
    end

	if saveStatus.timer > 0 then
        local scaleX, scaleY = getScale()
        love.graphics.setColor(1, 1, 1, math.min(saveStatus.timer, 1))
        local img = images.saving
        if img then
            local x = love.graphics.getWidth() - 40 * scaleX
            local y = 8 * scaleY
            love.graphics.draw(img, x, y, nil, 0.07 * scaleX, nil)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    local scaleX, scaleY = getScale()

    if fps_counter then
        -- fps counter
        local fpsFont = getFont(16 * scaleY)
        love.graphics.setFont(fpsFont)
        love.graphics.printf(
            "FPS: " .. love.timer.getFPS(),
            10 * scaleX,
            love.graphics.getHeight() - fpsFont:getHeight() - (4 * scaleY),
            BASE_WIDTH * scaleX,
            "left"
        )
    end

    -- version number
    local versionFont = getFont(16 * scaleY)
    love.graphics.setFont(versionFont)
    local versionTextWidth = versionFont:getWidth(VERSION_NUMBER)
    love.graphics.print(
        VERSION_NUMBER,
        love.graphics.getWidth() - versionTextWidth - (10 * scaleX),
        love.graphics.getHeight() - versionFont:getHeight() - (4 * scaleY)
    )

    -- errors on top of everything

    drawErrors()
end

function love.mousemoved()
    inputMode = "mouse"
    for _, tbl in pairs(buttons) do
        for _, btn in pairs(tbl) do
            btn.hot = false
        end
    end
end

function love.mousepressed(x, y, button)
    if GUI_SCREEN == "settings" then
        musicVolumeSlider:mousepressed(x, y, button)
        sfxVolumeSlider:mousepressed(x, y, button)
    end
end

function love.mousereleased(x, y, button)
    if GUI_SCREEN == "settings" then
        musicVolumeSlider:mousereleased(x, y, button)
        sfxVolumeSlider:mousereleased(x, y, button)
    end
end

-- keybinds (should clean this up)

function back()
    if GUI_SCREEN == "highscores" or GUI_SCREEN == "shop" or GUI_SCREEN == "difficulty" or 
       GUI_SCREEN == "update_log" or GUI_SCREEN == "credits" or GUI_SCREEN == "settings" then
        uiIndex = 1
        SwitchMenuScreen("main_menu")
    end
end

function pausemenu()
    if game.state.running then
        if GUI_SCREEN == "paused" then
            GUI_SCREEN = "difficulty"
        else
            uiIndex = 1
            GUI_SCREEN = "paused"
        end
    end
end

function distraction()
    shop.distractions = shop.distractions - 1
    local scaleX, scaleY = getScale()
    distractionCountdown = distractionTime
    table.insert(distractions, Distraction(distractions, scaleY, distractionTime))

    local btn = findButtonByText(buttons.shop, "distraction")
    local canDistraction2 = false
    if coins >= DISTRACTION_COINS and shop.distractions < MAX_DISTRACTIONS then canDistraction2 = true end
    if canDistraction2 then
        print("can")
        btn.color1, btn.color2 = {0, 0.9, 0, 1}, {0.4, 1, 0.4, 1}
    else
        print("cant")
        btn.color1, btn.color2 = {0.9, 0, 0, 1}, {1, 0.4, 0.4, 1}
    end
end

function failedDistraction()
    if #distractions >= 1 then
        createNewError("already a distraction being used")
    elseif shop.distractions <= 0 then
        createNewError("not enough distractions")
    end
end

function fullscreenfn()
    _G["fullscreen"] = not _G["fullscreen"]
    love.window.setFullscreen(_G["fullscreen"])
    updateColor(findButtonByText(buttons.settings, "fullscreen"), "fullscreen")
    saveSettings()
end

function love.gamepadpressed(js, button)
    inputMode = "controller"
    if button == KEYBINDS.Menu.Controller or button == "start" or button == "menu" or button == "guide" then
        pausemenu()
        return
    end

    if button == "a" and not game.state.running then
        gamepadAPressed = true
    elseif button == "a" and GUI_SCREEN == "paused" then
        gamepadAPressed = true
    end
end

function love.gamepadreleased(joystick, button)
    if button == "a" then
        if gamepadAPressed then
            local list = buttons[GUI_SCREEN]
            local btn = list and list[uiIndex]
            if btn and btn.hot then
                btn.targetScale = 1
                btn.fn()
                if Button:getSfx() then
                    love.audio.newSource("sounds/sfx/blip.wav", "static"):play()
                end
            end
            gamepadAPressed = false
        end
    elseif button == KEYBINDS.Back.Controller then
        if GUI_SCREEN == "paused" then
            pausemenu()
        else
            back()
        end
    elseif button == KEYBINDS.Menu.Controller then
        pausemenu()
    elseif button == KEYBINDS.Distraction.Controller then
        if inputMode == "controller" then
            if shop.distractions > 0 and #distractions < 1 and game.state.running and GUI_SCREEN ~= "paused" and GUI_SCREEN == "difficulty" then
                distraction()
            elseif game.state.running and GUI_SCREEN ~= "paused" then
                failedDistraction()
            end
        end
    end
end

function love.keypressed(key)
    local inputMode = "mouse"
    if key == KEYBINDS.Fullscreen.Keyboard and not game.state.running then
        fullscreenfn()
    elseif key == KEYBINDS.Back.Keyboard then
        if game.state.running then
            pausemenu()
        else
            back()
        end
    elseif key == KEYBINDS.Distraction.Keyboard then
        if inputMode == "mouse" then
            if shop.distractions > 0 and #distractions < 1 and game.state.running and GUI_SCREEN ~= "paused" and GUI_SCREEN == "difficulty" then
                distraction()
            elseif game.state.running and GUI_SCREEN ~= "paused" then
                failedDistraction()
            end
        end
    end
end

-- save data on quit (already autosaves when data changes)

function love.quit()
    local dataToSave = {
        coins = math.floor(coins),
        shop = shop,
        difficulty = game.difficulty,
        sfx = Button:getSfx(),
        music = Button:getMusic(),
        volume = musicVolume,
        sfx_volume = sfxVolume,
        fpsCounter = fps_counter,
        fullscreen = fullscreen,
        vsync = vsync,
        bitfont = bitfont,
        highscore_easy = game.highscores[1],
        highscore_medium = game.highscores[2],
        highscore_hard = game.highscores[3],
        highscore_impossible = game.highscores[4],
        highscore_demon = game.highscores[5],
    }
    Save:save(dataToSave)
end
