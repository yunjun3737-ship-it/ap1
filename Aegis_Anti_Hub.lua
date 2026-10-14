local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local State = {
    AntiGrab = false,
    AntiRagdoll = false,
    AntiExplosion = false,
    AntiBurn = false,
    AntiVoid = false,
    AntiPaint = false,
    AntiPoison = false,
    AntiSticky = false,
    AntiLag = false,
    AntiBanana = false,
    AntiSnowball = false,
    AutoAntiLag = false,
    RestorePosition = nil,
    Connections = {},
    PaintParts = {},
    PoisonParts = {},
    OriginalScriptStates = {},
}

local function disconnect(key)
    local c = State.Connections[key]
    if c then
        pcall(function() c:Disconnect() end)
        State.Connections[key] = nil
    end
end

local function character()
    return LocalPlayer.Character
end

local function humanoid()
    local c = character()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function root()
    local c = character()
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso"))
end

local function notify(text)
    pcall(function()
        Library:Notify({
            Title = "Aegis Anti Hub",
            Description = text,
            Time = 3
        })
    end)
end

local function getRemote(folderName, remoteName)
    local folder = ReplicatedStorage:FindFirstChild(folderName)
    return folder and folder:FindFirstChild(remoteName)
end

local function tryStruggle()
    local remote = getRemote("CharacterEvents", "Struggle")
    if remote and remote:IsA("RemoteEvent") then
        pcall(function()
            remote:FireServer(LocalPlayer)
        end)
    end
end

local function clearConnections()
    for key in pairs(State.Connections) do
        disconnect(key)
    end
end

local function setAntiGrab(enabled)
    State.AntiGrab = enabled
    disconnect("AntiGrab")
    if not enabled then return end

    State.Connections.AntiGrab = RunService.Heartbeat:Connect(function()
        if not State.AntiGrab then return end
        local c = character()
        local head = c and c:FindFirstChild("Head")
        local owner = head and head:FindFirstChild("PartOwner")
        local held = owner ~= nil
        if owner and owner:IsA("ObjectValue") then
            held = owner.Value ~= nil
        elseif owner and owner:IsA("BoolValue") then
            held = owner.Value
        end
        if held then
            tryStruggle()
        end
    end)
end

local function setAntiRagdoll(enabled)
    State.AntiRagdoll = enabled
    disconnect("AntiRagdoll")
    if not enabled then return end

    local function protect(c)
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if not h then return end
        pcall(function()
            h.AutoRotate = true
            h.PlatformStand = false
        end)
    end

    if character() then protect(character()) end
    State.Connections.AntiRagdoll = RunService.Heartbeat:Connect(function()
        if not State.AntiRagdoll then return end
        local c = character()
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then
            pcall(function()
                if h.PlatformStand then h.PlatformStand = false end
                if not h.AutoRotate then h.AutoRotate = true end
                if h.Sit and not h.SeatPart then h.Sit = false end
            end)
        end
    end)
end

local function setAntiExplosion(enabled)
    State.AntiExplosion = enabled
    disconnect("AntiExplosion")
    if not enabled then return end

    State.Connections.AntiExplosion = RunService.Heartbeat:Connect(function()
        if not State.AntiExplosion then return end
        local c = character()
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then
            local ragdolled = h:FindFirstChild("Ragdolled")
            if ragdolled and ragdolled:IsA("BoolValue") and ragdolled.Value then
                pcall(function()
                    local remote = getRemote("CharacterEvents", "RagdollRemote")
                    local r = root()
                    if remote and r then remote:FireServer(r, 0) end
                    h:ChangeState(Enum.HumanoidStateType.GettingUp)
                end)
            end
        end
    end)
end

local function setAntiBurn(enabled)
    State.AntiBurn = enabled
    disconnect("AntiBurn")
    local function clean(c)
        if not c then return end
        for _, obj in ipairs(c:GetDescendants()) do
            if obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                pcall(function() obj:Destroy() end)
            end
        end
    end
    if enabled then
        clean(character())
        State.Connections.AntiBurn = Workspace.DescendantAdded:Connect(function(obj)
            if State.AntiBurn and character() and obj:IsDescendantOf(character()) then
                if obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                    pcall(function() obj:Destroy() end)
                end
            end
        end)
    end
end

local function applyPartFilter(enabled, partName, stateKey)
    local saved = State[stateKey]
    if enabled then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name == partName then
                if saved[obj] == nil then saved[obj] = obj.CanTouch end
                pcall(function() obj.CanTouch = false end)
            end
        end
        disconnect(stateKey .. "Added")
        State.Connections[stateKey .. "Added"] = Workspace.DescendantAdded:Connect(function(obj)
            if not State[stateKey .. "Enabled"] then return end
            if obj:IsA("BasePart") and obj.Name == partName then
                if saved[obj] == nil then saved[obj] = obj.CanTouch end
                pcall(function() obj.CanTouch = false end)
            end
        end)
    else
        disconnect(stateKey .. "Added")
        for obj, original in pairs(saved) do
            if obj and obj.Parent then
                pcall(function() obj.CanTouch = original end)
            end
            saved[obj] = nil
        end
    end
