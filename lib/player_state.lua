local ps = {}

ps.id = 0
ps.name = ''
ps.status = 0
ps.main_job = ''
ps.main_job_level = 0
ps.sub_job = ''
ps.sub_job_level = 0
ps.hp = 0
ps.hpp = 0
ps.mp = 0
ps.mpp = 0
ps.tp = 0
ps.tpp = 0

function ps.refresh()
    local p = windower.ffxi.get_player()
    if not p then return end
    ps.id = p.id
    ps.name = p.name
    ps.status = p.status
    ps.main_job = p.main_job
    ps.main_job_level = p.main_job_level
    ps.sub_job = p.sub_job
    ps.sub_job_level = p.sub_job_level
    local v = p.vitals
    ps.hp = v.hp
    ps.hpp = v.hpp
    ps.mp = v.mp
    ps.mpp = v.mpp
    ps.tp = v.tp
    ps.tpp = math.min(v.tp / 10, 100)
end

return ps
