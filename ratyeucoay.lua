repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("DataLoaded")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Player = Players.LocalPlayer
local CommF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
local previous = getgenv().DwacTrackNotifier
if previous and previous.Stop then previous.Stop() end
local Runtime = {Running = true, Version = "2026.11.27-no-berry", JobId = game.JobId, Threads = {}, Connections = {}, DeadBosses = {}, Stable = {}, Candidates = {}}
getgenv().DwacTrackNotifier = Runtime
local Config = getgenv().DwacNotifyConfig or {}
getgenv().DwacNotifyConfig = Config
for key, value in pairs({Url = "https://nf.quachlehuyy.workers.dev/notify", Token = "", ScanSeconds = 1,
    HeartbeatSeconds = 20, IdleHeartbeatSeconds = 60, ChangeDebounceSeconds = 3, DryRun = false}) do
    if Config[key] == nil then Config[key] = value end
end
local Sea = ({[2753915549]=1,[85211729168715]=1,[4442272183]=2,[79091703265657]=2,[7449423635]=3,[100117331123089]=3})[game.PlaceId] or 0
local BossSea = {["rip_indra True Form"]=3,["Dough King"]=3,["Cake Prince"]=3,["Soul Reaper"]=3,["Cake Queen"]=3,
    ["Darkbeard"]=2,["Cursed Captain"]=2,["Tyrant of the Skies"]=3}
local CastleMobs = {["Pirate Millionaire"]=true,["Pistol Billionaire"]=true,["Dragon Crew Warrior"]=true,["Dragon Crew Archer"]=true}
local BossWatches = setmetatable({}, {__mode = "k"})
local SeenDeaths = setmetatable({}, {__mode = "k"})
local DeathTimes = {}
local function RememberDeath(model, name)
    if not SeenDeaths[model] then
        SeenDeaths[model],Runtime.DeadBosses[name],DeathTimes[name] = true,true,os.clock()
    end
end
local function Spawn(callback)
    local thread = task.spawn(function()
        local ok, err = pcall(callback)
        if not ok and Runtime.Running then Runtime.LastError = tostring(err); warn("[Dwac Track] " .. tostring(err)) end
    end)
    Runtime.Threads[thread] = true
    return thread
end
function Runtime.Stop()
    Runtime.Running = false
    for _, connection in ipairs(Runtime.Connections) do pcall(function() connection:Disconnect() end) end
    for thread in pairs(Runtime.Threads) do if thread ~= coroutine.running() then pcall(task.cancel, thread) end end
end
local function Night(hour) return hour >= 18 or hour < 5 end
local function BossName(name) return name:gsub("%s+%[.*$", "") end
local function Alive(model)
    local hum = model:IsA("Model") and model:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0 and model:FindFirstChild("HumanoidRootPart") ~= nil
end
local function WatchBoss(model, name)
    if BossWatches[model] then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local connection = hum.Died:Connect(function()
        if Runtime.Running then RememberDeath(model,name) end
    end)
    BossWatches[model] = connection
    table.insert(Runtime.Connections, connection)
