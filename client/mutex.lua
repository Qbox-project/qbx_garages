local Mutex = {}
Mutex.__index = Mutex

function Mutex:new()
    return setmetatable({ locked = false }, self)
end

-- atomic-style exchange
function Mutex:acquire()
    local locked = self.locked
    if locked then
        return false
    end

    self.locked = true
    return true
end

function Mutex:release()
    self.locked = false
end

return function()
    return Mutex:new()
end