end

State.PaintParts = {}
State.PoisonParts = {}
State.PaintPartsEnabled = false
State.PoisonPartsEnabled = false

local function setAntiPaint(enabled)
    State.AntiPaint = enabled
    State.AntiPaintEnabled = enabled
    applyPartFilter(enabled, "PaintPlayerPart", "PaintParts")
end

local function setAntiPoison(enabled)
    State.AntiPoison = enabled
    State.PoisonPartsEnabled = enabled
    applyPartFilter(enabled, "PoisonHurtPart", "PoisonParts")
    if enabled then
        end
end

local function setAntiSticky(enabled)
    State.AntiSticky = enabled
    disconnect("AntiSticky")
    if not enabled then return end

    local function removeStickyTouch(c)
        if not c then return end
        for _, obj in ipairs(c:GetDescendants()) do
            if obj:IsA("BasePart") then
                for _, connected in ipairs(obj:GetConnectedParts()) do
                    if connected.Name == "StickyPart" then
                        for _, child in ipairs(connected:GetChildren()) do
                            if child:IsA("TouchTransmitter") or child.Name == "TouchInterest" then
                                pcall(function() child:Destroy() end)
                            end
                        end
                    end
                end
            end
        end
    end

    State.Connections.AntiSticky = RunService.Heartbeat:Connect(function()
        if State.AntiSticky then removeStickyTouch(character()) end
    end)
end

local function setAntiVoid(enabled)
    State.AntiVoid = enabled
    disconnect("AntiVoid")
    if enabled then
        local r = root()
        if r then State.RestorePosition = r.CFrame end
        State.Connections.AntiVoid = RunService.Heartbeat:Connect(function()
            if not State.AntiVoid then return end
            local r = root()
            if not r then return end
            if r.Position.Y < -80 then
                pcall(function()
                    r.AssemblyLinearVelocity = Vector3.zero
                    r.CFrame = State.RestorePosition or CFrame.new(0, 20, 0)
                end)
            elseif r.Position.Y > -20 then
                State.RestorePosition = r.CFrame
            end
        end)
    end
end

local function setAntiLag(enabled)
    State.AntiLag = enabled
    local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
    if not scripts then return end
    for _, name in ipairs({"CharacterAndBeamMove", "StickyPartsTouchDetection"}) do
        local s = scripts:FindFirstChild(name)
        if s and s:IsA("LocalScript") then
            if State.OriginalScriptStates[s] == nil then
                State.OriginalScriptStates[s] = s.Enabled
            end
            pcall(function() s.Enabled = not enabled end)
        end
    end
    if not enabled then
        for s, wasEnabled in pairs(State.OriginalScriptStates) do
            if s and s.Parent then
                pcall(function() s.Enabled = wasEnabled end)
            end
            State.OriginalScriptStates[s] = nil
        end
    end
end

local function setAntiBanana(enabled)
    State.AntiBanana = enabled
    disconnect("AntiBanana")
    if not enabled then return end

    local function disableBananaTouch(obj)
        if not obj:IsA("BasePart") then return end
        local n = obj.Name:lower()
        if n:find("banana") or n:find("peel") then
            pcall(function() obj.CanTouch = false end)
        end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do disableBananaTouch(obj) end
    State.Connections.AntiBanana = Workspace.DescendantAdded:Connect(function(obj)
        if State.AntiBanana then disableBananaTouch(obj) end
    end)
end

local function setAntiSnowball(enabled)
    State.AntiSnowball = enabled
    disconnect("AntiSnowball")
    if not enabled then return end
    State.Connections.AntiSnowball = RunService.Heartbeat:Connect(function()
        if not State.AntiSnowball then return end
        local c = character()
        local h = c and c:FindFirstChildOfClass("Humanoid")
        local r = root()
        if h and r and h.Health > 0 then
            local weld = c:FindFirstChild("WeldHRP")
            if weld then
                pcall(function()
                    h.Sit = false
                    h.AutoRotate = true
                    h:ChangeState(Enum.HumanoidStateType.GettingUp)
                end)
                tryStruggle()
            end
        end
    end)
end

local function setAutoAntiLag(enabled)
    State.AutoAntiLag = enabled
    disconnect("AutoAntiLag")
    if not enabled then return end
    local lastCheck = 0
    State.Connections.AutoAntiLag = RunService.RenderStepped:Connect(function(dt)
        if not State.AutoAntiLag or os.clock() - lastCheck < 3 then return end
        lastCheck = os.clock()
        if dt > 0 and (1 / dt) < 25 and not State.AntiLag then
            setAntiLag(true)
            notify("낮은 FPS 감지: Anti Lag을 켰습니다.")
        end
    end)
