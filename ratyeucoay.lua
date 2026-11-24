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
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CommF = Remotes:WaitForChild("CommF_")
-- Worker URL của bạn
local WorkerURL = "https://nf.quachlehuyy.workers.dev/notify"
-- Xác định Sea hiện tại
local SeaIndex = ({
    [2753915549] = 1,
    [85211729168715] = 1,
    [4442272183] = 2,
    [79091703265657] = 2,
    [7449423635] = 3,
    [100117331123089] = 3,
})[game.PlaceId] or 0
-- Danh sách Rare Boss
local RareBosses = {
    "rip_indra True Form",
    "Dough King",
    "Cake Prince",
    "Soul Reaper",
    "Darkbeard",
    "Cursed Captain",
    "Tyrant of the Skies"
}
local LastState = {}
local LastMoonPhase = nil
local LastHaki = nil
-- Hàm gửi HTTP Request an toàn
local function SendNotify(data)
    task.spawn(function()
        pcall(function()
            local requestFunc = syn and syn.request or http_request or request or HttpPost
            if requestFunc then
                requestFunc({
                    Url = WorkerURL,
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json"
                    },
                    Body = HttpService:JSONEncode(data)
                })
            end
        end)
    end)
end
-- Hàm đóng gói payload dữ liệu
local function SendEvent(eventType, active, extra)
    local clock = math.floor(Lighting.ClockTime)
    local data = {
        JobId = game.JobId,
        PlaceId = game.PlaceId,
        Player = Player.Name,
        Players = Players.NumPlayers .. "/" .. Players.MaxPlayers,
        ClockTime = clock,
        IsNight = (clock >= 18 or clock < 5),
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
-- Hàm cập nhật trạng thái sự kiện
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
-- ==========================================================================
-- CÁC HÀM QUÉT KIỂM TRA SỰ KIỆN TRONG GAME
-- ==========================================================================
-- 1. Kiểm tra Trăng (Full Moon & Next Night)
local function GetFullMoon()
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
    local moon = GetFullMoon()
    if not moon then
        if LastMoonPhase then
            SendEvent("Moon", false, { MoonPhase = LastMoonPhase })
            LastMoonPhase = nil
        end
        return
    end
    if not LastMoonPhase then
        LastMoonPhase = moon
        SendEvent("Moon", true, { MoonPhase = moon })
        return
    end
    if LastMoonPhase ~= moon then
        SendEvent("Moon", false, { MoonPhase = LastMoonPhase })
        LastMoonPhase = moon
        SendEvent("Moon", true, { MoonPhase = moon })
    end
end
-- 2. Kiểm tra Đảo Mirage
local function GetMirage()
    return Workspace.Map:FindFirstChild("MysticIsland") ~= nil
end
-- 3. Kiểm tra Đảo Prehistoric
local function HasPrehistoric()
    return Workspace.Map:FindFirstChild("PrehistoricIsland") ~= nil
end
-- 4. Kiểm tra Castle Raid
local function HasCastle()
    local origin = Vector3.new(-5000, 350, -3035)
    for _, folder in ipairs({
        Workspace:FindFirstChild("Enemies"),
        ReplicatedStorage
    }) do
        if folder then
            for _, v in ipairs(folder:GetChildren()) do
                if v:IsA("Model")
                    and v.Name ~= "Blank Buddy"
                    and (v:GetPivot().Position - origin).Magnitude <= 3000 then
                    return true
                end
            end
        end
    end
    return false
end
-- 5. Kiểm tra Rare Boss
local function HasRareBoss(name)
    for _, folder in ipairs({
        ReplicatedStorage,
        Workspace:FindFirstChild("Enemies"),
        Workspace:FindFirstChild("_WorldOrigin") and Workspace._WorldOrigin:FindFirstChild("EnemySpawns")
    }) do
        if folder then
            for _, v in ipairs(folder:GetChildren()) do
                if v.Name:find(name, 1, true) then
                    return true
                end
            end
        end
    end
    return false
end
-- 6. Quét TẤT CẢ các loại Berry đang có trên đảo
local function GetAllBerries()
    local foundBerries = {}
    for _, bush in ipairs(CollectionService:GetTagged("BerryBush")) do
        for _, berryName in pairs(bush:GetAttributes()) do
            local bStr = tostring(berryName)
            if bStr:find("Berry") and not table.find(foundBerries, bStr) then
                table.insert(foundBerries, bStr)
            end
        end
    end
    return foundBerries
end
-- ==========================================================================
-- VÒNG LẶP CHÍNH (QUÉT MỖI 1 GIÂY)
-- ==========================================================================
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            --------------------------------------------------
            -- A. HAKI (COLORS DEALER) - SEA 2 & SEA 3
            --------------------------------------------------
            if SeaIndex == 2 or SeaIndex == 3 then
                local haki = CommF:InvokeServer("ColorsDealer", "1")
                if haki ~= LastHaki then
                    if LastHaki then
                        SendEvent("Legendary", false, { Haki = LastHaki })
                    end
                    LastHaki = haki
                    if LastHaki then
                        SendEvent("Legendary", true, { Haki = LastHaki })
                    end
                end
            end
            --------------------------------------------------
            -- B. RARE BOSS - SEA 2 & SEA 3
            --------------------------------------------------
            if SeaIndex == 2 or SeaIndex == 3 then
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
            end
            --------------------------------------------------
            -- C. PREHISTORIC ISLAND - SEA 3
            --------------------------------------------------
            if SeaIndex == 3 then
                UpdateState(
                    "Prehistoric",
                    HasPrehistoric(),
                    "Island",
                    {
                        ["Prehistoric Island"] = true
                    }
                )
            end
            --------------------------------------------------
            -- D. MOON, MIRAGE, CASTLE - SEA 3
            --------------------------------------------------
            if SeaIndex == 3 then
                UpdateMoon()
                UpdateState(
                    "Mirage",
                    GetMirage(),
                    "Mirage",
                    {
                        Mirage = true
                    }
                )
                UpdateState(
                    "Castle",
                    HasCastle(),
                    "Castle"
                )
            end
            --------------------------------------------------
            -- E. TẤT CẢ CÁC LOẠI BERRY - MỌI SEA
            --------------------------------------------------
            local currentBerries = GetAllBerries()
            -- Gửi thông báo cho từng loại Berry tìm thấy
            for _, bName in ipairs(currentBerries) do
                local stateKey = "Berry:" .. bName
                if not LastState[stateKey] then
                    LastState[stateKey] = true
                    SendEvent("Berry", true, {
                        Berry = bName
                    })
                end
            end
            -- Hủy thông báo khi loại Berry đó đã bị nhặt mất
            for key, state in pairs(LastState) do
                if state and key:sub(1, 6) == "Berry:" then
                    local oldBName = key:sub(7)
                    if not table.find(currentBerries, oldBName) then
                        LastState[key] = nil
                        SendEvent("Berry", false, {
                            Berry = oldBName
                        })
                    end
                end
            end
        end)
    end
end)
