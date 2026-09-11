local love = require("love")

local BASE_WIDTH, BASE_HEIGHT = 1280, 720

local images = {
    distraction = love.graphics.newImage("images/distraction.png")
}

function Distraction(distractions, scaleY, time)
    local _radius = 23
    local _colliderFactor = 0.96
    local _speed = 8
    local _x, _y

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local side = math.random(1,4)
    
    local scaleX = w / BASE_WIDTH
    local avgScale = (scaleX + scaleY) / 2
    local scaledCollider = _colliderFactor * _radius * avgScale
    local scaledRadius   = _radius * avgScale

    if side == 1 then
        _x = math.random(scaledRadius, w - scaledRadius)
        _y = -scaledCollider * 2
    elseif side == 2 then
        _x = -scaledCollider * 2
        _y = math.random(scaledRadius, h - scaledRadius)
    elseif side == 3 then
        _x = math.random(scaledRadius, w - scaledRadius)
        _y = h + scaledCollider * 2
    else
        _x = w + scaledCollider * 2
        _y = math.random(scaledRadius, h - scaledRadius)
    end

    local self = {
        radius = _radius,
        colliderFactor = _colliderFactor,
        speed = _speed,
        rotation = 0,
        x = _x,
        y = _y,
        timer = 0,
        maxTimer = time,
        dead = false,
        wanderTimer = 0,
        wanderDirX = 0,
        wanderDirY = 0,
        isWandering = false,
        spinDir = 1,
        insideScreen = false,
        distractions = distractions or {},
        timeSinceSpawn = 0,
        img = images.distraction
    }

    function self:getColliderRadius()
        return self.radius * self.colliderFactor
    end

    function self:move(dt, distractions, player, enemies, scale)
        self.timeSinceSpawn = self.timeSinceSpawn + dt
        local baseSpeed = 50 * self.speed
        self.timer = self.timer + dt

        if self.timer >= self.maxTimer then self.dead = true return end

        -- wandering
        self.wanderTimer = self.wanderTimer - dt
        if self.wanderTimer <= 0 then
            self.isWandering = true
            local angle = math.random() * 2 * math.pi
            self.wanderDirX = math.cos(angle)
            self.wanderDirY = math.sin(angle)
            self.wanderTimer = math.random(1, 3)
        end

        if self.isWandering then
            self.x = self.x + self.wanderDirX * baseSpeed * dt * scale
            self.y = self.y + self.wanderDirY * baseSpeed * dt * scale
        end

        local cr = self:getColliderRadius() * scale
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()

        -- window collisions
        if self.x - cr < 0 then self.x = cr; self.wanderDirX = -self.wanderDirX end
        if self.x + cr > w then self.x = w - cr; self.wanderDirX = -self.wanderDirX end
        if self.y - cr < 0 then self.y = cr; self.wanderDirY = -self.wanderDirY end
        if self.y + cr > h then self.y = h - cr; self.wanderDirY = -self.wanderDirY end

        -- distraction collisions
        for _, other in ipairs(distractions or {}) do
            if other ~= self and other.x and other.y then
                local dx = other.x - self.x
                local dy = other.y - self.y
                local dist = math.sqrt(dx*dx + dy*dy)
                local minDist = cr + other:getColliderRadius() * scale
                if dist < minDist and dist > 0 then
                    local overlap = minDist - dist
                    local nx, ny = dx / dist, dy / dist
                    self.x = self.x - nx * (overlap/2)
                    self.y = self.y - ny * (overlap/2)
                    other.x = other.x + nx * (overlap/2)
                    other.y = other.y + ny * (overlap/2)
                end
            end
        end

        -- player collisions
        if player and player.x and player.y then
            local pr = player:getColliderRadius() * scale
            local dx = player.x - self.x
            local dy = player.y - self.y
            local dist = math.sqrt(dx*dx + dy*dy)
            local minDist = cr + pr
            if dist < minDist and dist > 0 then
                local overlap = minDist - dist
                local nx, ny = dx / dist, dy / dist
                self.x = self.x - nx * (overlap/2)
                self.y = self.y - ny * (overlap/2)
                player.x = player.x + nx * (overlap/2)
                player.y = player.y + ny * (overlap/2)
            end
        end

        -- enemy collisions
        for _, e in ipairs(enemies or {}) do
            if e.x and e.y then
                local er = e.getColliderRadius and e:getColliderRadius()*scale or e.radius or 20
                local dx = e.x - self.x
                local dy = e.y - self.y
                local dist = math.sqrt(dx*dx + dy*dy)
                local minDist = cr + er
                if dist < minDist and dist > 0 then
                    local overlap = minDist - dist
                    local nx, ny = dx / dist, dy / dist
                    self.x = self.x - nx * (overlap/2)
                    self.y = self.y - ny * (overlap/2)
                    e.x = e.x + nx * (overlap/2)
                    e.y = e.y + ny * (overlap/2)
                end
            end
        end
    end

    function self:draw(scale)
        scale = scale or 1
        local imgW, imgH = self.img:getWidth(), self.img:getHeight()
        local visualRadius = self.radius * scale
        local scaleX = (visualRadius * 2) / imgW
        local scaleY = (visualRadius * 2) / imgH
        love.graphics.draw(self.img, self.x, self.y, 0, scaleX, scaleY, imgW/2, imgH/2)
    end
    return self
end

return Distraction