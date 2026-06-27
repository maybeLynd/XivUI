local DPSClock = {}
DPSClock.__index = DPSClock

function DPSClock:new()
    return setmetatable({ clock = 0, prev_time = 0, active = false }, self)
end

function DPSClock:advance()
    local now = os.time()
    if self.prev_time == 0 then self.prev_time = now end
    self.clock = self.clock + (now - self.prev_time)
    self.prev_time = now
    self.active = true
end

function DPSClock:pause()
    self.active = false
    self.prev_time = 0
end

function DPSClock:is_active()
    return self.active
end

function DPSClock:reset()
    self.active = false
    self.clock = 0
    self.prev_time = 0
end

function DPSClock:to_string()
    local seconds = self.clock
    local hours = math.floor(seconds / 3600)
    seconds = seconds - hours * 3600
    local minutes = math.floor(seconds / 60)
    seconds = seconds - minutes * 60
    return (hours > 0 and hours .. 'h' or '') ..
           (minutes > 0 and minutes .. 'm' or '') ..
           (seconds .. 's')
end

return DPSClock
