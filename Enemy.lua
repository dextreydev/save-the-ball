local love = require("love")

local BASE_WIDTH, BASE_HEIGHT = 1280, 720

function Enemy(_level, distractions, scaleY, allEnemies)
    local _radius = 23
    local _colliderFactor = 0.96
    local _speed = _level
    local _x, _y

    local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    local side = math.random(1,4)
    
    local scaleX = w / BASE_WIDTH
    local avgScale = (scaleX + scaleY) / 2
    local spawnRadius = _radius * _colliderFactor * avgScale

    if side == 1 then
        _x = math.random(spawnRadius, w - spawnRadius)
        _y = -spawnRadius * 2
    elseif side == 2 then
        _x = -spawnRadius * 2
        _y = math.random(spawnRadius, h - spawnRadius)
    elseif side == 3 then
        _x = math.random(spawnRadius, w - spawnRadius)
        _y = h + spawnRadius * 2
    else
        _x = w + spawnRadius * 2
        _y = math.random(spawnRadius, h - spawnRadius)
    end


    local self = {
        level = _level or 1,
        radius = _radius,
        colliderFactor = _colliderFactor,
        speed = _speed,
        rotation = 0,
        scale = avgScale,
        x = _x,
        y = _y,
        insideScreen = false,
        spinDir = 1,
        distractions = distractions or {},
        timeSinceSpawn = 0,
        wanderTimer = 2,
        wanderDirX = 0,
        wanderDirY = 0,
        isWandering = false,
        allEnemies = allEnemies,
    }

    function self:getColliderRadius()
        return self.radius * self.colliderFactor
    end      

    function self:checkTouched(px, py, pr)
        local cr = self:getColliderRadius() * self.scale * self.scale
        local dx = self.x - px
        local dy = self.y - py
        return (dx*dx + dy*dy) <= (pr + cr)^2
    end    

    function self:move(px, py, dt, enemySpeed)
        self.timeSinceSpawn = self.timeSinceSpawn + dt
        enemySpeed = enemySpeed or 1
        local baseSpeed = 50 + (self.level - 1) * 10 * (enemySpeed / 100)
    
        local cr = self:getColliderRadius() * self.scale
        local w, h = love.graphics.getWidth(), love.graphics.getHeight()
    
        -- check if enemy has entered the screen
        if not self.insideScreen then
            if self.x > cr and self.x < w - cr and self.y > cr and self.y < h - cr then
                self.insideScreen = true
            end
        end
    
        -- find closest distraction
        local closest, minDist = nil, math.huge
        for _, d in ipairs(self.distractions) do
            if d and d.x and d.y then
                local dx = d.x - self.x
                local dy = d.y - self.y
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist < minDist then
                    minDist = dist
                    closest = d
                end
            end
        end
    
        -- handle wandering timer
        self.wanderTimer = self.wanderTimer - dt
        if self.wanderTimer <= 0 then
            self.wanderTimer = 2
            self.isWandering = math.random() < 0.3
            if self.isWandering then
                local a = math.random() * math.pi * 2
                self.wanderDirX = math.cos(a)
                self.wanderDirY = math.sin(a)
            else
                self.wanderDirX, self.wanderDirY = 0, 0
            end
        end
    
        -- decide target position
        local targetX, targetY
        if closest then
            -- go to distraction
            targetX, targetY = closest.x, closest.y
            self.isWandering = false
        elseif self.isWandering then
            -- wander randomly
            targetX, targetY = self.x + self.wanderDirX * 100, self.y + self.wanderDirY * 100
        else
            -- move toward player
            targetX, targetY = px, py
        end
    
        -- compute movement
        local dx = targetX - self.x
        local dy = targetY - self.y
        local dist = math.sqrt(dx*dx + dy*dy)
        local moveX, moveY = 0, 0
    
        if dist > 0 then
            local nx, ny = dx / dist, dy / dist
            moveX = nx * baseSpeed * dt
            moveY = ny * baseSpeed * dt
            self.spinDir = nx >= 0 and 1 or -1
        end
    
        -- movement
        self.x = self.x + moveX * scaleY
        self.y = self.y + moveY * scaleY
    
        -- prevent moving out of window
        if self.insideScreen then
            self.x = math.max(cr, math.min(w - cr, self.x))
            self.y = math.max(cr, math.min(h - cr, self.y))
        end
    
        -- rotation
        self.rotation = self.rotation + (self.spinDir * baseSpeed / 50 * dt)
    
        -- enemy collisions
        if self.allEnemies then
            for _, other in ipairs(self.allEnemies) do
                if other ~= self then
                    local dx = other.x - self.x
                    local dy = other.y - self.y
                    local dist = math.sqrt(dx*dx + dy*dy)
                    local minDist = cr + other:getColliderRadius() * self.scale
                    if dist < minDist and dist > 0 then
                        local overlap = minDist - dist
                        local nx, ny = dx / dist, dy / dist
                        self.x = self.x - nx * (overlap / 2)
                        self.y = self.y - ny * (overlap / 2)
                        other.x = other.x + nx * (overlap / 2)
                        other.y = other.y + ny * (overlap / 2)
                    end
                end
            end
        end
    end

    function self:draw(scale)
        local img = images.enemy
        local r = self.radius * scale
        local sx = (r * 2) / img:getWidth()
        local sy = (r * 2) / img:getHeight()
        love.graphics.draw(img, self.x, self.y, self.rotation, sx, sy, img:getWidth()/2, img:getHeight()/2)
    end

    return self
end

return Enemy