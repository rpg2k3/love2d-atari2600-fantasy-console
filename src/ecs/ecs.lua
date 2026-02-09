-- src/ecs/ecs.lua  Entity-Component-System core
-- Entities are integer IDs. Components stored in pools keyed by entity ID.
-- Systems are objects with update(dt, world) and/or draw(world).

local World = {}
World.__index = World

function World.new()
    local w = setmetatable({}, World)
    w.nextId = 1
    w.entities = {}       -- set of active entity IDs
    w.components = {}     -- [componentName] = { [entityId] = data }
    w.systems = {}        -- ordered list of systems
    w.toRemove = {}       -- deferred removal
    w.entityCount = 0
    return w
end

function World:newEntity()
    local id = self.nextId
    self.nextId = id + 1
    self.entities[id] = true
    self.entityCount = self.entityCount + 1
    return id
end

function World:removeEntity(id)
    self.toRemove[#self.toRemove + 1] = id
end

function World:_flushRemove()
    for _, id in ipairs(self.toRemove) do
        if self.entities[id] then
            self.entities[id] = nil
            self.entityCount = self.entityCount - 1
            -- Remove all components
            for _, pool in pairs(self.components) do
                pool[id] = nil
            end
        end
    end
    if #self.toRemove > 0 then
        for i = 1, #self.toRemove do self.toRemove[i] = nil end
    end
end

function World:addComponent(entityId, name, data)
    if not self.components[name] then
        self.components[name] = {}
    end
    self.components[name][entityId] = data or true
    return data
end

function World:removeComponent(entityId, name)
    if self.components[name] then
        self.components[name][entityId] = nil
    end
end

-- Get the entire component pool
function World:get(name)
    return self.components[name] or {}
end

-- Get a specific entity's component
function World:getComponent(entityId, name)
    local pool = self.components[name]
    return pool and pool[entityId]
end

-- Check if entity has all listed components
function World:has(entityId, ...)
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        local pool = self.components[name]
        if not pool or not pool[entityId] then return false end
    end
    return true
end

-- Query: iterate entities that have ALL listed components
-- Returns iterator of (entityId, comp1, comp2, ...)
function World:query(names)
    local pools = {}
    for i, name in ipairs(names) do
        pools[i] = self.components[name]
        if not pools[i] then
            -- empty result
            return function() return nil end
        end
    end
    -- Use smallest pool for iteration
    local smallest, smallIdx = nil, 1
    for i, p in ipairs(pools) do
        local n = 0
        for _ in pairs(p) do n = n + 1 end
        if not smallest or n < smallest then
            smallest = n
            smallIdx = i
        end
    end
    local iter = pairs(pools[smallIdx])
    local key = nil
    return function()
        while true do
            local id, _
            id, _ = iter(pools[smallIdx], key)
            key = id
            if id == nil then return nil end
            -- Check all pools
            local ok = true
            for i, p in ipairs(pools) do
                if not p[id] then ok = false; break end
            end
            if ok then
                -- Return entity id plus each component
                if #names == 1 then
                    return id, pools[1][id]
                elseif #names == 2 then
                    return id, pools[1][id], pools[2][id]
                elseif #names == 3 then
                    return id, pools[1][id], pools[2][id], pools[3][id]
                else
                    local comps = {}
                    for i, p in ipairs(pools) do comps[i] = p[id] end
                    return id, unpack(comps)
                end
            end
        end
    end
end

-- Register a system (order matters)
function World:addSystem(system)
    self.systems[#self.systems + 1] = system
end

-- Update all systems
function World:update(dt)
    for _, sys in ipairs(self.systems) do
        if sys.update then sys:update(dt, self) end
    end
    self:_flushRemove()
end

-- Draw all systems
function World:draw()
    for _, sys in ipairs(self.systems) do
        if sys.draw then sys:draw(self) end
    end
end

return World