end
local function ScanBosses()
    local events, seen = {}, {}
    -- EnemySpawns contains spawn points, not proof that a boss exists.
    for _, folder in pairs({Workspace:FindFirstChild("Enemies"), ReplicatedStorage}) do
        for _, model in ipairs(folder:GetChildren()) do
            local name = BossName(model.Name)
            if BossSea[name] == Sea and model:IsA("Model") then
                local hum = model:FindFirstChildOfClass("Humanoid")
                if Alive(model) then
                    WatchBoss(model, name)
                    if DeathTimes[name] and os.clock()-DeathTimes[name]>20 then Runtime.DeadBosses[name] = nil end
                    if not seen[name] and not Runtime.DeadBosses[name] then
                        seen[name] = true
                        events[#events+1] = {Name=name,Confirmed=true,Evidence="Alive"}
                    end
                elseif hum and hum.Health <= 0 then RememberDeath(model,name) end
            end
        end
    end
    return events
end
local function ScanMoon()
    local phase = tonumber(Lighting:GetAttribute("MoonPhase"))
    local sky = Lighting:FindFirstChild("Sky") or Lighting:FindFirstChild("FantasySky")
    local texture = sky and tostring(sky.MoonTextureId):match("(%d+)$")
    local full = phase == 5 or texture == "9709149431"
    local nextNight = phase == 4
    if full then
        if Night(Lighting.ClockTime) then return {{MoonPhase="Full Moon",Confirmed=true,Evidence="MoonPhase"}} end
        if Lighting.ClockTime >= 12 then return {{MoonPhase="Next Night",Confirmed=true,Evidence="MoonPhase"}} end
        return {}
    end
    if nextNight then return {{MoonPhase="Next Night",Confirmed=true,Evidence="MoonPhase"}} end
    if phase or texture then return {} end
end
local function ScanIsland(name, markerName)
    local map = Workspace:FindFirstChild("Map")
    if not map then return nil end
    local origin = Workspace:FindFirstChild("_WorldOrigin")
    local locations = origin and origin:FindFirstChild("Locations")
    if map:FindFirstChild(name) or (locations and locations:FindFirstChild(markerName)) then
        return {{Confirmed=true,Evidence="IslandModel"}}
    end
    return {}
end
local function ScanCastle()
    local origin = Vector3.new(-5000,350,-3035)
    for _, folder in pairs({Workspace:FindFirstChild("Enemies"), ReplicatedStorage}) do
        for _, model in ipairs(folder:GetChildren()) do
            if CastleMobs[BossName(model.Name)] and Alive(model) then
                local root = model:FindFirstChild("HumanoidRootPart")
                if (root.Position-origin).Magnitude <= 550 then return {{Confirmed=true,Evidence="RaidEnemy"}} end
            end
        end
    end
    return {}
end
local function SortEvents(events)
    table.sort(events, function(a,b) return (a.Name or a.Haki or a.MoonPhase or "") < (b.Name or b.Haki or b.MoonPhase or "") end)
end
local function Observe(kind, callback)
    local ok, events = pcall(callback)
    if not ok or type(events) ~= "table" then return end
    SortEvents(events)
    local signature = HttpService:JSONEncode(events)
    local candidate = Runtime.Candidates[kind]
    if not candidate or candidate.Hash ~= signature then
        candidate = {Hash=signature,Since=os.clock(),Events=events}
        Runtime.Candidates[kind] = candidate
    end
    if not Runtime.Stable[kind] or os.clock()-candidate.Since >= Config.ChangeDebounceSeconds then
        -- Initial empty observations are safe; initial positives need the same debounce as changes.
        if #events == 0 or os.clock()-candidate.Since >= Config.ChangeDebounceSeconds then
            Runtime.Stable[kind] = {Hash=signature,Events=events,KnownAt=os.clock()}
        end
    elseif Runtime.Stable[kind].Hash == signature then Runtime.Stable[kind].KnownAt = os.clock() end
    local stable = Runtime.Stable[kind]
    if stable and stable.Hash == signature then stable.KnownAt = os.clock() end
end
local function Snapshot()
    local observations, hasEvents, hashParts, capturedDeaths = {}, false, {}, {}
    for _, kind in ipairs({"Rare Boss","Moon","Mirage","Castle","Island","Legendary"}) do
        local stable = Runtime.Stable[kind]
        local knownFor = kind == "Legendary" and 45 or 5
        if stable and os.clock()-stable.KnownAt <= knownFor and (kind ~= "Legendary" or Runtime.HakiKnown) then
            local events = table.clone(stable.Events)
            if kind == "Rare Boss" then
                for name in pairs(Runtime.DeadBosses) do
                    events[#events+1] = {Name=name,Active=false,Confirmed=true,Evidence="Dead"}
                    capturedDeaths[name] = true
                end
                for index=#events,1,-1 do
                    if events[index].Active ~= false and Runtime.DeadBosses[events[index].Name] then table.remove(events,index) end
                end
            end
            SortEvents(events)
            observations[#observations+1] = {Type=kind,Events=events}
            hasEvents = hasEvents or #events > 0
            hashParts[#hashParts+1] = kind .. HttpService:JSONEncode(events)
        end
    end
    return observations,table.concat(hashParts,"|"),hasEvents,capturedDeaths
end
local function RequestFunction()
    if type(syn) == "table" and type(syn.request) == "function" then return syn.request end
    if type(http_request) == "function" then return http_request end
    if type(request) == "function" then return request end
end
local session, sequence = HttpService:GenerateGUID(false), 0
local nextSend, lastSuccess, lastHash, failures, pending = 0, -math.huge, nil, 0, nil
Spawn(function()
    while Runtime.Running do
        if Sea == 2 or Sea == 3 then Observe("Rare Boss",ScanBosses) end
        if Sea == 3 then
            Observe("Moon",ScanMoon)
            Observe("Mirage",function() return ScanIsland("MysticIsland","Mirage Island") end)
            Observe("Island",function() return ScanIsland("PrehistoricIsland","Prehistoric Island") end)
            Observe("Castle",ScanCastle)
        end
        task.wait(math.max(0.5,tonumber(Config.ScanSeconds) or 1))
    end
end)
Spawn(function()
    while Runtime.Running and (Sea == 2 or Sea == 3) do
        local ok, value = pcall(CommF.InvokeServer,CommF,"ColorsDealer","1")
        Runtime.HakiKnown = ok and (value == nil or value == false or type(value) == "number" or type(value) == "string")
        if Runtime.HakiKnown then
            local events = {}
            if type(value) == "string" and #value >= 3 and #value <= 72 and not tonumber(value)
                and not value:find("[<>\n\r]") and not value:lower():find("not available",1,true)
                and not value:lower():find("come back",1,true) and not value:lower():find("don't",1,true) then
                events[1] = {Haki=value,Confirmed=true,Evidence="ColorsDealer"}
            end
            SortEvents(events)
            Runtime.Stable.Legendary = {Hash=HttpService:JSONEncode(events),Events=events,KnownAt=os.clock()}
        end
        task.wait(30)
    end
end)
Spawn(function()
    while Runtime.Running do
        task.wait(0.25)
        if Sea == 0 or game.JobId == "" or os.clock() < nextSend then continue end
        local observations, hash, active, deaths = Snapshot()
        local heartbeat = active and Config.HeartbeatSeconds or Config.IdleHeartbeatSeconds
        if not pending and hash == lastHash and os.clock()-lastSuccess < heartbeat then continue end
        if pending and os.clock()-pending.CreatedAt > 40 then pending = nil end
        if not pending then
            sequence += 1
            pending = {CreatedAt=os.clock(),Hash=hash,Deaths=deaths,Body={Version=2,JobId=game.JobId,PlaceId=game.PlaceId,
                ReporterId=tostring(Player.UserId),SessionId=session,Sequence=sequence,SentAt=DateTime.now().UnixTimestampMillis,
                Players={Count=Players.NumPlayers,Max=Players.MaxPlayers},ClockTime=Lighting.ClockTime,Observations=observations}}
        end
        local captured = pending
        if Config.DryRun then
            Runtime.LastPayload, Runtime.LastError = captured.Body, nil
            lastHash,lastSuccess,pending,nextSend = captured.Hash,os.clock(),nil,os.clock()+3
            for name in pairs(captured.Deaths) do Runtime.DeadBosses[name] = nil end
            continue
        end
        local requestFunc = RequestFunction()
        if not requestFunc then Runtime.LastError="HTTP request function unavailable"; nextSend=os.clock()+60; continue end
        local headers = {["Content-Type"]="application/json"}
        if Config.Token ~= "" then headers["X-Dwac-Notify-Key"] = Config.Token end
        local ok, response = pcall(requestFunc,{Url=Config.Url,Method="POST",Headers=headers,Body=HttpService:JSONEncode(captured.Body),Timeout=10})
        local status = ok and type(response) == "table" and tonumber(response.StatusCode or response.Status)
        local decoded
        if status and status >= 200 and status < 300 then
            local parsed, data = pcall(HttpService.JSONDecode,HttpService,response.Body or "")
            if parsed and type(data) == "table" and data.ok == true and data.schemaVersion == 2 then decoded=data end
        end
        if decoded then
            Runtime.LastPayload,Runtime.LastError = captured.Body,nil
            lastHash,lastSuccess,pending,failures,nextSend = captured.Hash,os.clock(),nil,0,os.clock()+3
            for name in pairs(captured.Deaths) do Runtime.DeadBosses[name] = nil end
        else
            failures = math.min(failures+1,5)
            Runtime.LastError = "Notify rejected: " .. tostring(status or response)
            local retry = math.min(60,3*2^failures)
            if status == 400 or status == 401 or status == 403 then pending=nil; retry=60 end
            if status == 429 then
                local h = response.Headers or {}
                retry = math.clamp(tonumber(h["Retry-After"] or h["retry-after"]) or retry,3,60)
            end
            nextSend = os.clock()+retry
        end
    end
end)
