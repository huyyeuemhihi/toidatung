repeat
    task.wait()
until game:IsLoaded()
    and game.Players.LocalPlayer
    and game.Players.LocalPlayer:FindFirstChild("DataLoaded")

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local Player = Players.LocalPlayer
local CommF = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
local WorkerURL = "https://nf.quachlehuyy.workers.dev/notify"

local RareBosses = {
    "rip_indra True Form",
    "Dough King",
    "Soul Reaper",
    "Darkbeard",
    "Cursed Captain"
}

local LastState = {}
local ActiveMoon
local ActiveHaki
local ActiveBerries = {}

local function SendNotify(data)
    task.spawn(function()
        pcall(function()
            request({
                Url = WorkerURL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(data)
            })
        end)
    end)
end

local function SendEvent(eventType, active, extra)
    local clock = math.floor(Lighting.ClockTime)

    local data = {
        JobId = game.JobId,
        PlaceId = game.PlaceId,
        Player = Player.Name,
        Players = Players.NumPlayers .. "/" .. Players.MaxPlayers,
        ClockTime = clock,
        IsNight = clock >= 18 or clock < 5,
        Type = eventType,
        Active = active
    }

    if extra then
        for k, v in pairs(extra) do
            data[k] = v
        end
    end

    SendNotify(data)
end

local function UpdateState(key, active, eventType, extra)
    if LastState[key] == nil then
        LastState[key] = active

        if active then
            SendEvent(eventType, true, extra)
        end

        return
    end

    if LastState[key] ~= active then
        LastState[key] = active
        SendEvent(eventType, active, extra)
    end
end

local function GetMoonPhase()
    local phase = Lighting:GetAttribute("MoonPhase")
    local clock = math.floor(Lighting.ClockTime)
    if phase == 5 and (clock >= 12 or clock < 5) then
        return "Full Moon"
    end
    if phase == 4 then
        return "Next Night"
    end
    return nil
end

local function UpdateMoon()
    local moon = GetMoonPhase()

    if not moon then
        if ActiveMoon then
            SendEvent("Moon", false, {
                MoonPhase = ActiveMoon
            })

            ActiveMoon = nil
        end

        return
    end

    if not ActiveMoon then
        ActiveMoon = moon

        SendEvent("Moon", true, {
            MoonPhase = moon
        })

        return
    end

    if ActiveMoon ~= moon then
        SendEvent("Moon", false, {
            MoonPhase = ActiveMoon
        })

        ActiveMoon = moon

        SendEvent("Moon", true, {
            MoonPhase = moon
        })
    end
end

local function GetMirage()
    return Workspace.Map:FindFirstChild("MysticIsland") ~= nil
end

local function HasCastle()
    local origin = Vector3.new(-5000, 350, -3035)

    for _, folder in ipairs({
        Workspace.Enemies,
        ReplicatedStorage
    }) do
        for _, v in ipairs(folder:GetChildren()) do
            if v:IsA("Model")
                and v.Name ~= "Blank Buddy"
                and (v:GetPivot().Position - origin).Magnitude <= 3000 then

                return true
            end
        end
    end

    return false
end

local function HasPrehistoric()
    return Workspace.Map:FindFirstChild("PrehistoricIsland") ~= nil
end

local function HasRareBoss(name)
    for _, folder in ipairs({
        ReplicatedStorage,
        Workspace.Enemies
    }) do
        for _, v in ipairs(folder:GetChildren()) do
            if v.Name:find(name, 1, true) then
                return true
            end
        end
    end

    return false
end

local function GetBerry()
    for _, bush in ipairs(
        CollectionService:GetTagged("BerryBush")
    ) do
        for _, berryName in pairs(
            bush:GetAttributes()
        ) do
            if (
                not BerryArray
                or table.find(BerryArray, berryName)
            ) and (
                berryName == "Red Cherry Berry"
                or berryName == "White Cloud Berry"
                or berryName == "Pink Pig Berry"
            ) then
                return berryName
            end
        end
    end
end

task.spawn(function()
    while task.wait(1) do
        pcall(function()


            local haki = CommF:InvokeServer(
                "ColorsDealer",
                "1"
            )

            if haki ~= ActiveHaki then

                if ActiveHaki then
                    SendEvent("Legendary", false, {
                        Haki = ActiveHaki
                    })
                end

                ActiveHaki = haki
                if ActiveHaki then
                    SendEvent("Legendary", true, {
                        Haki = ActiveHaki
                    })
                end
            end


            for _, boss in ipairs(RareBosses) do
                UpdateState(
                    "Boss:" .. boss,
                    HasRareBoss(boss),
                    "Rare Boss",
                    {
                        ["Rare Boss"] = boss
                    }
                )
            end


            UpdateState(
                "Prehistoric",
                HasPrehistoric(),
                "Island",
                {
                    ["Prehistoric Island"] = true
                }
            )

            if SeaIndex == 3 then
                UpdateState(
                    "Mirage",
                    GetMirage(),
                    "Mirage",
                    {
                        Mirage = true
                    }
                )
            end

            UpdateMoon()


            if SeaIndex == 3 then
                local berry = GetBerry()

                if berry then
                    -- Berry mới
                    if not ActiveBerries[berry] then
                        ActiveBerries[berry] = true

                        SendEvent("Berry", true, {
                            Berry = berry
                        })
                    end
                end

                for oldBerry in pairs(ActiveBerries) do
                    if oldBerry ~= berry then
                        ActiveBerries[oldBerry] = nil

                        SendEvent("Berry", false, {
                            Berry = oldBerry
                        })
                    end
                end

                UpdateState(
                    "Castle",
                    HasCastle(),
                    "Castle"
                )
            end
        end)
    end
end)
