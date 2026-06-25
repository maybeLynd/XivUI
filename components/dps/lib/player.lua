
local Player = {}
Player.__index = Player

function Player:new(name)
    return setmetatable({
        name = name,
        is_sc = name == 'Skillchain',
        is_mb = name == 'Magic Burst',
        is_pet = false,
        role_override = nil,
        job   = nil,

        damage = 0,
        max_hit = 0,

        ws_count = 0, ws_damage = 0, ws_misses = 0,

        m_hits = 0, m_misses = 0, m_crits = 0,
        r_hits = 0, r_misses = 0, r_crits = 0,

        heal_amount = 0, heal_count = 0,

        melee_taken = 0,
        blocks = 0, parries = 0, evades = 0, guards = 0, deaths = 0,

        mb_damage  = 0,
    }, self)
end

local function note_hit(self, damage)
    if damage > self.max_hit then self.max_hit = damage end
end

function Player:add_damage(damage)
    self.damage = self.damage + damage
    note_hit(self, damage)
end

function Player:add_ws_damage(damage)
    self.ws_count = self.ws_count + 1
    self.ws_damage = self.ws_damage + damage
    self.damage = self.damage + damage
    note_hit(self, damage)
end

function Player:add_m_hit(damage)
    self.m_hits = self.m_hits + 1
    self.damage = self.damage + damage
    note_hit(self, damage)
end

function Player:add_m_crit(damage)
    self.m_crits = self.m_crits + 1
    self.damage = self.damage + damage
    note_hit(self, damage)
end

function Player:add_r_hit(damage)
    self.r_hits = self.r_hits + 1
    self.damage = self.damage + damage
    note_hit(self, damage)
end

function Player:add_r_crit(damage)
    self.r_crits = self.r_crits + 1
    self.damage = self.damage + damage
    note_hit(self, damage)
end

function Player:add_mb(damage)
    self.mb_damage = self.mb_damage + damage
    self.damage = self.damage + damage
    note_hit(self, damage)
end

function Player:add_heal(amount)
    self.heal_count = self.heal_count + 1
    self.heal_amount = self.heal_amount + amount
end

function Player:incr_m_misses()  self.m_misses  = self.m_misses  + 1 end
function Player:incr_r_misses()  self.r_misses  = self.r_misses  + 1 end
function Player:incr_ws_misses() self.ws_misses = self.ws_misses + 1 end
function Player:incr_melee_taken() self.melee_taken = self.melee_taken + 1 end
function Player:incr_block()  self.blocks  = self.blocks  + 1 end
function Player:incr_parry()  self.parries = self.parries + 1 end
function Player:incr_evade()  self.evades  = self.evades  + 1 end
function Player:incr_guard()  self.guards  = self.guards  + 1 end
function Player:incr_death()  self.deaths  = self.deaths  + 1 end

function Player:get_dps(clock)
    if not clock or clock <= 0 then return 0 end
    return self.damage / clock
end

function Player:get_hps(clock)
    if not clock or clock <= 0 then return 0 end
    return self.heal_amount / clock
end

function Player:crit_pct()
    local swings = self.m_hits + self.m_crits
    if swings == 0 then return 0 end
    return 100 * self.m_crits / swings
end

function Player:swings_at_me()
    return self.melee_taken + self.blocks + self.parries + self.evades + self.guards
end

function Player:block_pct()
    local s = self:swings_at_me()
    return s == 0 and 0 or 100 * self.blocks / s
end

function Player:parry_pct()
    local s = self:swings_at_me()
    return s == 0 and 0 or 100 * self.parries / s
end

function Player:eva_pct()
    local s = self:swings_at_me()
    return s == 0 and 0 or 100 * self.evades / s
end

function Player:guard_pct()
    local s = self:swings_at_me()
    return s == 0 and 0 or 100 * self.guards / s
end

return Player