end

local Window = Library:CreateWindow({
    Title = "Aegis Anti Hub",
    Footer = "Mobile / Obsidian",
    NotifySide = "Right",
    ShowCustomCursor = false,
})

local Tabs = {
    Defense = Window:AddTab("Defense", "shield"),
    Environment = Window:AddTab("Environment", "leaf"),
    Settings = Window:AddTab("Settings", "settings"),
}

local Core = Tabs.Defense:AddLeftGroupbox("Player Protection")
Core:AddToggle("AntiGrab", {
    Text = "Anti Grab",
    Default = false,
    Tooltip = "Attempts to trigger the game's struggle action when a grab is detected.",
    Callback = setAntiGrab,
})
Core:AddToggle("AntiRagdoll", {
    Text = "Anti Ragdoll",
    Default = false,
    Tooltip = "Attempts to restore local humanoid movement states.",
    Callback = setAntiRagdoll,
})
Core:AddToggle("AntiExplosion", {
    Text = "Anti Explosion / Ragdoll",
    Default = false,
    Tooltip = "Attempts to recover from a local ragdoll state.",
    Callback = setAntiExplosion,
})
Core:AddToggle("AntiVoid", {
    Text = "Anti Void",
    Default = false,
    Tooltip = "Returns your character to the last safe local position if it falls below the map.",
    Callback = setAntiVoid,
})
Core:AddToggle("AntiSnowball", {
    Text = "Anti Snowball",
    Default = false,
    Tooltip = "Attempts to recover when the character is attached by the game's snowball mechanic.",
    Callback = setAntiSnowball,
})

local Environment = Tabs.Environment:AddLeftGroupbox("Environment Protection")
Environment:AddToggle("AntiBurn", {
    Text = "Anti Burn Effects",
    Default = false,
    Tooltip = "Removes local Fire, Smoke and Sparkles effects attached to your character.",
    Callback = setAntiBurn,
})
Environment:AddToggle("AntiPaint", {
    Text = "Anti Paint",
    Default = false,
    Tooltip = "Disables touch on PaintPlayerPart objects on this client.",
    Callback = setAntiPaint,
})
Environment:AddToggle("AntiPoison", {
    Text = "Anti Poison",
    Default = false,
    Tooltip = "Disables touch on PoisonHurtPart objects on this client.",
    Callback = setAntiPoison,
})
Environment:AddToggle("AntiSticky", {
    Text = "Anti Sticky",
    Default = false,
    Tooltip = "Attempts to remove local touch transmitters from connected StickyParts.",
    Callback = setAntiSticky,
})
Environment:AddToggle("AntiBanana", {
    Text = "Anti Banana",
    Default = false,
    Tooltip = "Disables touch on parts whose names contain banana or peel, locally.",
    Callback = setAntiBanana,
})
Environment:AddToggle("AntiLag", {
    Text = "Anti Lag",
    Default = false,
    Tooltip = "Disables selected game LocalScripts on this client. Restore them when switched off.",
    Callback = setAntiLag,
})
Environment:AddToggle("AutoAntiLag", {
    Text = "Auto Anti Lag",
    Default = false,
    Tooltip = "Enables Anti Lag when a low-FPS frame is detected.",
    Callback = setAutoAntiLag,
})

local Info = Tabs.Settings:AddLeftGroupbox("Configuration")
Info:AddButton({
    Text = "Restore Local Scripts",
    Func = function()
        setAntiLag(false)
        notify("원래 저장된 LocalScript 상태를 복원했습니다.")
    end,
})
Info:AddButton({
    Text = "Stop All Protection Loops",
    Func = function()
        for _, fn in ipairs({
            function() setAntiGrab(false) end,
            function() setAntiRagdoll(false) end,
            function() setAntiExplosion(false) end,
            function() setAntiBurn(false) end,
            function() setAntiVoid(false) end,
            function() setAntiPaint(false) end,
            function() setAntiPoison(false) end,
            function() setAntiSticky(false) end,
            function() setAntiBanana(false) end,
            function() setAntiSnowball(false) end,
            function() setAutoAntiLag(false) end,
            function() setAntiLag(false) end,
        }) do
            pcall(fn)
        end
        notify("보호 루프를 종료했습니다.")
    end,
})

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetFolder("AegisAntiHub")
ThemeManager:SetFolder("AegisAntiHub")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if State.AntiGrab then setAntiGrab(true) end
    if State.AntiRagdoll then setAntiRagdoll(true) end
    if State.AntiExplosion then setAntiExplosion(true) end
    if State.AntiBurn then setAntiBurn(true) end
    if State.AntiVoid then setAntiVoid(true) end
    if State.AntiSticky then setAntiSticky(true) end
    if State.AntiSnowball then setAntiSnowball(true) end
end)

Library:Notify({
    Title = "Aegis Anti Hub",
    Description = "Loaded. Configs and themes are available in Settings.",
    Time = 5,
})
