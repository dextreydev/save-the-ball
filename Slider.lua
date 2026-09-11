local love = require("love")

local Slider = {}
Slider.__index = Slider

Slider.currentDragging = nil
Slider.currentController = nil

function Slider:create(width, min, max, value, label, xRatio, yRatio)
    local s = setmetatable({}, Slider)
    s.baseWidth = width or 200
    s.baseHeight = 10
    s.min = min or 0
    s.max = max or 100
    s.value = value or s.min
    s.label = label or ""
    s.handleRadius = 10
    s.xRatio = xRatio or 0.5
    s.yRatio = yRatio or 0.5
    s.hover = false
    s.dragging = false
    s.controllerActive = false
    s.controllerFocus = false
    s.ignoreStick = false
    s.handleScale = 1
    s.handleScaleTarget = 1
    s.controllerRing = 0
    s.controllerRingTarget = 0
    s.refWidth, s.refHeight = 1280, 720
    s.avgScale = 1
    return s
end

function Slider:update(dt, scaleX, scaleY, controllerActive)
    if not scaleX then
        local sw, sh = love.graphics.getDimensions()
        scaleX = sw / self.refWidth
        scaleY = sh / self.refHeight
    end
    
    self.avgScale = (scaleX + scaleY) / 2
    local w = self.baseWidth * scaleX
    local h = self.baseHeight * scaleY
    local handleR = self.handleRadius * self.avgScale

    self.x = self.xRatio * love.graphics.getWidth()
    self.y = self.yRatio * love.graphics.getHeight()
    if self.xRatio == 0.5 then self.x = self.x - w/2 end
    if self.yRatio == 0.5 then self.y = self.y - h/2 end

    local mx, my = love.mouse.getPosition()
    local handleX = self.x + ((self.value - self.min)/(self.max - self.min)) * w
    local handleY = self.y + h/2

    local dx = mx - handleX
    local dy = my - handleY
    self.hover = (dx*dx + dy*dy) <= handleR*handleR

    if self.dragging then
        local clampedX = math.max(self.x, math.min(mx, self.x + w))
        self.value = self.min + (clampedX - self.x)/w * (self.max - self.min)
    end
    
    if controllerActive and not self.controllerFocus then
        self.controllerFocus = true
        self.ignoreStick = true
    elseif not controllerActive and self.controllerFocus then
        self.controllerFocus = false
        self.ignoreStick = false
    end

    if controllerActive then
        local js = love.joystick.getJoysticks()[1]
        if js then
            local leftStickX = js:getGamepadAxis("leftx")
            local dpadLeft = js:isGamepadDown("dpleft")
            local dpadRight = js:isGamepadDown("dpright")
            
            local stickDeadzone = 0.12
            if self.ignoreStick then
                if math.abs(leftStickX) < stickDeadzone then
                    self.ignoreStick = false
                end
            end

            if not self.ignoreStick and math.abs(leftStickX) > stickDeadzone then
                local stickStrength = math.abs(leftStickX)
                local joystickStep = (self.max - self.min) * 0.6 * stickStrength * dt
                if leftStickX > 0 then
                    self.value = math.min(self.max, self.value + joystickStep)
                else
                    self.value = math.max(self.min, self.value - joystickStep)
                end
            end

            if dpadRight then
                local dpadStep = (self.max - self.min) * 1.0 * dt
                self.value = math.min(self.max, self.value + dpadStep)
            elseif dpadLeft then
                local dpadStep = (self.max - self.min) * 1.0 * dt
                self.value = math.max(self.min, self.value - dpadStep)
            end
        end
    end
    self.controllerActive = controllerActive

    
    local desiredScale = 1
    if self.dragging or self.hover or (self.controllerActive and self.controllerFocus) or self.controllerActive then
        desiredScale = 1.35
    end
    self.handleScaleTarget = desiredScale
    local interpSpeed = 8
    self.handleScale = self.handleScale + (self.handleScaleTarget - self.handleScale) * math.min(1, interpSpeed * dt)

    
    self.controllerRingTarget = (self.controllerActive and not self.dragging) and 1 or 0
    local ringSpeed = 10
    if self.controllerRingTarget == 0 then
        self.controllerRing = 0
    else
        self.controllerRing = self.controllerRing + (self.controllerRingTarget - self.controllerRing) * math.min(1, ringSpeed * dt)
    end
end

function Slider:mousepressed(mx, my, button)
    if button == 1 and Slider.currentDragging == nil then
        local sw, sh = love.graphics.getDimensions()
        local scaleX = sw / self.refWidth
        local scaleY = sh / self.refHeight
        local avgScale = (scaleX + scaleY) / 2
        local w = self.baseWidth * scaleX
        local h = self.baseHeight * scaleY
        local handleR = self.handleRadius * avgScale

        self.x = self.xRatio * sw
        self.y = self.yRatio * sh
        if self.xRatio == 0.5 then self.x = self.x - w/2 end
        if self.yRatio == 0.5 then self.y = self.y - h/2 end

        local handleX = self.x + ((self.value - self.min)/(self.max - self.min)) * w
        local handleY = self.y + h/2

        local overHandle = ((mx - handleX)^2 + (my - handleY)^2) <= handleR^2
        local overBar = mx >= self.x and mx <= self.x + w and my >= self.y and my <= self.y + h

        if overHandle or overBar then
            local clampedX = math.max(self.x, math.min(mx, self.x + w))
            self.value = self.min + (clampedX - self.x)/w * (self.max - self.min)

            self.dragging = true
            Slider.currentDragging = self
        end
    end
end

function Slider:mousereleased(mx, my, button)
    if button == 1 and self.dragging then
        self.dragging = false
        Slider.currentDragging = nil
    end
end

function Slider:draw(scaleX, scaleY)
    if not scaleX then
        local sw, sh = love.graphics.getDimensions()
        scaleX = sw / self.refWidth
        scaleY = sh / self.refHeight
    end

    local avgScale = (scaleX + scaleY) / 2
    local w = self.baseWidth * scaleX
    local h = self.baseHeight * scaleY
    local handleR = self.handleRadius * avgScale

    local x, y = self.x, self.y
    local valPct = (self.value - self.min)/(self.max - self.min)
    local handleX = x + valPct * w
    local handleY = y + h/2

    if self.label ~= "" then
        local font = love.graphics.getFont()
        local textW = font:getWidth(self.label)
        local textH = font:getHeight()
        love.graphics.setColor(1,1,1)
        love.graphics.print(self.label, x + (w - textW)/2, y - textH - 5 * scaleY)
    end

    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, y, w, h, h/2, h/2)
    love.graphics.setColor(0, 0.8, 0, 1)
    love.graphics.rectangle("fill", x, y, handleX - x, h, h/2, h/2)
    love.graphics.setColor(1,1,1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, h/2, h/2)

    local handleScale = self.handleScale or 1

    if self.controllerRing and self.controllerRing > 0.01 then
        local alpha = 0.9
        love.graphics.setColor(1, 1, 1, alpha)
        local ringRadius = handleR * 1.2 * handleScale
        local ringLine = 2.5 * handleScale
        love.graphics.setLineWidth(ringLine)
        love.graphics.circle("line", handleX, handleY, ringRadius)
    end

    

    love.graphics.setColor(0, 0.4, 0)
    love.graphics.circle("fill", handleX, handleY, handleR * handleScale)
    love.graphics.setColor(1,1,1)
end

return Slider
