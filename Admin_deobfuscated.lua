-- v43.9

if getgenv().DShubScript then
    warn("DShub가 이미 실행중입니다.")
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "DShub",
            Text = "이미 스크립트가 실행중입니다.",
            Duration = 5
        })
    end)
    return
end
getgenv().DShubScript = true

do
    local env = getgenv()
    local reg = {
        conns = {}, threads = setmetatable({}, {__mode = "k"}), insts = {},
        ffo = {}, core = {}, lightKids = {}, resetOff = false,
    }
    env.__DSR = reg

    local function isConnected(v) return v.Connected end
    local function parentOf(v) return v.Parent end
    local connLimit, instLimit = 800, 3000
    local guiChild = {
        Frame = true, TextLabel = true, TextButton = true, TextBox = true, ImageLabel = true,
        ScrollingFrame = true, CanvasGroup = true, UICorner = true, UIStroke = true,
        UIScale = true, UIGradient = true, UIPadding = true, UIListLayout = true,
    }

    env.__DST = function(c)
        if c ~= nil then
            local t = reg.conns
            t[#t + 1] = c
            if #t > connLimit then
                local keep = {}
                for i = 1, #t do
                    local v = t[i]
                    local ok, alive = pcall(isConnected, v)
                    if not ok or alive ~= false then keep[#keep + 1] = v end
                end
                reg.conns = keep
                connLimit = math.max(800, #keep * 2)
            end
        end
        return c
    end

    env.__DSTH = function(th)
        if th ~= nil then reg.threads[th] = true end
        return th
    end

    env.__DSN = function(...)
        local o = Instance.new(...)
        if guiChild[(...)] then return o end
        local t = reg.insts
        t[#t + 1] = o
        if #t > instLimit then
            local keep = {}
            for i = 1, #t do
                local v = t[i]
                local ok, parent = pcall(parentOf, v)
                if ok and parent ~= nil then keep[#keep + 1] = v end
            end
            reg.insts = keep
            instLimit = math.max(3000, #keep * 2)
        end
        return o
    end

    env.__DSFF = function(name, value)
        if reg.ffo[name] == nil then
            local ok, cur = pcall(function() return getfflag(name) end)
            reg.ffo[name] = (ok and cur ~= nil and cur ~= "") and tostring(cur) or false
        end
        return setfflag(name, value)
    end

    local lpl = game:GetService("Players").LocalPlayer
    local StarterGuiS = game:GetService("StarterGui")
    local LightingS = game:GetService("Lighting")

    reg.ws = {Gravity = workspace.Gravity, Fallen = workspace.FallenPartsDestroyHeight}

    for _, t in ipairs(Enum.CoreGuiType:GetEnumItems()) do
        if t ~= Enum.CoreGuiType.All then
            pcall(function() reg.core[t] = StarterGuiS:GetCoreGuiEnabled(t) end)
        end
    end

    reg.light = {}
    for _, k in ipairs({"Brightness", "ClockTime", "FogEnd", "FogStart", "FogColor", "GlobalShadows",
        "OutdoorAmbient", "Ambient", "ExposureCompensation"}) do
        pcall(function() reg.light[k] = LightingS[k] end)
    end
    for _, child in ipairs(LightingS:GetChildren()) do
        pcall(function()
            local copy = child:Clone()
            if copy then reg.lightKids[#reg.lightKids + 1] = {orig = child, copy = copy} end
        end)
    end

    local function snapHumanoid()
        local ch = lpl.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if not hum then return false end
        reg.hum = {}
        for _, k in ipairs({"UseJumpPower", "WalkSpeed", "JumpPower", "RequiresNeck", "BreakJointsOnDeath", "AutoRotate"}) do
            pcall(function() reg.hum[#reg.hum + 1] = {k, hum[k]} end)
        end
        return true
    end
    if not snapHumanoid() then
        task.spawn(function()
            local t0 = tick()
            while not reg.hum and tick() - t0 < 10 and not reg.torn do
                if snapHumanoid() then break end
                task.wait(0.25)
            end
        end)
    end

    env.__DSTD = function()
        reg.torn = true
        local RS = game:GetService("RunService")
        local cur = coroutine.running()

        for name, orig in pairs(reg.ffo) do
            if orig then pcall(setfflag, name, orig) end
        end

        for i = #reg.conns, 1, -1 do
            local c = reg.conns[i]
            pcall(function() c:Disconnect() end)
        end
        reg.conns = {}

        for th in pairs(reg.threads) do
            if th ~= cur then pcall(task.cancel, th) end
        end

        for _, n in ipairs({"ClientVision", "BangClientVision", "OrbitClientVision", "GetBangClientVision",
            "GetSuckClientVision", "BringClientVision", "LoopGotoClientVision", "PerfectDesyncRender",
            "Freecam", "DestroyAllToysClient"}) do
            pcall(function() RS:UnbindFromRenderStep(n) end)
        end
        pcall(function()
            local cas = game:GetService("ContextActionService")
            cas:UnbindAction("FreecamKeyboard")
            cas:UnbindAction("FreecamMousePan")
        end)

        for i = #reg.insts, 1, -1 do
            local o = reg.insts[i]
            pcall(function() o:Destroy() end)
        end
        reg.insts = {}

        local users = env._CmdScriptUsers
        if users then users[lpl.UserId] = nil end
        env._OwnerHandleRankCommand = nil
        env._OwnerListenerActive = false
        env.DShubScript = false

        pcall(function()
            workspace.Gravity = reg.ws.Gravity
            workspace.FallenPartsDestroyHeight = reg.ws.Fallen
        end)
        for k, v in pairs(reg.light) do
            pcall(function() LightingS[k] = v end)
        end
        for _, rec in ipairs(reg.lightKids) do
            if not rec.orig.Parent then pcall(function() rec.copy.Parent = LightingS end) end
        end
        for t, en in pairs(reg.core) do
            pcall(function() StarterGuiS:SetCoreGuiEnabled(t, en) end)
        end
        if reg.resetOff then
            pcall(function() StarterGuiS:SetCore("ResetButtonCallback", true) end)
        end
        if reg.hum then
            local hum = lpl.Character and lpl.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                for _, kv in ipairs(reg.hum) do
                    pcall(function() hum[kv[1]] = kv[2] end)
                end
            end
        end
    end
end

do
    local _allowedUsers = {
        [9902765941] = true, -- mirimirimirihyuk 도시
        [3168025083] = true, -- saleexpense177 도시 부계
        [10911026588] = true, -- mirimirimirihyuk1 도시 부계
        [9077969715] = true, -- FlyReflect9 도시 부계
        [1895306192] = true, -- hoyalim2012 지티
        [9424459134] = true, -- o1oio1oio1oio1oi 지티 부계
        [8050500137] = true, -- DGTPC10040 지티 부계
        [11624295209] = true, -- ftap_dh 지티 부계
        [10715326994] = true, -- DGT_ADOPTME 지티 부계
        [2609742251] = true, -- jaeyoon4720 비모
        [8729927637] = true, -- jaeyoon4740 비모 부계
        [3762591388] = true, -- AUCTIONSYYYYY 팔분이
    }
    local _lp = game:GetService("Players").LocalPlayer
    if not _allowedUsers[_lp.UserId] then
        pcall(function()
            local _src = game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/non-allowed')
            if _src and _src ~= "" then
                local _fn = loadstring(_src)
                if _fn then _fn() end
            end
        end)
        pcall(function()
            _lp:Kick("허용된 사용자가 아닙니다.")
        end)
        return
    end
end

local Players, TeleportService, StarterGui, RunService, MarketplaceService,
        Lighting, UserInputService, TweenService, HttpService, ReplicatedStorage,
        TextChatService, VirtualUser, Workspace, Stats, CoreGui =
    game:GetService("Players"),
    game:GetService("TeleportService"),
    game:GetService("StarterGui"),
    game:GetService("RunService"),
    game:GetService("MarketplaceService"),
    game:GetService("Lighting"),
    game:GetService("UserInputService"),
    game:GetService("TweenService"),
    game:GetService("HttpService"),
    game:GetService("ReplicatedStorage"),
    game:GetService("TextChatService"),
    game:GetService("VirtualUser"),
    game:GetService("Workspace"),
    game:GetService("Stats"),
    game:GetService("CoreGui")
local Terrain, lp = Workspace:FindFirstChildOfClass("Terrain"), Players.LocalPlayer

local defaultCameraMode, defaultMinZoom, defaultMaxZoom, defaultFOV, chatConnection, mainInputConnection,
        startTime, serverInfoGui, _scriptTerminated, COMMAND_PREFIX =
    lp.CameraMode,
    lp.CameraMinZoomDistance,
    lp.CameraMaxZoomDistance,
    workspace.CurrentCamera.FieldOfView,
    nil,
    nil,
    tick(),
    nil,
    false,
    "."
do
    local ok, saved = pcall(function()
        return readfile("DShub prefix.txt")
    end)
    if ok and saved and saved ~= "" then
        COMMAND_PREFIX = saved
    end
end

local VALID_COMMANDS_SET = {}

local SCRIPT_MARKER_NAME = "CmdScriptMarker"
local function applyScriptMarker(char)
    if not char then return end
    if not char:FindFirstChild(SCRIPT_MARKER_NAME) then
        local marker = getgenv().__DSN("BoolValue")
        marker.Name = SCRIPT_MARKER_NAME
        marker.Value = true
        marker.Parent = char
    end
end
getgenv().__DSTH(task.spawn(function()
    local char = lp.Character or lp.CharacterAdded:Wait()
    applyScriptMarker(char)
    getgenv().__DST(lp.CharacterAdded:Connect(function(newChar)
        applyScriptMarker(newChar)
    end))
end))

if not getgenv()._CmdScriptUsers then
    getgenv()._CmdScriptUsers = {}
end
getgenv()._CmdScriptUsers[lp.UserId] = true
getgenv().__DST(Players.PlayerRemoving:Connect(function(p)
    if getgenv()._CmdScriptUsers then
        getgenv()._CmdScriptUsers[p.UserId] = nil
    end
end))

local S = {
    customSpawnCFrame = nil, spawnConnection = nil,
    fullbrightLoop = nil, savedLightingSettings = {},
    fpsBoostEnabled = false, fpsBoostConnection = nil,
    originalLightingState = {}, cachedParts = {},
    shaderEnabled = false, shaderDescConn = nil,
    originalShaderState = {},
}
local M = {
    walkflingEnabled = false, noclipConnection = nil,
    spinEnabled = false, spinSpeed = 10, spinConnection = nil,
    spinGrabEnabled = false, spinGrabSpeed = 20, spinGrabConnection = nil,
    spinGrabWatcher = nil, spinGrabCurrentPart = nil,
    flyConnection = nil, currentFlyType = nil, flySpeed = 50,
    flyObjects = {}, lastFlyTargetPart = nil,
    vflyCurrentVelocity = Vector3.new(0, 0, 0), vflyAccelRate = 7, vflyDecelRate = 8,
    vflyCurrentGyroCFrame = nil, vflyRotationRate = 12,
    vflyCurrentTilt = 0, vflyCurrentRoll = 0, vflyTiltMax = math.rad(15), vflyTiltStrength = 0.35, vflyTiltSmoothRate = 10,
    suppressFlyStartNotify = false,
    vflyVehicles = {}, currentVFlyVehicle = nil,
    vflyToggleEnabled = false, vflyToggleActive = false, vflyToggleSpeed = nil,
    vflyKeyState = {W = false, A = false, S = false, D = false}, vflyInputConn = nil, vflyInputEndConn = nil,
    infJumpConnection = nil, previousJumpPower = nil,
    loopSpeedConnection = nil, loopJumpConnection = nil,
    targetWalkSpeed = 16, targetJumpPower = 50,
    tpwalkEnabled = false, tpwalkStep = 1, tpwalkConnection = nil,
    voidTpEnabled = false, voidTpOriginalPosition = nil,
    loopTpEnabled = false, loopTpOriginalPosition = nil,
    walkToEnabled = false, walkToTarget = nil, walkToLoop = nil,
    thirdpConnection = nil,
    bangAnimation = nil, bangAnimTrack = nil, bangDiedConnection = nil, bangLoopConnection = nil,
    bangTargetDiedConn = nil, bangTargetRespawnConn = nil, bangTargetLeaveConn = nil, bangTarget = nil, bangOffset = nil,
    getSuckEnabled = false, getSuckConnection = nil, getSuckAnimTrack = nil, getSuckTarget = nil,
    getSuckTargetDiedConn = nil, getSuckTargetRespawnConn = nil, getSuckTargetLeaveConn = nil,
    getBangEnabled = false, getBangLoop = nil, getBangAnimTrack = nil, getBangTarget = nil,
    getBangTargetDiedConn = nil, getBangTargetRespawnConn = nil, getBangTargetLeaveConn = nil,
    xrayEnabled = false, xrayLevel = 0.5, xrayDefaultLevel = 0.5, xrayLoopConnection = nil,
    orbitConnection1 = nil, orbitConnection2 = nil, orbitConnection3 = nil,
    orbitEnabled = false, orbitTarget = nil, orbitSpeed = 0.2, orbitDistance = 6,
    orbitTargetDiedConn = nil, orbitTargetRespawnConn = nil, orbitTargetLeaveConn = nil,
    invisEnabled = false, invisLoopConnection = nil, invisCamConnection = nil,
    bangFakeIsFaking = false, bangFakeOCF = nil, bangFakeHBC = nil,
    orbitFakeIsFaking = false, orbitFakeOCF = nil, orbitFakeHBC = nil,
    getBangFakeIsFaking = false, getBangFakeOCF = nil, getBangFakeHBC = nil,
    getSuckFakeIsFaking = false, getSuckFakeOCF = nil, getSuckFakeHBC = nil,
    bringFakeIsFaking = false, bringFakeOCF = nil, bringFakeHBC = nil,
    loopGotoFakeIsFaking = false, loopGotoFakeOCF = nil, loopGotoFakeHBC = nil,
    jerkEnabled = false, jerkPlaying = false, jerkAnimTrack = nil, jerkInputConn = nil,
    headSitConnection = nil, headSitTargetLeaveConn = nil,
    headSitTarget = nil, headSitRespawnConn = nil, headSitDiedConn = nil,
}
local A = {
    antiAfkEnabled = false, antiAfkConnection = nil, antiAfkLoop = nil,
    antiLagEnabled = false, antiLagLoop = nil,
    charAntiLagEnabled = false,
    AUTO_ANTILAG_PLACE_ID = 6961824067, autoAntiLagLoop = nil,
    antiInPlotsEnabled = false,
}
local E = {
    iconEspEnabled = false, iconEspConnection = nil, iconEspMaxDist = 5000,
    iconEspObjects = {}, iconEspCharConns = {}, iconEspGui = nil, iconEspRemovingConn = nil,
    nameEspEnabled = false, nameEspConnection = nil, nameEspMaxDist = 5000,
    nameEspObjects = {}, nameEspCharConns = {}, nameEspGui = nil, nameEspRemovingConn = nil,
    stickyPartEspEnabled = false, stickyPartEspConnection = nil,
}
local L = {
    loopKillConnections = {}, loopKillPlotWatchers = {}, loopKillCharConns = {}, loopKillAllMode = false, loopKillAllWatcher = nil,
    autoResetEnabled = false, autoResetPending = false, autoResetForced = false,
    autoResetDiedConnection = nil, autoResetCharConnection = nil,
    loopresetEnabled = false, loopresetCharConnection = nil, loopresetDiedConnection = nil,
    loopKillEnabled = false, loopKillTargets = {}, currentProcessing = {},
    loopGotoEnabled = false, loopGotoTarget = nil, loopGotoConnection = nil,
    lpBringEnabled = false, lpBringTargets = {}, lpBringLoop = nil, lpBringDeathConns = {},
    lpwdTargets = {}, lpwdEnabled = false, lpwdLoop = nil, lpwdLeaveConns = {},
    autoWarningResetEnabled = false, autoWarningResetConnection = nil,
    autoWarningResetCount = 0, autoWarningResetDiedConn = nil, autoWarningResetCharConn = nil,
    lpPendikSessions = {}, lpPendikSpawnMutex = false, lpPendikKnownToys = {},
    lpPendikCleanupRunning = false,
    flingEnabled = false, flingTarget = nil, flingConnection = nil,
    flingDice = nil, flingOwnerConfirmed = false, flingLossTimer = 0,
    flingLastSpawn = 0, flingPlayerRemovingConn = nil,
}
local F = {
    friendListGui = nil, friendListContent = nil,
    friendListTitle = nil, friendListLayout = nil,
    blackListGui = nil, blackListContent = nil, blackListLayout = nil,
    friendCache = {}, cmdFocused = false,
    viewingPlayer = nil, viewConnection = nil,
    viewLeaveConnection = nil, viewUpdateConnection = nil,
}
local T = {
    targetPlayer = nil,
    targetGui = nil,
    targetUpdateLoop = nil,
    targetLeaveConn = nil,
}
local Z = {
    isFaking = false, hbc = nil, ocf = nil, tpPrediction = 0.05,
    kickAllEnabled = false, kickAllLoopConn = nil, kickAllLogicConn = nil,
    _lastHandledMsg = "", _lastHandledTime = 0,
    initialLoadDone = false, joiningPlayers = {}, bringAllSlots = {}, _hookedBoxes = {},
    StartFreecam = nil, StopFreecam = nil,
}

local http_request, BL_FILE, blackList =
    (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request,
    "DShub BlackList.txt",
    {}

local function loadBlackList()
    pcall(function()
        if isfile and isfile(BL_FILE) then
            local content = readfile(BL_FILE)
            blackList = {}
            for name in content:gmatch("[^\r\n]+") do
                local trimmed = name:match("^%s*(.-)%s*$")
                if trimmed ~= "" then
                    blackList[trimmed:lower()] = trimmed
                end
            end
        end
    end)
end

local function saveBlackList()
    pcall(function()
        if writefile then
            local lines = {}
            for _, name in pairs(blackList) do
                table.insert(lines, name)
            end
            table.sort(lines)
            writefile(BL_FILE, table.concat(lines, "\n"))
        end
    end)
end

loadBlackList()

local blGuiName, blScreenGui, blContainer, blLayoutCount = "DSHubBlackListNotify", nil, nil, 0

local function initBLGui()
    if blScreenGui and blScreenGui.Parent then return end
    blScreenGui = getgenv().__DSN("ScreenGui")
    blScreenGui.Name = blGuiName
    blScreenGui.ResetOnSpawn = false
    blScreenGui.DisplayOrder = 999999998
    if syn and syn.protect_gui then
        syn.protect_gui(blScreenGui)
        blScreenGui.Parent = game:GetService("CoreGui")
    elseif gethui then
        blScreenGui.Parent = gethui()
    else
        blScreenGui.Parent = game:GetService("CoreGui")
    end

    blContainer = getgenv().__DSN("Frame")
    blContainer.Name = "BLNotifyContainer"
    blContainer.Size = UDim2.new(0, 320, 0.5, 0)
    blContainer.Position = UDim2.new(1, -340, 0.5, 0)
    blContainer.AnchorPoint = Vector2.new(0, 0)
    blContainer.BackgroundTransparency = 1
    blContainer.Parent = blScreenGui

    local uiList = getgenv().__DSN("UIListLayout")
    uiList.Parent = blContainer
    uiList.SortOrder = Enum.SortOrder.LayoutOrder
    uiList.VerticalAlignment = Enum.VerticalAlignment.Top
    uiList.Padding = UDim.new(0, 10)

end

local function showBLNotify(displayName, isAlreadyIn)
    initBLGui()
    blLayoutCount = blLayoutCount - 1

    local TweenService, msg = game:GetService("TweenService"), isAlreadyIn
        and ("블랙리스트 " .. displayName .. "가 서버에 있습니다.")
        or  ("블랙리스트 " .. displayName .. "가 접속했습니다.")

    local frame = getgenv().__DSN("Frame")
    frame.Size = UDim2.new(1, 0, 0, 65)
    frame.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.LayoutOrder = blLayoutCount
    frame.Parent = blContainer

    local frameCorner = getgenv().__DSN("UICorner")
    frameCorner.CornerRadius = UDim.new(0, 6)
    frameCorner.Parent = frame

    local uiStroke = getgenv().__DSN("UIStroke")
    uiStroke.Color = Color3.fromRGB(200, 50, 50)
    uiStroke.Thickness = 1.5
    uiStroke.Transparency = 1
    uiStroke.Parent = frame

    local titleLabel = getgenv().__DSN("TextLabel")
    titleLabel.Size = UDim2.new(1, -20, 0, 22)
    titleLabel.Position = UDim2.new(0, 12, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "[ BlackList 감지 ]"
    titleLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    titleLabel.TextTransparency = 1
    titleLabel.TextStrokeTransparency = 1
    titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    titleLabel.TextSize = 16
    titleLabel.Font = Enum.Font.GothamBlack
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = frame

    local contentLabel = getgenv().__DSN("TextLabel")
    contentLabel.Size = UDim2.new(1, -20, 0, 22)
    contentLabel.Position = UDim2.new(0, 12, 0, 32)
    contentLabel.BackgroundTransparency = 1
    contentLabel.Text = msg
    contentLabel.TextColor3 = Color3.fromRGB(255, 200, 200)
    contentLabel.TextTransparency = 1
    contentLabel.TextStrokeTransparency = 1
    contentLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    contentLabel.TextSize = 15
    contentLabel.Font = Enum.Font.GothamBold
    contentLabel.TextXAlignment = Enum.TextXAlignment.Left
    contentLabel.TextWrapped = true
    contentLabel.Parent = frame

    local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(frame, tweenInfo, {BackgroundTransparency = 0.1}):Play()
    TweenService:Create(uiStroke, tweenInfo, {Transparency = 0}):Play()
    TweenService:Create(titleLabel, tweenInfo, {TextTransparency = 0, TextStrokeTransparency = 0.4}):Play()
    TweenService:Create(contentLabel, tweenInfo, {TextTransparency = 0, TextStrokeTransparency = 0.4}):Play()

    getgenv().__DSTH(task.delay(8, function()
        local fadeOut = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        TweenService:Create(frame, fadeOut, {BackgroundTransparency = 1}):Play()
        TweenService:Create(uiStroke, fadeOut, {Transparency = 1}):Play()
        TweenService:Create(titleLabel, fadeOut, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
        TweenService:Create(contentLabel, fadeOut, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
        task.wait(0.5)
        if frame then frame:Destroy() end
    end))
end

local function startBLMonitor()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            local key = p.Name:lower()
            if blackList[key] then
                showBLNotify(p.DisplayName .. " (@" .. p.Name .. ")", true)
            end
        end
    end
    getgenv().__DST(Players.PlayerAdded:Connect(function(newPlr)
        local key = newPlr.Name:lower()
        if blackList[key] then
            showBLNotify(newPlr.DisplayName .. " (@" .. newPlr.Name .. ")", false)
        end
    end))
end

startBLMonitor()

local friendAlertGui = nil
local activeAlerts = {}

local function makeDraggable(frame, dragHandle)
    local dragTarget, dragging, dragStart, startPos = dragHandle or frame, false, nil, nil

    getgenv().__DST(dragTarget.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            getgenv().__DST(input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end))
        end
    end))

    getgenv().__DST(dragTarget.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end

        local autoExecFileName = "DShub autoexecute.txt"
        local AutoExecConfig = {
            NoclipBarrier = true,
            AntiInPlots = true,
            AntiInvisible = true,
            Antilag = true,
            Antilogger = true,
            AntiPoison = true,
            AntiVoid = true,
            AutoDeleteFollowThisParts = true,
            ChangeBlackHole = true,
            changecrosshair = true,
            Changelinetexture = true,
            Changelinetexturetofartherline = true,
            ChangeReachTo42Studs = true,
            ChatTypingDelete = true,
            DestroyAllToysButton = true,
            kickalarm = true,
            LiquidGlassMenu = true,
            MousePointer = true,
            NolegCanSit = true,
            OceanWalk = true,
            PacketLagDetect = true,
            StickyPartEsp = true,
            TrajectoryPrediction = true,
            VisibleCharacter = true,
            CustomCommands = {}
        }

        pcall(function()
            if isfile and readfile and isfile(autoExecFileName) then
                local content = readfile(autoExecFileName)
                local decoded = game:GetService("HttpService"):JSONDecode(content)
                if type(decoded) == "table" then
                    for k, v in pairs(decoded) do
                        if AutoExecConfig[k] ~= nil then AutoExecConfig[k] = v end
                    end
                end
            end
        end)

        local function saveAutoExecConfig()
            pcall(function()
                if writefile then
                    writefile(autoExecFileName, game:GetService("HttpService"):JSONEncode(AutoExecConfig))
                end
            end)
        end
        saveAutoExecConfig()

        local function setupMousePointer()
            local UserInputService = game:GetService("UserInputService")
            local RunService = game:GetService("RunService")
            local CoreGui = game:GetService("CoreGui")
            local Camera = workspace.CurrentCamera

            if CoreGui:FindFirstChild("MousePointerTrackerGui") then
                CoreGui.MousePointerTrackerGui:Destroy()
            end

            local screenGui = getgenv().__DSN("ScreenGui")
            screenGui.Name = "MousePointerTrackerGui"
            screenGui.ResetOnSpawn = false
            screenGui.IgnoreGuiInset = true
            screenGui.DisplayOrder = 2147483647

            if gethui then
                screenGui.Parent = gethui()
            elseif syn and syn.protect_gui then
                syn.protect_gui(screenGui)
                screenGui.Parent = CoreGui
            else
                screenGui.Parent = CoreGui
            end

            local cursorContainer = getgenv().__DSN("Frame")
            cursorContainer.Name = "CursorIcon"
            cursorContainer.Size = UDim2.new(0, 10, 0, 10)
            cursorContainer.AnchorPoint = Vector2.new(0.5, 0.5)
            cursorContainer.BackgroundTransparency = 1
            cursorContainer.ZIndex = 10000
            cursorContainer.Parent = screenGui

            local bgVertical = getgenv().__DSN("Frame")
            bgVertical.Size = UDim2.new(0, 4, 0, 10)
            bgVertical.AnchorPoint = Vector2.new(0.5, 0.5)
            bgVertical.Position = UDim2.new(0.5, 0, 0.5, 0)
            bgVertical.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            bgVertical.BorderSizePixel = 0
            bgVertical.Parent = cursorContainer

            local bgHorizontal = getgenv().__DSN("Frame")
            bgHorizontal.Size = UDim2.new(0, 10, 0, 4)
            bgHorizontal.AnchorPoint = Vector2.new(0.5, 0.5)
            bgHorizontal.Position = UDim2.new(0.5, 0, 0.5, 0)
            bgHorizontal.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            bgHorizontal.BorderSizePixel = 0
            bgHorizontal.Parent = cursorContainer

            local fgVertical = getgenv().__DSN("Frame")
            fgVertical.Size = UDim2.new(0, 2, 0, 8)
            fgVertical.AnchorPoint = Vector2.new(0.5, 0.5)
            fgVertical.Position = UDim2.new(0.5, 0, 0.5, 0)
            fgVertical.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            fgVertical.BorderSizePixel = 0
            fgVertical.Parent = cursorContainer

            local fgHorizontal = getgenv().__DSN("Frame")
            fgHorizontal.Size = UDim2.new(0, 8, 0, 2)
            fgHorizontal.AnchorPoint = Vector2.new(0.5, 0.5)
            fgHorizontal.Position = UDim2.new(0.5, 0, 0.5, 0)
            fgHorizontal.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            fgHorizontal.BorderSizePixel = 0
            fgHorizontal.Parent = cursorContainer

            local renderConnection
            local lastMX, lastMY = nil, nil
            renderConnection = getgenv().__DST(RunService.RenderStepped:Connect(function()
                if not screenGui or not screenGui.Parent then
                    if renderConnection then
                        renderConnection:Disconnect()
                    end
                    return
                end

                local mousePos = UserInputService:GetMouseLocation()
                if mousePos.X ~= lastMX or mousePos.Y ~= lastMY then
                    lastMX, lastMY = mousePos.X, mousePos.Y
                    cursorContainer.Position = UDim2.new(0, lastMX, 0, lastMY)
                end

                local showCursor = (Camera.CFrame.Position - Camera.Focus.Position).Magnitude >= 1
                if cursorContainer.Visible ~= showCursor then
                    cursorContainer.Visible = showCursor
                end
            end))
        end

        if AutoExecConfig.MousePointer then
            getgenv().__DSTH(task.spawn(function()
                pcall(setupMousePointer)
            end))
        end

        local autoExecGui = nil
        local function openAutoExecGui()
            if autoExecGui then autoExecGui:Destroy() end
            autoExecGui = getgenv().__DSN("ScreenGui")
            autoExecGui.Name = "AutoExecGui"
            autoExecGui.Parent = lp:WaitForChild("PlayerGui")
            autoExecGui.ResetOnSpawn = false

            local frame = getgenv().__DSN("Frame")
            frame.Size = UDim2.new(0, 300, 0, 400)
            frame.Position = UDim2.new(1, -310, 0, 350)
            frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            frame.Parent = autoExecGui
            makeDraggable(frame)

            local corner = getgenv().__DSN("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = frame

            local title = getgenv().__DSN("TextLabel")
            title.Size = UDim2.new(1, -40, 0, 30)
            title.Text = "자동 실행 스크립트 관리"
            title.TextColor3 = Color3.new(1, 1, 1)
            title.Font = Enum.Font.GothamBold
            title.TextSize = 14
            title.BackgroundTransparency = 1
            title.Parent = frame

            local closeBtn = getgenv().__DSN("TextButton")
            closeBtn.Size = UDim2.new(0, 30, 0, 30)
            closeBtn.Position = UDim2.new(1, -30, 0, 0)
            closeBtn.Text = "X"
            closeBtn.TextColor3 = Color3.new(1, 1, 1)
            closeBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
            closeBtn.Font = Enum.Font.GothamBold
            closeBtn.Parent = frame
            local closeCorner = getgenv().__DSN("UICorner")
            closeCorner.CornerRadius = UDim.new(0, 6)
            closeCorner.Parent = closeBtn
            getgenv().__DST(closeBtn.MouseButton1Click:Connect(function()
                if autoExecGui then
                    autoExecGui:Destroy()
                    autoExecGui = nil
                end
            end))

            local scroll = getgenv().__DSN("ScrollingFrame")
            scroll.Size = UDim2.new(1, -10, 1, -40)
            scroll.Position = UDim2.new(0, 5, 0, 35)
            scroll.BackgroundTransparency = 1
            scroll.ScrollBarThickness = 6
            scroll.Parent = frame

            local layout = getgenv().__DSN("UIListLayout")
            layout.Padding = UDim.new(0, 5)
            layout.Parent = scroll

            local sortedCmdKeys = {}
            for cmdStr in pairs(AutoExecConfig.CustomCommands) do
                sortedCmdKeys[#sortedCmdKeys + 1] = cmdStr
            end
            table.sort(sortedCmdKeys, function(x, y) return string.lower(x) < string.lower(y) end)

            for _, cmdStr in ipairs(sortedCmdKeys) do
                local cmdPlaceId = AutoExecConfig.CustomCommands[cmdStr]
                local item = getgenv().__DSN("Frame")
                item.Size = UDim2.new(1, 0, 0, 30)
                item.BackgroundTransparency = 1
                item.Parent = scroll

                local nameLbl = getgenv().__DSN("TextLabel")
                nameLbl.Size = UDim2.new(0.7, 0, 1, 0)
                nameLbl.Text = " ." .. cmdStr .. " (PlaceId: " .. tostring(cmdPlaceId) .. ")"
                nameLbl.TextColor3 = Color3.new(1, 1, 1)
                nameLbl.Font = Enum.Font.Gotham
                nameLbl.TextSize = 13
                nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                nameLbl.BackgroundTransparency = 1
                nameLbl.Parent = item

                local deleteBtn = getgenv().__DSN("TextButton")
                deleteBtn.Size = UDim2.new(0.3, -5, 0.8, 0)
                deleteBtn.Position = UDim2.new(0.7, 0, 0.1, 0)
                deleteBtn.Text = "Delete"
                deleteBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                deleteBtn.TextColor3 = Color3.new(1, 1, 1)
                deleteBtn.Font = Enum.Font.GothamBold
                deleteBtn.TextSize = 15
                deleteBtn.TextScaled = false
                deleteBtn.Parent = item
                local delCorner = getgenv().__DSN("UICorner")
                delCorner.CornerRadius = UDim.new(0, 4)
                delCorner.Parent = deleteBtn

                getgenv().__DST(deleteBtn.MouseButton1Click:Connect(function()
                    AutoExecConfig.CustomCommands[cmdStr] = nil
                    saveAutoExecConfig()
                    item:Destroy()
                end))
            end

            local sortedConfigKeys = {}
            for key in pairs(AutoExecConfig) do
                if key ~= "CustomCommands" then
                    sortedConfigKeys[#sortedConfigKeys + 1] = key
                end
            end
            table.sort(sortedConfigKeys, function(x, y) return string.lower(x) < string.lower(y) end)

            for _, key in ipairs(sortedConfigKeys) do
                local val = AutoExecConfig[key]
                if key ~= "CustomCommands" then
                    local item = getgenv().__DSN("Frame")
                    item.Size = UDim2.new(1, 0, 0, 30)
                    item.BackgroundTransparency = 1
                    item.Parent = scroll

                    local nameLbl = getgenv().__DSN("TextLabel")
                    nameLbl.Size = UDim2.new(0.7, 0, 1, 0)
                    nameLbl.Text = " " .. key
                    nameLbl.TextColor3 = Color3.new(1, 1, 1)
                    nameLbl.Font = Enum.Font.Gotham
                    nameLbl.TextSize = 13
                    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                    nameLbl.BackgroundTransparency = 1
                    nameLbl.Parent = item

                    local toggleBtn = getgenv().__DSN("TextButton")
                    toggleBtn.Size = UDim2.new(0.3, -5, 0.8, 0)
                    toggleBtn.Position = UDim2.new(0.7, 0, 0.1, 0)
                    toggleBtn.Text = val and "ON" or "OFF"
                    toggleBtn.BackgroundColor3 = val and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
                    toggleBtn.TextColor3 = Color3.new(1, 1, 1)
                    toggleBtn.Font = Enum.Font.GothamBold
                    toggleBtn.Parent = item
                    local btnCorner = getgenv().__DSN("UICorner")
                    btnCorner.CornerRadius = UDim.new(0, 4)
                    btnCorner.Parent = toggleBtn

                    getgenv().__DST(toggleBtn.MouseButton1Click:Connect(function()
                        AutoExecConfig[key] = not AutoExecConfig[key]
                        toggleBtn.Text = AutoExecConfig[key] and "ON" or "OFF"
                        toggleBtn.BackgroundColor3 = AutoExecConfig[key] and Color3.fromRGB(50, 200, 50) or Color3.fromRGB(200, 50, 50)
                        saveAutoExecConfig()
                    end))
                end
            end

            scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
            getgenv().__DST(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
            end))
        end

local friendListUpdatePending = false
local function updateFriendList()
    if not F.friendListGui or not F.friendListGui.Enabled then return end
    if not F.friendListContent then return end
    if friendListUpdatePending then return end
    friendListUpdatePending = true
    getgenv().__DSTH(task.defer(function()
        friendListUpdatePending = false
        if not F.friendListGui or not F.friendListGui.Enabled then return end

    for _, child in ipairs(F.friendListContent:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end

    local index, friendCount = 1, 0

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and lp:IsFriendsWith(p.UserId) then
            friendCount = friendCount + 1
            local lbl = getgenv().__DSN("TextLabel")
            lbl.Name = "FriendEntry"
            lbl.Size = UDim2.new(1, -10, 0, 25)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3 = Color3.fromRGB(230, 230, 230)
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Font = Enum.Font.GothamSemibold
            lbl.TextSize = 14
            lbl.Text = tostring(index) .. ". " .. p.DisplayName .. " (@" .. p.Name .. ")"
            lbl.Parent = F.friendListContent
            index = index + 1
        end
    end

    if friendCount == 0 then
        local lbl = getgenv().__DSN("TextLabel")
        lbl.Name = "NoFriendEntry"
        lbl.Size = UDim2.new(1, -10, 0, 25)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        lbl.TextXAlignment = Enum.TextXAlignment.Center
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 14
        lbl.Text = "현재 접속중인 친구가 없습니다."
        lbl.Parent = F.friendListContent
    end

    if F.friendListLayout then
        getgenv().__DSTH(task.delay(0.05, function()
            local contentHeight = F.friendListLayout.AbsoluteContentSize.Y
            F.friendListContent.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 10)
        end))
    end
    end))
end

local function createFriendListGui()
    if F.friendListGui then return end
    local sg = getgenv().__DSN("ScreenGui")
    sg.Name = "FriendListGui"
    sg.Parent = lp:WaitForChild("PlayerGui")
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999999996

    local frame = getgenv().__DSN("Frame")
    frame.Size = UDim2.new(0, 250, 0, 300)
    frame.Position = UDim2.new(0, 20, 0.5, -150)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    makeDraggable(frame)
    local corner = getgenv().__DSN("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = frame

    local title = getgenv().__DSN("TextLabel")
    title.Size = UDim2.new(1, -40, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "친구 목록"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Parent = frame
    F.friendListTitle = title

    local closeBtn = getgenv().__DSN("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = frame
    local btnCorner = getgenv().__DSN("UICorner"); btnCorner.CornerRadius = UDim.new(0, 5); btnCorner.Parent = closeBtn
    getgenv().__DST(closeBtn.MouseButton1Click:Connect(function() sg.Enabled = false end))

    local scroll = getgenv().__DSN("ScrollingFrame")
    scroll.Name = "FriendScroll"
    scroll.Size = UDim2.new(1, -20, 1, -50)
    scroll.Position = UDim2.new(0, 10, 0, 45)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.Parent = frame

    local layout = getgenv().__DSN("UIListLayout")
    layout.Parent = scroll
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    getgenv().__DST(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local contentHeight = layout.AbsoluteContentSize.Y
        scroll.CanvasSize = UDim2.new(0, 0, 0, contentHeight + 10)
    end))
    F.friendListLayout = layout
    F.friendListContent = scroll
    F.friendListGui = sg
    updateFriendList()
end

local function toggleFriendList()
    if not F.friendListGui then
        createFriendListGui()
    else
        F.friendListGui.Enabled = not F.friendListGui.Enabled
        if F.friendListGui.Enabled then
            updateFriendList()
        end
    end
end

local function updateBlackListGui()
    if not F.blackListGui or not F.blackListGui.Enabled or not F.blackListContent then return end

    for _, child in ipairs(F.blackListContent:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    local entries = {}
    for key, stored in pairs(blackList) do
        table.insert(entries, {key = key, stored = stored})
    end
    table.sort(entries, function(a, b)
        return a.stored:lower() < b.stored:lower()
    end)

    if #entries == 0 then
        local emptyLabel = getgenv().__DSN("TextLabel")
        emptyLabel.Size = UDim2.new(1, -10, 0, 24)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
        emptyLabel.TextSize = 14
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.TextXAlignment = Enum.TextXAlignment.Center
        emptyLabel.Text = "현재 블랙리스트가 비어있습니다."
        emptyLabel.Parent = F.blackListContent
    else
        for index, entry in ipairs(entries) do
            local displayText, player = entry.stored, Players:FindFirstChild(entry.stored)
            if player then
                displayText = player.DisplayName .. " (@" .. player.Name .. ")"
            end

            local label = getgenv().__DSN("TextLabel")
            label.Size = UDim2.new(1, -10, 0, 24)
            label.BackgroundTransparency = 1
            label.TextColor3 = Color3.fromRGB(240, 240, 240)
            label.TextSize = 14
            label.Font = Enum.Font.GothamSemibold
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Text = tostring(index) .. ". " .. displayText
            label.TextTruncate = Enum.TextTruncate.AtEnd
            label.Parent = F.blackListContent
        end
    end
end

local function createBlackListGui()
    if F.blackListGui then return end

    local sg = getgenv().__DSN("ScreenGui")
    sg.Name = "BlackListGui"
    sg.Parent = lp:WaitForChild("PlayerGui")
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999999997

    local frame = getgenv().__DSN("Frame")
    frame.Size = UDim2.new(0, 280, 0, 360)
    frame.Position = UDim2.new(1, -300, 0.5, -180)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    frame.Active = true

    local corner = getgenv().__DSN("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = frame

    local titleBar = getgenv().__DSN("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 34)
    titleBar.BackgroundTransparency = 0.15
    titleBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = frame

    local title = getgenv().__DSN("TextLabel")
    title.Size = UDim2.new(1, -70, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "블랙리스트"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 17
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    local closeBtn = getgenv().__DSN("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -34, 0.5, -14)
    closeBtn.BackgroundColor3 = Color3.fromRGB(192, 56, 56)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Parent = titleBar

    local closeCorner = getgenv().__DSN("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    getgenv().__DST(closeBtn.MouseButton1Click:Connect(function()
        sg.Enabled = false
    end))

    local contentFrame = getgenv().__DSN("ScrollingFrame")
    contentFrame.Size = UDim2.new(1, -20, 1, -56)
    contentFrame.Position = UDim2.new(0, 10, 0, 46)
    contentFrame.BackgroundTransparency = 1
    contentFrame.BorderSizePixel = 0
    contentFrame.ScrollBarThickness = 8
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentFrame.Parent = frame

    local layout = getgenv().__DSN("UIListLayout")
    layout.Parent = contentFrame
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    getgenv().__DST(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        contentFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end))

    makeDraggable(frame, titleBar)

    F.blackListGui = sg
    F.blackListContent = contentFrame
    F.blackListLayout = layout

    updateBlackListGui()
end

local function toggleBlackListGui()
    if not F.blackListGui then
        createBlackListGui()
    else
        F.blackListGui.Enabled = not F.blackListGui.Enabled
        if F.blackListGui.Enabled then
            updateBlackListGui()
        end
    end
end

local function toggleAntiAfk(state)
    if state then
        if A.antiAfkEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ Anti-AFK ]", Text = "이미 켜져 있습니다.", Duration = 2})
            return
        end
        A.antiAfkEnabled = true

        A.antiAfkConnection = getgenv().__DST(lp.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end))

        A.antiAfkLoop = getgenv().__DSTH(task.spawn(function()
            while A.antiAfkEnabled do
                task.wait(900)
                if not A.antiAfkEnabled then break end
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
        end))

        StarterGui:SetCore("SendNotification", {Title = "[ Anti-AFK 켜짐 ]", Text = "이중 안전장치로 잠수 킥을 방지합니다.", Duration = 3})
    else
        if not A.antiAfkEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ Anti-AFK ]", Text = "이미 꺼져 있습니다.", Duration = 2})
            return
        end
        A.antiAfkEnabled = false
        if A.antiAfkConnection then
            A.antiAfkConnection:Disconnect()
            A.antiAfkConnection = nil
        end
        if A.antiAfkLoop then
            task.cancel(A.antiAfkLoop)
            A.antiAfkLoop = nil
        end
        StarterGui:SetCore("SendNotification", {Title = "[ Anti-AFK 꺼짐 ]", Text = "이제 잠수하면 튕길 수 있습니다.", Duration = 3})
    end
end

if game.PlaceId == 6961824067 then
    getgenv().__DSTH(task.spawn(function()

        if AutoExecConfig.Antilag then
            pcall(function()
                loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/antilag%20(%20auto%20)'))()
            end)
        end

        if AutoExecConfig.Changelinetexture then
            task.wait(0.1)
            pcall(function()
                loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/changelinetexture'))()
            end)
        end

        if AutoExecConfig.changecrosshair then
            task.wait(0.1)
            pcall(function()
                loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/crosshairchanger'))()
            end)
        end

        if AutoExecConfig.nolegcansit then
            task.wait(0.1)
            pcall(function()
                loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/nolegcansit'))()
            end)
        end

        if AutoExecConfig.AntiVoid then
            task.wait(0.1)
            pcall(function()
                loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/antivoid'))()
            end)
        end

        if AutoExecConfig.ChangeBlackHole then
            task.wait(0.1)
            pcall(function()
                loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/ChangeBlackHole'))()
            end)
        end

        if AutoExecConfig.DestroyAllToysButton then
            task.wait(0.1)
            pcall(function()
                loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/DestroyAllToysButton'))()
            end)
        end

        if AutoExecConfig.kickalarm then
            task.wait(0.1)
            pcall(function()
                loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/kickalarm'))()
            end)
        end

        if AutoExecConfig.packetlagdetect then
            task.wait(0.1)
            pcall(function()
                loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/packetlagdetect'))()
            end)
        end

        if AutoExecConfig.AutoDeleteFollowThisParts then
            task.wait(0.1)
            pcall(function()
                loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/autodeleteFollowThisParts'))()
            end)
        end

        if AutoExecConfig.Changelinetexturetofartherline then
            task.wait(0.1)
            local Players, Workspace = game:GetService("Players"), game:GetService("Workspace")
            local LocalPlayer = Players.LocalPlayer

            local function applyTexture(beam)
                if beam:IsA("Beam") and beam.Name == "GrabBeam" then
                    local char = LocalPlayer.Character
                    if not char then return end

                    local isMine = false
                    if beam.Attachment0 and beam.Attachment0:IsDescendantOf(char) then
                        isMine = true
                    elseif beam.Attachment1 and beam.Attachment1:IsDescendantOf(char) then
                        isMine = true
                    end

                    if isMine then
                        beam.Texture = "rbxassetid://8933355899"
                    end
                end
            end

            getgenv().__DSTH(task.spawn(function()
                local n = 0
                for _, descendant in ipairs(Workspace:GetDescendants()) do
                    applyTexture(descendant)
                    n = n + 1
                    if n % 300 == 0 then task.wait() end
                end
            end))

            getgenv().__DST(Workspace.DescendantAdded:Connect(function(descendant)
                if descendant:IsA("Beam") then
                    getgenv().__DSTH(task.defer(applyTexture, descendant))
                end
            end))
        end

        if AutoExecConfig.ChatTypingDelete then
            task.wait(0.1)

            local function removeChatTyping(character)
                local targetScript = character:WaitForChild("ChatTyping", 10)
                if targetScript then
                    targetScript:Destroy()
                end
            end

            if lp.Character then
                removeChatTyping(lp.Character)
            end

            getgenv().__DST(lp.CharacterAdded:Connect(function(character)
                removeChatTyping(character)
            end))
        end

    end))
end

local function toggleAntiLag(enable)
    if enable then
        if A.antiLagLoop then
            StarterGui:SetCore("SendNotification", {Title = "[ Auto-Exit ]", Text = "이미 켜져 있습니다.", Duration = 2})
            return
        end
        A.antiLagEnabled = true
        A.antiLagLoop = getgenv().__DSTH(task.spawn(function()
            while A.antiLagEnabled do
                task.wait(0.3)
                local fps, kbpsObj = workspace:GetRealPhysicsFPS(), Stats:FindFirstChild("DataReceiveKbps")
                local kbps = kbpsObj and kbpsObj.Value or 0

                if fps < 8 or kbps > 2000 then
                    game:Shutdown()
                    break
                end
            end
        end))
        StarterGui:SetCore("SendNotification", {Title = "[ Auto-Exit 켜짐 ]", Text = "FPS<8 또는 수신>2000kb 감지 시 자동 종료합니다.", Duration = 3})
    else
        A.antiLagEnabled = false
        if A.antiLagLoop then
            task.cancel(A.antiLagLoop)
            A.antiLagLoop = nil
        end
        StarterGui:SetCore("SendNotification", {Title = "[ Auto-Exit 꺼짐 ]", Text = "자동 종료 감지가 해제되었습니다.", Duration = 3})
    end
end

local function toggleCharAntiLag(enable)
    local playerScripts = lp:FindFirstChild("PlayerScripts")
    if not playerScripts then
        StarterGui:SetCore("SendNotification", {Title = "[ Anti-Lag ]", Text = "PlayerScripts를 찾을 수 없습니다.", Duration = 3})
        return
    end
    local targetScript = playerScripts:FindFirstChild("CharacterAndBeamMove")
    if not targetScript then
        StarterGui:SetCore("SendNotification", {Title = "[ Anti-Lag ]", Text = "CharacterAndBeamMove 스크립트를 찾을 수 없습니다.", Duration = 3})
        return
    end
    
    local AL = getgenv()._AntiLagScript
    
    if enable then
        targetScript.Disabled = true
        A.charAntiLagEnabled = true
        StarterGui:SetCore("SendNotification", {Title = "[ Anti-Lag 켜짐 ]", Text = "CharacterAndBeamMove 비활성화 완료.", Duration = 3})
    else
        if AL then
            AL.isLagging = false
            AL.isFpsLow = false
            AL.suspectPlayer = nil
            
            if AL.fireCount then
                for _, data in pairs(AL.fireCount) do
                    data.isFlagged = false
                    data.count = 0
                    data.cps = 0
                    data.frameBurst = 0
                    data.rapidCount = 0
                end
            end
            
            if AL.charBeamMove then 
                AL.charBeamMove.Enabled = true 
            end
        end
        
        targetScript.Disabled = false
        A.charAntiLagEnabled = false
        StarterGui:SetCore("SendNotification", {Title = "[ Anti-Lag 리셋 ]", Text = "렉 상태를 초기화하고 빔을 활성화했습니다.", Duration = 3})
    end
end

local function toggleFpsBoost(enable)
    if enable then
        if S.fpsBoostEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ FPS 부스트 ]", Text = "이미 켜져 있습니다.", Duration = 2})
            return
        end
        S.fpsBoostEnabled = true

        local ok, err = pcall(function()
            S.originalLightingState = {
                GlobalShadows = Lighting.GlobalShadows,
                FogEnd = Lighting.FogEnd,
                Brightness = Lighting.Brightness,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                Ambient = Lighting.Ambient
            }

            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.Brightness = 1

            if Terrain then
                Terrain.WaterWaveSize = 0
                Terrain.WaterWaveSpeed = 0
                Terrain.WaterReflectance = 0
                Terrain.WaterTransparency = 0
            end

            S.fpsExtra = {effects = {}}
            pcall(function()
                S.fpsExtra.quality = settings().Rendering.QualityLevel
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end)
            if Terrain then
                pcall(function()
                    S.fpsExtra.decoration = Terrain.Decoration
                    Terrain.Decoration = false
                end)
            end
            for _, e in ipairs(Lighting:GetChildren()) do
                if e:IsA("BloomEffect") or e:IsA("BlurEffect") or e:IsA("DepthOfFieldEffect") or e:IsA("SunRaysEffect") then
                    S.fpsExtra.effects[e] = e.Enabled
                    e.Enabled = false
                end
            end

            local function optimizeObject(v)
                if v:IsA("BasePart") and not v:IsA("Terrain") then
                    if not S.cachedParts[v] then
                        S.cachedParts[v] = {
                            Type = "BasePart",
                            Material = v.Material,
                            Reflectance = v.Reflectance,
                            CastShadow = v.CastShadow,
                            RenderFidelity = v:IsA("MeshPart") and v.RenderFidelity or nil
                        }
                    end
                    v.Material = Enum.Material.SmoothPlastic
                    v.Reflectance = 0
                    v.CastShadow = false
                    if v:IsA("MeshPart") then
                        v.RenderFidelity = Enum.RenderFidelity.Performance
                    end

                elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") or v:IsA("Light") then
                    if not S.cachedParts[v] then
                        S.cachedParts[v] = {
                            Type = "Effect",
                            Enabled = v.Enabled
                        }
                    end
                    v.Enabled = false

                elseif v:IsA("Decal") or v:IsA("Texture") then
                    if not S.cachedParts[v] then
                        S.cachedParts[v] = {
                            Type = "Texture",
                            Transparency = v.Transparency
                        }
                    end
                    v.Transparency = 1
                end
            end

            getgenv().__DSTH(task.spawn(function()
                local n = 0
                for _, v in ipairs(Workspace:GetDescendants()) do
                    if not S.fpsBoostEnabled then return end
                    pcall(optimizeObject, v)
                    n = n + 1
                    if n % 250 == 0 then task.wait() end
                end
            end))

            S.fpsBoostConnection = getgenv().__DST(Workspace.DescendantAdded:Connect(function(v)
                pcall(optimizeObject, v)
            end))
        end)

        if not ok then
            S.fpsBoostEnabled = false
            StarterGui:SetCore("SendNotification", {Title = "[ FPS 부스트 실패 ]", Text = "오류가 발생했습니다: " .. tostring(err), Duration = 4})
            return
        end

        StarterGui:SetCore("SendNotification", {Title = "[ FPS 부스트 켜짐 ]", Text = "그래픽을 낮추고 원본 설정을 저장했습니다.(200 스터드 밖 오브젝트 숨김 적용)", Duration = 3})

        S.cullHiddenParts = {}
        S.cullRunning = true
        getgenv().__DSTH(task.spawn(function()
            task.wait()
            local cullList, cullTick = {}, 0
            while S.cullRunning do
                pcall(function()
                    local char = lp.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then
                        if cullTick % 20 == 0 then
                            local list, n, seen = {}, 0, 0
                            for _, v in ipairs(Workspace:GetDescendants()) do
                                if v:IsA("BasePart") and not v:IsA("Terrain") then
                                    n = n + 1
                                    list[n] = v
                                end
                                seen = seen + 1
                                if seen % 500 == 0 then
                                    task.wait()
                                    if not S.cullRunning then return end
                                end
                            end
                            cullList = list
                        end
                        cullTick = cullTick + 1
                        local originPos = root.Position
                        local ox, oy, oz = originPos.X, originPos.Y, originPos.Z
                        for i = 1, #cullList do
                            local v = cullList[i]
                            if v.Parent and v ~= root then
                                local p = v.Position
                                local dx, dy, dz = p.X - ox, p.Y - oy, p.Z - oz
                                local far = (dx * dx + dy * dy + dz * dz) > 40000
                                local hidden = S.cullHiddenParts[v]
                                if far then
                                    if not hidden and not v:IsDescendantOf(char) then
                                        S.cullHiddenParts[v] = {
                                            Transparency = v.Transparency,
                                            CanCollide = v.CanCollide,
                                            CanQuery = v.CanQuery,
                                            CanTouch = v.CanTouch
                                        }
                                        v.Transparency = 1
                                        v.CanCollide = false
                                        v.CanQuery = false
                                        v.CanTouch = false
                                    end
                                elseif hidden then
                                    v.Transparency = hidden.Transparency
                                    v.CanCollide = hidden.CanCollide
                                    v.CanQuery = hidden.CanQuery
                                    if hidden.CanTouch ~= nil then v.CanTouch = hidden.CanTouch end
                                    S.cullHiddenParts[v] = nil
                                end
                            end
                            if i % 300 == 0 then
                                task.wait()
                                if not S.cullRunning then return end
                            end
                        end
                    end
                end)
                task.wait(0.5)
            end
        end))

    else
        if not S.fpsBoostEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ FPS 부스트 ]", Text = "이미 꺼져 있습니다.", Duration = 2})
            return
        end
        S.fpsBoostEnabled = false

        if S.fpsBoostConnection then
            S.fpsBoostConnection:Disconnect()
            S.fpsBoostConnection = nil
        end

        S.cullRunning = false
        if S.cullHiddenParts then
            for obj, data in pairs(S.cullHiddenParts) do
                if obj and obj.Parent then
                    pcall(function()
                        obj.Transparency = data.Transparency
                        obj.CanCollide = data.CanCollide
                        obj.CanQuery = data.CanQuery
                        if data.CanTouch ~= nil then obj.CanTouch = data.CanTouch end
                    end)
                end
            end
            S.cullHiddenParts = {}
        end

        if S.originalLightingState.GlobalShadows ~= nil then
            Lighting.GlobalShadows = S.originalLightingState.GlobalShadows
            Lighting.FogEnd = S.originalLightingState.FogEnd
            Lighting.Brightness = S.originalLightingState.Brightness
            Lighting.OutdoorAmbient = S.originalLightingState.OutdoorAmbient
            Lighting.Ambient = S.originalLightingState.Ambient
        else
            Lighting.GlobalShadows = true
            Lighting.FogEnd = 10000
            Lighting.Brightness = 2
        end

        for obj, data in pairs(S.cachedParts) do
            if obj and obj.Parent then
                local ok, err = pcall(function()
                    if data.Type == "BasePart" or data.Type == "MeshPart" then
                        obj.Material = data.Material
                        if data.Reflectance ~= nil then obj.Reflectance = data.Reflectance end
                        if data.CastShadow ~= nil then obj.CastShadow = data.CastShadow end
                        if data.RenderFidelity ~= nil then obj.RenderFidelity = data.RenderFidelity end
                    elseif data.Type == "Texture" then
                        obj.Transparency = data.Transparency
                    elseif data.Type == "Effect" then
                        obj.Enabled = data.Enabled
                    end
                end)
            end
        end

        S.cachedParts = {}
        if S.fpsExtra then
            pcall(function()
                if S.fpsExtra.quality ~= nil then settings().Rendering.QualityLevel = S.fpsExtra.quality end
            end)
            if Terrain and S.fpsExtra.decoration ~= nil then
                pcall(function() Terrain.Decoration = S.fpsExtra.decoration end)
            end
            for e, en in pairs(S.fpsExtra.effects) do
                if e and e.Parent then e.Enabled = en end
            end
            S.fpsExtra = nil
        end
        StarterGui:SetCore("SendNotification", {Title = "[ FPS 부스트 꺼짐 ]", Text = "원래 그래픽 및 재질로 복구되었습니다.", Duration = 3})
    end
end

local function toggleShader(enable)
    if enable then
        if S.shaderEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ 쉐이더 ]", Text = "이미 켜져 있습니다.", Duration = 2})
            return
        end
        S.shaderEnabled = true


        local savedTech = nil
        pcall(function() savedTech = Lighting.Technology end)

        local savedCC, savedBloom, savedSunRays, savedBlur, savedDOF, savedAtmo, savedClouds =
            Lighting:FindFirstChildWhichIsA("ColorCorrectionEffect"),
            Lighting:FindFirstChildWhichIsA("BloomEffect"),
            Lighting:FindFirstChildWhichIsA("SunRaysEffect"),
            Lighting:FindFirstChildWhichIsA("BlurEffect"),
            Lighting:FindFirstChildWhichIsA("DepthOfFieldEffect"),
            Lighting:FindFirstChildWhichIsA("Atmosphere"),
            Terrain and Terrain:FindFirstChildWhichIsA("Clouds") or nil

        S.originalShaderState = {
            Technology = savedTech,
            Brightness = Lighting.Brightness,
            ExposureCompensation = Lighting.ExposureCompensation,
            GlobalShadows = Lighting.GlobalShadows,
            ShadowSoftness = Lighting.ShadowSoftness,
            Ambient = Lighting.Ambient,
            ColorCorrection = savedCC and {
                wasAbsent = false, name = savedCC.Name,
                Enabled = savedCC.Enabled, Brightness = savedCC.Brightness,
                Contrast = savedCC.Contrast, Saturation = savedCC.Saturation,
            } or { wasAbsent = true },
            Bloom = savedBloom and { wasAbsent = false, name = savedBloom.Name, Enabled = savedBloom.Enabled }
                or { wasAbsent = true },
            SunRays = savedSunRays and { wasAbsent = false, name = savedSunRays.Name, Enabled = savedSunRays.Enabled }
                or { wasAbsent = true },
            Blur = savedBlur and { wasAbsent = false, name = savedBlur.Name, Enabled = savedBlur.Enabled }
                or { wasAbsent = true },
            DOF = savedDOF and { wasAbsent = false, name = savedDOF.Name, Enabled = savedDOF.Enabled }
                or { wasAbsent = true },
            Atmosphere = savedAtmo and {
                wasAbsent = false, name = savedAtmo.Name,
                Density = savedAtmo.Density, Haze = savedAtmo.Haze,
            } or { wasAbsent = true },
            Clouds = savedClouds and {
                wasAbsent = false, name = savedClouds.Name,
                Cover = savedClouds.Cover, Density = savedClouds.Density,
            } or { wasAbsent = true },
        }

        local function getEffect(name, className)
            local obj = Lighting:FindFirstChild(name) or Lighting:FindFirstChildWhichIsA(className)
            if not obj then
                obj = getgenv().__DSN(className)
                obj.Name = name
                obj.Parent = Lighting
            end
            return obj
        end

        local ColorCorrection, Bloom, SunRays, Blur, DOF, Atmosphere =
            getEffect("ShaderUtility_ColorCorrection", "ColorCorrectionEffect"),
            getEffect("ShaderUtility_Bloom", "BloomEffect"),
            getEffect("ShaderUtility_SunRays", "SunRaysEffect"),
            getEffect("ShaderUtility_Blur", "BlurEffect"),
            getEffect("ShaderUtility_DepthOfField", "DepthOfFieldEffect"),
            Lighting:FindFirstChildWhichIsA("Atmosphere")
        if not Atmosphere then
            Atmosphere = getgenv().__DSN("Atmosphere")
            Atmosphere.Name = "ShaderUtility_Atmosphere"
            Atmosphere.Parent = Lighting
        end

        local Clouds
        if Terrain then
            Clouds = Terrain:FindFirstChildWhichIsA("Clouds")
            if not Clouds then
                Clouds = getgenv().__DSN("Clouds")
                Clouds.Name = "ShaderUtility_Clouds"
                Clouds.Parent = Terrain
            end
        end

        pcall(function() Lighting.Technology = Enum.Technology.Future end)

        ColorCorrection.Enabled = true
        ColorCorrection.Brightness = 0
        ColorCorrection.Contrast = 0.08
        ColorCorrection.Saturation = 0.02

        Lighting.Brightness = 2
        Lighting.ExposureCompensation = 0
        Lighting.GlobalShadows = false
        Lighting.ShadowSoftness = 0
        Lighting.Ambient = Color3.fromRGB(math.floor(85 * 0.9), math.floor(85 * 0.9), math.floor(95 * 0.9))

        Bloom.Enabled = false
        SunRays.Enabled = false
        Blur.Enabled = false
        DOF.Enabled = false

        Atmosphere.Density = 0.06
        Atmosphere.Haze = 0.1

        if Clouds then
            pcall(function() Clouds.Enabled = true end)
            Clouds.Cover = 0
            Clouds.Density = 0
        end

        local function disablePartShadow(obj)
            if obj:IsA("BasePart") then
                pcall(function() obj.CastShadow = false end)
            end
        end
        getgenv().__DSTH(task.spawn(function()
            local n = 0
            for _, obj in ipairs(Workspace:GetDescendants()) do
                disablePartShadow(obj)
                n = n + 1
                if n % 300 == 0 then task.wait() end
            end
        end))
        S.shaderDescConn = getgenv().__DST(Workspace.DescendantAdded:Connect(function(obj)
            disablePartShadow(obj)
        end))

        StarterGui:SetCore("SendNotification", {Title = "[ 쉐이더 켜짐 ]", Text = "쉐이더 효과가 적용되었습니다.", Duration = 3})
    else
        if not S.shaderEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ 쉐이더 ]", Text = "이미 꺼져 있습니다.", Duration = 2})
            return
        end
        S.shaderEnabled = false

        if S.shaderDescConn then
            S.shaderDescConn:Disconnect()
            S.shaderDescConn = nil
        end

        local st = S.originalShaderState

        if st.Technology ~= nil then pcall(function() Lighting.Technology = st.Technology end) end
        if st.Brightness ~= nil then Lighting.Brightness = st.Brightness end
        if st.ExposureCompensation ~= nil then Lighting.ExposureCompensation = st.ExposureCompensation end
        if st.GlobalShadows ~= nil then Lighting.GlobalShadows = st.GlobalShadows end
        if st.ShadowSoftness ~= nil then Lighting.ShadowSoftness = st.ShadowSoftness end
        if st.Ambient ~= nil then Lighting.Ambient = st.Ambient end

        local cc = Lighting:FindFirstChildWhichIsA("ColorCorrectionEffect")
        if cc then
            if st.ColorCorrection and st.ColorCorrection.wasAbsent then
                cc:Destroy()
            elseif st.ColorCorrection and not st.ColorCorrection.wasAbsent then
                pcall(function() cc.Enabled = st.ColorCorrection.Enabled end)
                pcall(function() cc.Brightness = st.ColorCorrection.Brightness end)
                pcall(function() cc.Contrast = st.ColorCorrection.Contrast end)
                pcall(function() cc.Saturation = st.ColorCorrection.Saturation end)
            end
        end

        local bloom = Lighting:FindFirstChildWhichIsA("BloomEffect")
        if bloom then
            if st.Bloom and st.Bloom.wasAbsent then bloom:Destroy()
            elseif st.Bloom and not st.Bloom.wasAbsent then pcall(function() bloom.Enabled = st.Bloom.Enabled end) end
        end

        local sunrays = Lighting:FindFirstChildWhichIsA("SunRaysEffect")
        if sunrays then
            if st.SunRays and st.SunRays.wasAbsent then sunrays:Destroy()
            elseif st.SunRays and not st.SunRays.wasAbsent then pcall(function() sunrays.Enabled = st.SunRays.Enabled end) end
        end

        local blur = Lighting:FindFirstChildWhichIsA("BlurEffect")
        if blur then
            if st.Blur and st.Blur.wasAbsent then blur:Destroy()
            elseif st.Blur and not st.Blur.wasAbsent then pcall(function() blur.Enabled = st.Blur.Enabled end) end
        end

        local dof = Lighting:FindFirstChildWhichIsA("DepthOfFieldEffect")
        if dof then
            if st.DOF and st.DOF.wasAbsent then dof:Destroy()
            elseif st.DOF and not st.DOF.wasAbsent then pcall(function() dof.Enabled = st.DOF.Enabled end) end
        end

        local atmo = Lighting:FindFirstChildWhichIsA("Atmosphere")
        if atmo then
            if st.Atmosphere and st.Atmosphere.wasAbsent then atmo:Destroy()
            elseif st.Atmosphere and not st.Atmosphere.wasAbsent then
                pcall(function() atmo.Density = st.Atmosphere.Density end)
                pcall(function() atmo.Haze = st.Atmosphere.Haze end)
            end
        end

        if Terrain then
            local clouds = Terrain:FindFirstChildWhichIsA("Clouds")
            if clouds then
                if st.Clouds and st.Clouds.wasAbsent then clouds:Destroy()
                elseif st.Clouds and not st.Clouds.wasAbsent then
                    pcall(function() clouds.Cover = st.Clouds.Cover end)
                    pcall(function() clouds.Density = st.Clouds.Density end)
                end
            end
        end

        S.originalShaderState = {}
        StarterGui:SetCore("SendNotification", {Title = "[ 쉐이더 꺼짐 ]", Text = "원래 조명 설정으로 복구되었습니다.", Duration = 3})
    end
end

local function sendChatMessage(msg)
    if not msg or #msg == 0 then return end
    local legacyChat = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
    if legacyChat and legacyChat:FindFirstChild("SayMessageRequest") then
        legacyChat.SayMessageRequest:FireServer(msg, "All")
    elseif TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local channel = TextChatService:FindFirstChild("TextChannels") and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if channel then channel:SendAsync(msg) end
    else
        pcall(function() Players:Chat(msg) end)
    end
end

function E.iconEspGetGui()
    if E.iconEspGui and E.iconEspGui.Parent then return E.iconEspGui end
    local g = getgenv().__DSN("ScreenGui")
    g.Name = "DS_IconESP"
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    pcall(function() g.Parent = gethui and gethui() or game:GetService("CoreGui") end)
    if not g.Parent then g.Parent = lp:WaitForChild("PlayerGui") end
    E.iconEspGui = g
    return g
end

function E.iconEspRemove(p)
    local data = E.iconEspObjects[p]
    if not data then return end
    E.iconEspObjects[p] = nil
    for _, c in ipairs(data.Connections) do c:Disconnect() end
    if data.Billboard then data.Billboard:Destroy() end
end

function E.iconEspCreate(p)
    if not E.iconEspEnabled or p == lp then return end
    local character = p.Character
    if not character then return end
    local old = E.iconEspObjects[p]
    if old then
        if old.Character == character then return end
        E.iconEspRemove(p)
    end
    local head = character:WaitForChild("Head", 5)
    if not head or not E.iconEspEnabled or not character.Parent or p.Character ~= character or E.iconEspObjects[p] then return end

    local bb = getgenv().__DSN("BillboardGui")
    bb.Adornee = head
    bb.Size = UDim2.fromOffset(200, 150)
    bb.SizeOffset = Vector2.new(0, 0.5)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = E.iconEspGetGui()

    local layout = getgenv().__DSN("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.Parent = bb

    local img = getgenv().__DSN("ImageLabel")
    img.BackgroundTransparency = 1
    img.Size = UDim2.fromOffset(32, 32)
    img.ScaleType = Enum.ScaleType.Crop
    img.Visible = false
    img.Parent = bb

    local txt = getgenv().__DSN("TextLabel")
    txt.BackgroundTransparency = 1
    txt.Size = UDim2.new(1, 0, 0, 0)
    txt.AutomaticSize = Enum.AutomaticSize.Y
    txt.TextXAlignment = Enum.TextXAlignment.Center
    txt.TextYAlignment = Enum.TextYAlignment.Top
    txt.TextSize = 11
    txt.TextColor3 = Color3.new(1, 1, 1)
    txt.TextTransparency = 0
    txt.TextStrokeColor3 = Color3.new(0, 0, 0)
    txt.TextStrokeTransparency = 0
    txt.FontFace = Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Bold)
    txt.Text = p.DisplayName .. "\n (@" .. p.Name .. ")"
    txt.Parent = bb

    local data = {Character = character, Billboard = bb, Connections = {}}
    E.iconEspObjects[p] = data
    data.Connections[1] = getgenv().__DST(character.AncestryChanged:Connect(function(_, parent)
        if not parent and E.iconEspObjects[p] == data then E.iconEspRemove(p) end
    end))

    getgenv().__DSTH(task.spawn(function()
        local ok, result = pcall(function()
            return Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size48x48)
        end)
        if ok and result and img.Parent then
            img.Image = result
            img.Visible = true
        end
    end))
end

function E.iconEspHook(p)
    if p == lp then return end
    local old = E.iconEspCharConns[p]
    if old then old:Disconnect() end
    E.iconEspCharConns[p] = getgenv().__DST(p.CharacterAdded:Connect(function()
        E.iconEspCreate(p)
    end))
    getgenv().__DSTH(task.spawn(E.iconEspCreate, p))
end

local function removeAllIconEsp()
    for p in pairs(E.iconEspObjects) do E.iconEspRemove(p) end
    for p, c in pairs(E.iconEspCharConns) do
        c:Disconnect()
        E.iconEspCharConns[p] = nil
    end
    if E.iconEspGui then E.iconEspGui:Destroy() E.iconEspGui = nil end
end

local function toggleIconEsp(state)
    if state then
        if E.iconEspEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ IconESP ]", Text = "이미 켜져 있습니다.", Duration = 2})
            return
        end
        E.iconEspEnabled = state
        if E.iconEspConnection then E.iconEspConnection:Disconnect() end
        if E.iconEspRemovingConn then E.iconEspRemovingConn:Disconnect() end
        for _, p in ipairs(Players:GetPlayers()) do
            E.iconEspHook(p)
        end
        E.iconEspConnection = getgenv().__DST(Players.PlayerAdded:Connect(function(p)
            E.iconEspHook(p)
        end))
        E.iconEspRemovingConn = getgenv().__DST(Players.PlayerRemoving:Connect(function(p)
            E.iconEspRemove(p)
            local c = E.iconEspCharConns[p]
            if c then c:Disconnect() E.iconEspCharConns[p] = nil end
        end))
        StarterGui:SetCore("SendNotification", {Title = "[ IconESP 켜짐 ]", Text = "모든 플레이어 표시", Duration = 3})
    else
        if not E.iconEspEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ IconESP ]", Text = "이미 꺼져 있습니다.", Duration = 2})
            return
        end
        E.iconEspEnabled = state
        if E.iconEspConnection then E.iconEspConnection:Disconnect() E.iconEspConnection = nil end
        if E.iconEspRemovingConn then E.iconEspRemovingConn:Disconnect() E.iconEspRemovingConn = nil end
        removeAllIconEsp()
        StarterGui:SetCore("SendNotification", {Title = "[ IconESP 꺼짐 ]", Text = "모든 ESP를 제거했습니다.", Duration = 2})
    end
end

function E.nameEspGetGui()
    if E.nameEspGui and E.nameEspGui.Parent then return E.nameEspGui end
    local g = getgenv().__DSN("ScreenGui")
    g.Name = "DS_NameESP"
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    pcall(function() g.Parent = gethui and gethui() or game:GetService("CoreGui") end)
    if not g.Parent then g.Parent = lp:WaitForChild("PlayerGui") end
    E.nameEspGui = g
    return g
end

function E.nameEspRemove(p)
    local data = E.nameEspObjects[p]
    if not data then return end
    E.nameEspObjects[p] = nil
    for _, c in ipairs(data.Connections) do c:Disconnect() end
    if data.Billboard then data.Billboard:Destroy() end
end

function E.nameEspCreate(p)
    if not E.nameEspEnabled or p == lp then return end
    local character = p.Character
    if not character then return end
    local old = E.nameEspObjects[p]
    if old then
        if old.Character == character then return end
        E.nameEspRemove(p)
    end
    local head = character:WaitForChild("Head", 5)
    if not head or not E.nameEspEnabled or not character.Parent or p.Character ~= character or E.nameEspObjects[p] then return end

    local bb = getgenv().__DSN("BillboardGui")
    bb.Adornee = head
    bb.Size = UDim2.fromOffset(200, 150)
    bb.SizeOffset = Vector2.new(0, 0.5)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = E.nameEspGetGui()

    local layout = getgenv().__DSN("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.Parent = bb

    local txt = getgenv().__DSN("TextLabel")
    txt.BackgroundTransparency = 1
    txt.Size = UDim2.new(1, 0, 0, 0)
    txt.AutomaticSize = Enum.AutomaticSize.Y
    txt.TextXAlignment = Enum.TextXAlignment.Center
    txt.TextYAlignment = Enum.TextYAlignment.Top
    txt.TextSize = 11
    txt.TextColor3 = Color3.new(1, 1, 1)
    txt.TextTransparency = 0
    txt.TextStrokeColor3 = Color3.new(0, 0, 0)
    txt.TextStrokeTransparency = 0
    txt.FontFace = Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Bold)
    txt.Text = p.DisplayName .. "\n (@" .. p.Name .. ")"
    txt.Parent = bb

    local data = {Character = character, Billboard = bb, Connections = {}}
    E.nameEspObjects[p] = data
    data.Connections[1] = getgenv().__DST(character.AncestryChanged:Connect(function(_, parent)
        if not parent and E.nameEspObjects[p] == data then E.nameEspRemove(p) end
    end))
end

function E.nameEspHook(p)
    if p == lp then return end
    local old = E.nameEspCharConns[p]
    if old then old:Disconnect() end
    E.nameEspCharConns[p] = getgenv().__DST(p.CharacterAdded:Connect(function()
        E.nameEspCreate(p)
    end))
    getgenv().__DSTH(task.spawn(E.nameEspCreate, p))
end

local function removeAllNameEsp()
    for p in pairs(E.nameEspObjects) do E.nameEspRemove(p) end
    for p, c in pairs(E.nameEspCharConns) do
        c:Disconnect()
        E.nameEspCharConns[p] = nil
    end
    if E.nameEspGui then E.nameEspGui:Destroy() E.nameEspGui = nil end
end

local function toggleNameEsp(state)
    if state then
        if E.nameEspEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ NameESP ]", Text = "이미 켜져 있습니다.", Duration = 2})
            return
        end
        E.nameEspEnabled = true
        if E.nameEspConnection then E.nameEspConnection:Disconnect() end
        if E.nameEspRemovingConn then E.nameEspRemovingConn:Disconnect() end
        for _, p in ipairs(Players:GetPlayers()) do
            E.nameEspHook(p)
        end
        E.nameEspConnection = getgenv().__DST(Players.PlayerAdded:Connect(function(p)
            E.nameEspHook(p)
        end))
        E.nameEspRemovingConn = getgenv().__DST(Players.PlayerRemoving:Connect(function(p)
            E.nameEspRemove(p)
            local c = E.nameEspCharConns[p]
            if c then c:Disconnect() E.nameEspCharConns[p] = nil end
        end))
        StarterGui:SetCore("SendNotification", {Title = "[ NameESP 켜짐 ]", Text = "모든 플레이어 이름 표시", Duration = 3})
    else
        if not E.nameEspEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ NameESP ]", Text = "이미 꺼져 있습니다.", Duration = 2})
            return
        end
        E.nameEspEnabled = false
        if E.nameEspConnection then E.nameEspConnection:Disconnect() E.nameEspConnection = nil end
        if E.nameEspRemovingConn then E.nameEspRemovingConn:Disconnect() E.nameEspRemovingConn = nil end
        removeAllNameEsp()
        StarterGui:SetCore("SendNotification", {Title = "[ NameESP 꺼짐 ]", Text = "이름 및 아이디 표시 비활성화", Duration = 2})
    end
end

local function removeStickyPartEsp()
    for _, p in pairs(Players:GetPlayers()) do
        local spawnFolder = Workspace:FindFirstChild(p.Name .. "SpawnedInToys")
        if spawnFolder then
            for _, item in pairs(spawnFolder:GetDescendants()) do
                if (item.Name == "NinjaKunai" or item.Name == "NinjaShuriken") and item:IsA("Model") then
                    local hl = item:FindFirstChild("StickyPartESP")
                    if hl then hl:Destroy() end
                end
                if (item.Name == "NinjaKunai" or item.Name == "NinjaShuriken") and item:IsA("BasePart") then
                    local hl = item:FindFirstChild("StickyPartESP")
                    if hl then hl:Destroy() end
                end
            end
            for _, item in pairs(spawnFolder:GetChildren()) do
                if (item.Name == "NinjaKunai" or item.Name == "NinjaShuriken") then
                    local hl = item:FindFirstChild("StickyPartESP")
                    if hl then hl:Destroy() end
                end
            end
        end
    end
    local plotItems = Workspace:FindFirstChild("PlotItems")
    if plotItems then
        for i = 1, 5 do
            local plotFolder = plotItems:FindFirstChild("Plot" .. i)
            if plotFolder then
                for _, item in pairs(plotFolder:GetChildren()) do
                    if item.Name == "NinjaKunai" or item.Name == "NinjaShuriken" then
                        local hl = item:FindFirstChild("StickyPartESP")
                        if hl then hl:Destroy() end
                    end
                end
                for _, item in pairs(plotFolder:GetDescendants()) do
                    if item.Name == "NinjaKunai" or item.Name == "NinjaShuriken" then
                        local hl = item:FindFirstChild("StickyPartESP")
                        if hl then hl:Destroy() end
                    end
                end
            end
        end
    end
end

local function applyStickyPartHighlight(item)
    if item:FindFirstChild("StickyPartESP") then return end
    local hl = getgenv().__DSN("Highlight")
    hl.Name = "StickyPartESP"
    hl.FillTransparency = 0.8
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillColor = Color3.fromRGB(255, 255, 255)
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = item
end

local function scanStickyPartEsp()
    for _, p in pairs(Players:GetPlayers()) do
        local spawnFolder = Workspace:FindFirstChild(p.Name .. "SpawnedInToys")
        if spawnFolder then
            for _, item in pairs(spawnFolder:GetChildren()) do
                if item.Name == "NinjaKunai" or item.Name == "NinjaShuriken" or item.Name == "ToolPencil" then
                    applyStickyPartHighlight(item)
                end
            end
        end
    end
    local plotItems = Workspace:FindFirstChild("PlotItems")
    if plotItems then
        for i = 1, 5 do
            local plotFolder = plotItems:FindFirstChild("Plot" .. i)
            if plotFolder then
                for _, item in pairs(plotFolder:GetChildren()) do
                    if item.Name == "NinjaKunai" or item.Name == "NinjaShuriken" or item.Name == "ToolPencil" then
                        applyStickyPartHighlight(item)
                    end
                end
                for _, item in pairs(plotFolder:GetDescendants()) do
                    if item.Name == "NinjaKunai" or item.Name == "NinjaShuriken" or item.Name == "ToolPencil" then
                        if item:IsA("Model") or item:IsA("BasePart") then
                            applyStickyPartHighlight(item)
                        end
                    end
                end
            end
        end
    end
end

local STICKY_TARGET_NAMES = {NinjaKunai = true, NinjaShuriken = true, ToolPencil = true}

local function isInWatchedFolder(item)
    local parent = item.Parent
    if not parent then return false end
    if parent.Name:match("SpawnedInToys$") then return true end
    local grandParent = parent.Parent
    if grandParent and grandParent.Name == "PlotItems" and parent.Name:match("^Plot%d+$") then return true end
    return false
end

local function toggleStickyPartEsp(state)
    if state then
        if E.stickyPartEspEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ StickyPartESP ]", Text = "이미 켜져 있습니다.", Duration = 2})
            return
        end
        E.stickyPartEspEnabled = true

        scanStickyPartEsp()

        if E.stickyPartEspConnection then E.stickyPartEspConnection:Disconnect() end
        E.stickyPartEspConnection = getgenv().__DST(Workspace.DescendantAdded:Connect(function(item)
            if not E.stickyPartEspEnabled then return end
            if not STICKY_TARGET_NAMES[item.Name] then return end
            if not (item:IsA("Model") or item:IsA("BasePart")) then return end
            if isInWatchedFolder(item) then
                getgenv().__DSTH(task.defer(function()
                    if E.stickyPartEspEnabled and item and item.Parent then
                        applyStickyPartHighlight(item)
                    end
                end))
            end
        end))

        StarterGui:SetCore("SendNotification", {Title = "[ StickyPartESP 켜짐 ]", Text = "NinjaKunai / NinjaShuriken ESP 활성화", Duration = 3})
    else
        if not E.stickyPartEspEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ StickyPartESP ]", Text = "이미 꺼져 있습니다.", Duration = 2})
            return
        end
        E.stickyPartEspEnabled = false
        if E.stickyPartEspConnection then E.stickyPartEspConnection:Disconnect() E.stickyPartEspConnection = nil end
        removeStickyPartEsp()
        StarterGui:SetCore("SendNotification", {Title = "[ StickyPartESP 꺼짐 ]", Text = "ESP가 제거되었습니다.", Duration = 2})
    end
end

local function onAutoResetCharacterAdded(char)
    if not L.autoResetEnabled then return end
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end

    if L.autoResetPending then
        L.autoResetPending = false
        L.autoResetForced = true
        task.wait()
        if hum and hum.Health > 0 then
            hum.Health = 0
        end
    end

    if L.autoResetDiedConnection then L.autoResetDiedConnection:Disconnect() end
    L.autoResetDiedConnection = getgenv().__DST(hum.Died:Connect(function()
        if not L.autoResetEnabled then return end
        if L.autoResetForced then
            L.autoResetForced = false
        else
            L.autoResetPending = true
        end
    end))
end

local function toggleAutoReset(state)
    if state then
        if L.autoResetEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ PCLD 삭제 ]", Text = "이미 켜져 있습니다.", Duration = 2})
            return
        end
        L.autoResetEnabled = true

        if L.autoResetCharConnection then L.autoResetCharConnection:Disconnect() end
        L.autoResetCharConnection = getgenv().__DST(lp.CharacterAdded:Connect(onAutoResetCharacterAdded))

        if lp.Character then
            onAutoResetCharacterAdded(lp.Character)
            local hum = lp.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                hum.Health = 0
            end
        end
        StarterGui:SetCore("SendNotification", {Title = "[ PCLD 삭제(AutoReset) ]", Text = "활성화됨: 부활 시 자동 재설정됩니다.", Duration = 3})
    else
        if not L.autoResetEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ PCLD 삭제 ]", Text = "이미 꺼져 있습니다.", Duration = 2})
            return
        end
        L.autoResetEnabled = false
        L.autoResetPending = false
        L.autoResetForced = false
        if L.autoResetDiedConnection then L.autoResetDiedConnection:Disconnect() L.autoResetDiedConnection = nil end
        if L.autoResetCharConnection then L.autoResetCharConnection:Disconnect() L.autoResetCharConnection = nil end
        StarterGui:SetCore("SendNotification", {Title = "[ PCLD 삭제 해제 ]", Text = "비활성화되었습니다.", Duration = 3})
    end
end

local function killLocalPlayer()
    local char = lp.Character
    if not char then return end
    local humanoid = char:FindFirstChildWhichIsA("Humanoid")
    if type(replicatesignal) == "function" then
        pcall(function() replicatesignal(lp.Kill) end)
    elseif humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Dead)
    else
        char:BreakJoints()
    end
end

local function onloopresetCharacterAdded(char)
    if not L.loopresetEnabled then return end
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    task.wait(0.1)
    if L.loopresetEnabled then
        killLocalPlayer()
    end
    if L.loopresetDiedConnection then L.loopresetDiedConnection:Disconnect() end
    L.loopresetDiedConnection = getgenv().__DST(hum.Died:Connect(function()
    end))
end

local function _autoWarningResetSetupChar(char)
    if not L.autoWarningResetEnabled then return end
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    L.autoWarningResetCount = 0
    L.autoWarningResetFirstTime = nil
    if L.autoWarningResetDiedConn then
        L.autoWarningResetDiedConn:Disconnect()
        L.autoWarningResetDiedConn = nil
    end
    L.autoWarningResetDiedConn = getgenv().__DST(hum.Died:Connect(function()
        L.autoWarningResetCount = 0
        L.autoWarningResetFirstTime = nil
    end))
end

local function toggleAutoWarningReset(state)
    if state then
        if L.autoWarningResetEnabled then
            game.StarterGui:SetCore("SendNotification", {
                Title = "[ 안내 ]",
                Text = "경고 방지 자동리셋이 이미 켜져 있습니다.",
                Duration = 2,
            })
            return
        end
        L.autoWarningResetEnabled = true
        L.autoWarningResetCount = 0
        L.autoWarningResetFirstTime = nil
        local rs = ReplicatedStorage
        if lp.Character then
            getgenv().__DSTH(task.spawn(_autoWarningResetSetupChar, lp.Character))
        end
        if L.autoWarningResetCharConn then
            L.autoWarningResetCharConn:Disconnect()
        end
        L.autoWarningResetCharConn = getgenv().__DST(lp.CharacterAdded:Connect(function(char)
            getgenv().__DSTH(task.spawn(_autoWarningResetSetupChar, char))
        end))
        L.autoWarningResetConnection = getgenv().__DST(rs.GameCorrectionEvents.GameCorrectionsNotify.OnClientEvent:Connect(function(Type)
            if not L.autoWarningResetEnabled then return end
            if Type == "Flying" then
                local char = lp.Character
                if not char then return end
                local hum, hrp = char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
                if not hum or not hrp then return end
                if hum.Health <= 0 then return end
                if L.autoWarningResetCount <= 0 then
                    L.autoWarningResetCount = 1
                    pcall(function() rs.CharacterEvents.Struggle:FireServer() end)
                    hum.Health = 0
                    hum:ChangeState(Enum.HumanoidStateType.Dead)
                    char:BreakJoints()
                end
            end
        end))
        game.StarterGui:SetCore("SendNotification", {
            Title = "[ 켜짐 ]",
            Text = "경고 방지 자동리셋이 활성화되었습니다. (경고 1회 감지 시 즉시 재설)",
            Duration = 3,
        })
    else
        if not L.autoWarningResetEnabled then
            game.StarterGui:SetCore("SendNotification", {
                Title = "[ 안내 ]",
                Text = "경고 방지 자동리셋이 이미 꺼져 있습니다.",
                Duration = 2,
            })
            return
        end
        L.autoWarningResetEnabled = false
        L.autoWarningResetCount = 0
        if L.autoWarningResetConnection then
            L.autoWarningResetConnection:Disconnect()
            L.autoWarningResetConnection = nil
        end
        if L.autoWarningResetCharConn then
            L.autoWarningResetCharConn:Disconnect()
            L.autoWarningResetCharConn = nil
        end
        if L.autoWarningResetDiedConn then
            L.autoWarningResetDiedConn:Disconnect()
            L.autoWarningResetDiedConn = nil
        end
        game.StarterGui:SetCore("SendNotification", {
            Title = "[ 종료 ]",
            Text = "경고 방지 자동리셋이 비활성화되었습니다.",
            Duration = 3,
        })
    end
end

local function toggleloopreset(state)
    if state then
        if L.loopresetEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ loopreset ]", Text = "이미 켜져 있습니다.", Duration = 2})
            return
        end
        L.loopresetEnabled = true
        if L.loopresetCharConnection then L.loopresetCharConnection:Disconnect() end
        L.loopresetCharConnection = getgenv().__DST(lp.CharacterAdded:Connect(onloopresetCharacterAdded))
        if lp.Character then
            getgenv().__DSTH(task.spawn(function()
                task.wait(0.1)
                if L.loopresetEnabled then killLocalPlayer() end
            end))
        end
        StarterGui:SetCore("SendNotification", {Title = "[ loopreset 켜짐 ]", Text = "부활할 때마다 자동으로 죽습니다.", Duration = 3})
    else
        if not L.loopresetEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ loopreset ]", Text = "이미 꺼져 있습니다.", Duration = 2})
            return
        end
        L.loopresetEnabled = false
        if L.loopresetDiedConnection then L.loopresetDiedConnection:Disconnect() L.loopresetDiedConnection = nil end
        if L.loopresetCharConnection then L.loopresetCharConnection:Disconnect() L.loopresetCharConnection = nil end
        StarterGui:SetCore("SendNotification", {Title = "[ loopreset 꺼짐 ]", Text = "비활성화되었습니다.", Duration = 3})
    end
end

M.xrayJob = 0
M.xrayApply = function(level)
    M.xrayJob = M.xrayJob + 1
    local job = M.xrayJob
    getgenv().__DSTH(task.spawn(function()
        local n, modelCache = 0, {}
        for _, v in ipairs(Workspace:GetDescendants()) do
            if job ~= M.xrayJob then return end
            if v:IsA("BasePart") then
                local par = v.Parent
                local skip = modelCache[par]
                if skip == nil then
                    skip = (par:FindFirstChildWhichIsA("Humanoid") or (par.Parent and par.Parent:FindFirstChildWhichIsA("Humanoid"))) and true or false
                    modelCache[par] = skip
                end
                if not skip then v.LocalTransparencyModifier = level end
            end
            n = n + 1
            if n % 300 == 0 then task.wait() end
        end
    end))
end

local function toggleNoclip(state)
    if state then
        if M.noclipConnection then M.noclipConnection:Disconnect() end
        local cachedNoclipParts, lastNoclipChar = {}, nil
        local changed = M.noclipChanged
        if not changed then
            changed = setmetatable({}, {__mode = "k"})
            M.noclipChanged = changed
        end
        M.noclipConnection = getgenv().__DST(RunService.Stepped:Connect(function()
            local char = lp.Character
            if not char then return end
            if char ~= lastNoclipChar then
                lastNoclipChar = char
                cachedNoclipParts = char:GetDescendants()
            end
            for _, v in ipairs(cachedNoclipParts) do
                if v:IsA("BasePart") and v.CanCollide then
                    changed[v] = true
                    v.CanCollide = false
                end
            end
        end))
    else
        if M.noclipConnection then M.noclipConnection:Disconnect() M.noclipConnection = nil end
        local changed = M.noclipChanged
        if changed then
            for part in pairs(changed) do
                if part.Parent then part.CanCollide = true end
            end
            M.noclipChanged = nil
        end
    end
end

local function toggleSpin(state, speed)
    if state then
        local newSpeed = tonumber(speed)

        if newSpeed then
            M.spinSpeed = newSpeed
        elseif not M.spinEnabled then
            M.spinSpeed = 10
        end

        if M.spinEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ Spin 속도 변경 ]", Text = "회전 속도: " .. M.spinSpeed, Duration = 2})
            return
        end

        M.spinEnabled = true

        if M.spinConnection then M.spinConnection:Disconnect() end
        M.spinConnection = getgenv().__DST(RunService.Heartbeat:Connect(function()
            if not M.spinEnabled then return end
            local char = lp.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(M.spinSpeed), 0)
        end))

        StarterGui:SetCore("SendNotification", {Title = "[ Spin 활성화 ]", Text = "회전 속도: " .. M.spinSpeed, Duration = 3})
    else
        M.spinEnabled = false
        if M.spinConnection then
            M.spinConnection:Disconnect()
            M.spinConnection = nil
        end
        StarterGui:SetCore("SendNotification", {Title = "[ Spin 해제 ]", Text = "회전이 멈췄습니다.", Duration = 3})
    end
end

M.startSpinGrab = function(speed)
    M.spinGrabSpeed = speed or 20
    M.spinGrabEnabled = true

    local grabPartsHandler = function(grabPartsClone)
        local grabPart = grabPartsClone:WaitForChild("GrabPart", 3)
        if not grabPart then return end

        if M.spinGrabConnection then
            M.spinGrabConnection:Disconnect()
            M.spinGrabConnection = nil
        end

        M.spinGrabCurrentPart = grabPart

        M.spinGrabConnection = getgenv().__DST(RunService.Heartbeat:Connect(function()
            if not M.spinGrabEnabled or not grabPart.Parent then
                if M.spinGrabConnection then
                    M.spinGrabConnection:Disconnect()
                    M.spinGrabConnection = nil
                end
                M.spinGrabCurrentPart = nil
                return
            end

            local isFixed = grabPart.Anchored
            if not isFixed then
                for _, p in ipairs(grabPart:GetConnectedParts()) do
                    if p.Anchored then
                        isFixed = true
                        break
                    end
                end
            end

            if isFixed then
                return
            end

            grabPart.AssemblyAngularVelocity = Vector3.new(0, M.spinGrabSpeed, 0)
        end))
    end

    if M.spinGrabWatcher then
        M.spinGrabWatcher:Disconnect()
        M.spinGrabWatcher = nil
    end

    M.spinGrabWatcher = getgenv().__DST(workspace.ChildAdded:Connect(function(child)
        if child.Name == "GrabParts" then
            grabPartsHandler(child)
        end
    end))
end

M.stopSpinGrab = function()
    M.spinGrabEnabled = false

    if M.spinGrabConnection then
        M.spinGrabConnection:Disconnect()
        M.spinGrabConnection = nil
    end
    if M.spinGrabWatcher then
        M.spinGrabWatcher:Disconnect()
        M.spinGrabWatcher = nil
    end
    if M.spinGrabCurrentPart and M.spinGrabCurrentPart.Parent then
        M.spinGrabCurrentPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end
    M.spinGrabCurrentPart = nil
end

local function performJerk()
    if not M.jerkEnabled then return end
    local character = lp.Character or lp.CharacterAdded:Wait()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if not M.jerkAnimTrack then
        local animation = getgenv().__DSN("Animation")
        animation.AnimationId = "rbxassetid://168268306"
        local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator")
        M.jerkAnimTrack = animator:LoadAnimation(animation)
    end

    M.jerkPlaying = not M.jerkPlaying

    if M.jerkPlaying then
        M.jerkAnimTrack:Play()
        while M.jerkPlaying and M.jerkAnimTrack do
            M.jerkAnimTrack.TimePosition = 0.3
            task.wait(0.1)
        end
    else
        M.jerkAnimTrack:Stop()
    end
end

local function toggleJerk(state)
    if state then
        if M.jerkEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ Jerk ]", Text = "이미 켜져 있습니다.", Duration = 2})
            return
        end
        M.jerkEnabled = true
        if not M.jerkInputConn then
            M.jerkInputConn = getgenv().__DST(UserInputService.InputBegan:Connect(function(input, gpe)
                if gpe then return end
                if input.KeyCode == Enum.KeyCode.Backquote then
                    performJerk()
                end
            end))
        end
        StarterGui:SetCore("SendNotification", {Title = "[ Jerk 켜짐 ]", Text = "` 키로 토글 가능합니다.", Duration = 3})
    else
        if not M.jerkEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ Jerk ]", Text = "이미 꺼져 있습니다.", Duration = 2})
            return
        end
        M.jerkEnabled = false
        M.jerkPlaying = false
        if M.jerkAnimTrack then
            pcall(function() M.jerkAnimTrack:Stop() end)
            M.jerkAnimTrack = nil
        end
        if M.jerkInputConn then
            M.jerkInputConn:Disconnect()
            M.jerkInputConn = nil
        end
        StarterGui:SetCore("SendNotification", {Title = "[ Jerk 꺼짐 ]", Text = "` 키 기능이 비활성화되었습니다.", Duration = 3})
    end
end

getgenv().__DST(lp.CharacterAdded:Connect(function()
    M.jerkAnimTrack = nil
    M.jerkPlaying = false
end))

local function startFlying(mode, speedInput)
    local desired = tonumber(speedInput)

    if M.flyConnection and M.currentFlyType == mode then
        if desired then
            M.flySpeed = desired * 10
            local modeName = (mode == "vfly") and "VFly" or "Fly"
            StarterGui:SetCore("SendNotification", {Title = "[ " .. modeName .. " 속도 변경 ]", Text = "속도: " .. desired, Duration = 2})
        else
            local modeName = (mode == "vfly") and "VFly" or "Fly"
            StarterGui:SetCore("SendNotification", {Title = "[ " .. modeName .. " ]", Text = "이미 켜져 있습니다.", Duration = 2})
        end
        return
    end
    if M.flyConnection then M.flyConnection:Disconnect() M.flyConnection = nil end
    if lp.Character then
        local hum = lp.Character:FindFirstChild("Humanoid")
        if hum then hum.PlatformStand = false end
        for _, obj in pairs(M.flyObjects) do if obj then obj:Destroy() end end
        M.flyObjects = {}
        for _, v in pairs(lp.Character:GetDescendants()) do
            if v.Name == "VelocityFly_BV" or v.Name == "VelocityFly_BG" then v:Destroy() end
        end
    end

    M.currentFlyType = mode
    M.lastFlyTargetPart = nil
    M.vflyCurrentVelocity = Vector3.new(0, 0, 0)
    M.vflyCurrentGyroCFrame = nil
    M.vflyCurrentTilt = 0
    M.vflyCurrentRoll = 0

    if mode == "vfly" or mode == "fly" then
        local vflyKeyMap = {[Enum.KeyCode.W] = "W", [Enum.KeyCode.A] = "A", [Enum.KeyCode.S] = "S", [Enum.KeyCode.D] = "D"}

        M.vflyKeyState = {W = false, A = false, S = false, D = false}
        if not UserInputService:GetFocusedTextBox() then
            for keyCode, k in pairs(vflyKeyMap) do
                if UserInputService:IsKeyDown(keyCode) then
                    M.vflyKeyState[k] = true
                end
            end
        end

        if M.vflyInputConn then M.vflyInputConn:Disconnect() end
        if M.vflyInputEndConn then M.vflyInputEndConn:Disconnect() end

        M.vflyInputConn = getgenv().__DST(UserInputService.InputBegan:Connect(function(input, gpe)
            local k = vflyKeyMap[input.KeyCode]
            if k and not gpe and not UserInputService:GetFocusedTextBox() then
                M.vflyKeyState[k] = true
            end
        end))
        M.vflyInputEndConn = getgenv().__DST(UserInputService.InputEnded:Connect(function(input)
            local k = vflyKeyMap[input.KeyCode]
            if k then M.vflyKeyState[k] = false end
        end))
    end

    if desired then
        M.flySpeed = desired * 10
    else
        if not M.flySpeed or M.flySpeed < 1 then M.flySpeed = 50 end
    end

    M.flyConnection = getgenv().__DST(RunService.RenderStepped:Connect(function(dt)
        local char = lp.Character
        if not char then return end

        local hum, hrp = char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end

        local targetPart, isInVehicle = hrp, false

        if mode == "vfly" and hum.SeatPart then
            targetPart = hum.SeatPart
            isInVehicle = true
            if targetPart.Parent:IsA("Model") and targetPart.Parent.PrimaryPart then
                targetPart = targetPart.Parent.PrimaryPart
            end

            if game.PlaceId == 6961824067 then
                M.currentVFlyVehicle = targetPart
                M.currentVFlyVehicle.Anchored = false
                local found = false
                for _, v in ipairs(M.vflyVehicles) do
                    if v == M.currentVFlyVehicle then found = true break end
                end
                if not found then table.insert(M.vflyVehicles, M.currentVFlyVehicle) end
            end
        else
            if game.PlaceId == 6961824067 and M.currentVFlyVehicle then
                pcall(function() M.currentVFlyVehicle.Anchored = true end)
                M.currentVFlyVehicle = nil
            end
        end

        if M.lastFlyTargetPart and M.lastFlyTargetPart ~= targetPart then
            for _, obj in pairs(M.flyObjects) do
                if obj and obj.Parent then obj:Destroy() end
            end
            M.flyObjects = {}
            if M.lastFlyTargetPart:FindFirstChild("VelocityFly_BV") then M.lastFlyTargetPart.VelocityFly_BV:Destroy() end
            if M.lastFlyTargetPart:FindFirstChild("VelocityFly_BG") then M.lastFlyTargetPart.VelocityFly_BG:Destroy() end
        end
        M.lastFlyTargetPart = targetPart

        local bv, bg = targetPart:FindFirstChild("VelocityFly_BV"), targetPart:FindFirstChild("VelocityFly_BG")

        if not bv then
            bv = getgenv().__DSN("BodyVelocity")
            bv.Name = "VelocityFly_BV"
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Velocity = Vector3.new(0, 0, 0)
            bv.Parent = targetPart
            table.insert(M.flyObjects, bv)
        end
        if not bg then
            bg = getgenv().__DSN("BodyGyro")
            bg.Name = "VelocityFly_BG"
            bg.P = isInVehicle and 3e4 or 9e4
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.CFrame = targetPart.CFrame
            bg.Parent = targetPart
            table.insert(M.flyObjects, bg)
        end

        local cam, moveDir = workspace.CurrentCamera, Vector3.new(0, 0, 0)
        local cf = cam.CFrame

        if not UserInputService:GetFocusedTextBox() then
            if M.vflyKeyState.W then moveDir = moveDir + cf.LookVector end
            if M.vflyKeyState.S then moveDir = moveDir - cf.LookVector end
            if M.vflyKeyState.A then moveDir = moveDir - cf.RightVector end
            if M.vflyKeyState.D then moveDir = moveDir + cf.RightVector end
        end
        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
        end

        local targetVelocity = moveDir * M.flySpeed
        local safeDt = math.clamp(dt or (1 / 60), 0, 0.1)
        local prevVelocity = M.vflyCurrentVelocity
        local smoothRate = (targetVelocity.Magnitude > prevVelocity.Magnitude) and M.vflyAccelRate or M.vflyDecelRate
        local lerpAlpha = 1 - math.exp(-smoothRate * safeDt)
        M.vflyCurrentVelocity = prevVelocity:Lerp(targetVelocity, lerpAlpha)

        if not M.vflyCurrentGyroCFrame then
            M.vflyCurrentGyroCFrame = cf
        end
        local rotAlpha = 1 - math.exp(-M.vflyRotationRate * safeDt)
        M.vflyCurrentGyroCFrame = M.vflyCurrentGyroCFrame:Lerp(cf, rotAlpha)

        local accel = (M.vflyCurrentVelocity - prevVelocity) / safeDt
        local forwardAccel = accel:Dot(cf.LookVector)
        local rightAccel = accel:Dot(cf.RightVector)
        local targetTilt = math.clamp(forwardAccel * M.vflyTiltStrength / M.flySpeed, -1, 1) * M.vflyTiltMax
        local targetRoll = math.clamp(rightAccel * M.vflyTiltStrength / M.flySpeed, -1, 1) * M.vflyTiltMax
        local tiltAlpha = 1 - math.exp(-M.vflyTiltSmoothRate * safeDt)
        M.vflyCurrentTilt = M.vflyCurrentTilt + (targetTilt - M.vflyCurrentTilt) * tiltAlpha
        M.vflyCurrentRoll = M.vflyCurrentRoll + (targetRoll - M.vflyCurrentRoll) * tiltAlpha

        bv.Velocity = M.vflyCurrentVelocity
        bg.CFrame = M.vflyCurrentGyroCFrame * CFrame.Angles(-M.vflyCurrentTilt, 0, -M.vflyCurrentRoll)

        if hum then
            if isInVehicle then
                hum.PlatformStand = false
            else
                hum.PlatformStand = true
            end
        end
    end))

    if M.suppressFlyStartNotify then
        M.suppressFlyStartNotify = false
    else
        local titleText = (mode == "vfly") and "[ VFly 켜짐 ]" or "[ Fly 켜짐 ]"
        StarterGui:SetCore("SendNotification", {Title = titleText, Text = "속도: " .. M.flySpeed, Duration = 3})
    end
end

local function stopFlying()
    if M.flyConnection then M.flyConnection:Disconnect() M.flyConnection = nil end
    if M.vflyInputConn then M.vflyInputConn:Disconnect() M.vflyInputConn = nil end
    if M.vflyInputEndConn then M.vflyInputEndConn:Disconnect() M.vflyInputEndConn = nil end
    M.vflyKeyState = {W = false, A = false, S = false, D = false}
    M.currentFlyType = nil

    for _, obj in pairs(M.flyObjects) do
        if obj and obj.Parent then obj:Destroy() end
    end
    M.flyObjects = {}
    M.lastFlyTargetPart = nil
    M.vflyCurrentVelocity = Vector3.new(0, 0, 0)
    M.vflyCurrentGyroCFrame = nil
    M.vflyCurrentTilt = 0
    M.vflyCurrentRoll = 0

    if game.PlaceId == 6961824067 then
        for _, veh in ipairs(M.vflyVehicles) do
            pcall(function()
                if veh and veh.Parent then veh.Anchored = false end
            end)
        end
        M.vflyVehicles = {}
        M.currentVFlyVehicle = nil
    end

    if lp.Character then
        for _, v in pairs(lp.Character:GetDescendants()) do
            if v.Name == "VelocityFly_BV" or v.Name == "VelocityFly_BG" then v:Destroy() end
        end
        local hum = lp.Character:FindFirstChild("Humanoid")
        if hum then hum.PlatformStand = false end
    end
    M.currentFlyType = nil
end

local function startTpwalk(step)
    M.tpwalkStep = tonumber(step) or 1
    if M.tpwalkStep <= 0 then M.tpwalkStep = 1 end

    if M.tpwalkEnabled then
        StarterGui:SetCore("SendNotification", {Title = "[ TpWalk 속도 변경 ]", Text = "0.1초당 " .. tostring(M.tpwalkStep) .. " studs", Duration = 3})
        return
    end

    if M.tpwalkConnection then M.tpwalkConnection:Disconnect() M.tpwalkConnection = nil end
    M.tpwalkEnabled = true

    local stopUntil = 0
    local function halt()
        if tick() >= stopUntil then return end
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and hum and hum.MoveDirection.Magnitude == 0 then
            local v = hrp.AssemblyLinearVelocity
            if v.X ~= 0 or v.Z ~= 0 then
                hrp.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
            end
        end
    end
    local hbConn = RunService.Heartbeat:Connect(function(dt)
        if not M.tpwalkEnabled then return end
        if F.cmdFocused then return end
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (hrp and hum) then return end
        local dir = hum.MoveDirection
        if dir.Magnitude > 0 then
            stopUntil = tick() + 0.5
            local v = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
            hrp.CFrame = hrp.CFrame + dir * M.tpwalkStep * dt * 10
        else
            halt()
        end
    end)
    local stConn = RunService.Stepped:Connect(function()
        if M.tpwalkEnabled then halt() end
    end)
    M.tpwalkConnection = getgenv().__DST({
        Connected = true,
        Disconnect = function(self)
            self.Connected = false
            hbConn:Disconnect()
            stConn:Disconnect()
        end
    })
    StarterGui:SetCore("SendNotification", {Title = "[ TpWalk 켜짐 ]", Text = "0.1초당 " .. tostring(M.tpwalkStep) .. " studs", Duration = 4})
end

local function stopTpwalk()
    M.tpwalkEnabled = false
    if M.tpwalkConnection then M.tpwalkConnection:Disconnect() M.tpwalkConnection = nil end
    StarterGui:SetCore("SendNotification", {Title = "[ TpWalk 꺼짐 ]", Text = "이제 텔레포트 보행이 중지됩니다.", Duration = 2})
end

local function toggleNoclipBarrier(state)
    local targetCollide, count = not state, 0
    for i = 1, 5 do
        local folder = Workspace:FindFirstChild("Plots") and Workspace.Plots:FindFirstChild("Plot" .. i) and Workspace.Plots["Plot" .. i]:FindFirstChild("Barrier")
        if folder then
            for _, v in pairs(folder:GetChildren()) do
                if v.Name == "PlotBarrier" and v:IsA("BasePart") then
                    v.CanCollide = targetCollide
                    count = count + 1
                end
            end
        end
    end

    if state then
        StarterGui:SetCore("SendNotification", {Title = "[ NoclipBarrier 켜짐 ]", Text = "플롯 장벽 충돌을 껐습니다.", Duration = 3})
    else
        StarterGui:SetCore("SendNotification", {Title = "[ NoclipBarrier 꺼짐 ]", Text = "플롯 장벽 충돌을 다시 켰습니다.", Duration = 3})
    end
end

local function toggleAntiFling(state)
    if state then
        if A.antiFlingEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ AntiFling ]", Text = "이미 켜져 있습니다.", Duration = 2})
            return
        end
        A.antiFlingEnabled = true
        A.antiFlingConstraints = {}

        local function ensureNoCollide(myPart, otherPart)
            A.antiFlingConstraints[myPart] = A.antiFlingConstraints[myPart] or {}
            if A.antiFlingConstraints[myPart][otherPart] then return end
            local ok, c = pcall(function()
                local nc = getgenv().__DSN("NoCollisionConstraint")
                nc.Name = "DShub_AntiFling"
                nc.Part0 = myPart
                nc.Part1 = otherPart
                nc.Parent = myPart
                return nc
            end)
            if ok and c then
                A.antiFlingConstraints[myPart][otherPart] = c
            end
        end

        local scanChar, scanParts, scanBuilt, scanDone, lastScan = nil, {}, 0, {}, 0
        local function scan()
            local now = tick()
            if now - lastScan < 0.05 then return end
            lastScan = now
            local char = lp.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            if char ~= scanChar or now - scanBuilt > 2 then
                scanChar, scanBuilt, scanParts, scanDone = char, now, {}, {}
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then scanParts[#scanParts + 1] = v end
                end
            end
            if #scanParts == 0 then return end

            local nearbyParts = Workspace:GetPartBoundsInRadius(hrp.Position, 20)
            for _, other in ipairs(nearbyParts) do
                if not scanDone[other] and not other.Anchored and not other:IsDescendantOf(char) then
                    for _, myPart in ipairs(scanParts) do
                        ensureNoCollide(myPart, other)
                    end
                    scanDone[other] = true
                end
            end
        end

        A.antiFlingConn = getgenv().__DST(RunService.Heartbeat:Connect(function()
            if A.antiFlingEnabled then pcall(scan) end
        end))

        A.antiFlingCharConn = getgenv().__DST(lp.CharacterAdded:Connect(function()
            A.antiFlingConstraints = {}
        end))

        StarterGui:SetCore("SendNotification", {Title = "[ AntiFling 켜짐 ]", Text = "장난감과 내 캐릭터 사이의 충돌이 꺼집니다.", Duration = 3})
    else
        if not A.antiFlingEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ AntiFling ]", Text = "이미 꺼져 있습니다.", Duration = 2})
            return
        end
        A.antiFlingEnabled = false

        if A.antiFlingConn then
            A.antiFlingConn:Disconnect()
            A.antiFlingConn = nil
        end
        if A.antiFlingCharConn then
            A.antiFlingCharConn:Disconnect()
            A.antiFlingCharConn = nil
        end
        if A.antiFlingConstraints then
            for _, tbl in pairs(A.antiFlingConstraints) do
                for _, c in pairs(tbl) do
                    pcall(function() c:Destroy() end)
                end
            end
            A.antiFlingConstraints = nil
        end

        StarterGui:SetCore("SendNotification", {Title = "[ AntiFling 꺼짐 ]", Text = "충돌이 다시 정상적으로 적용됩니다.", Duration = 3})
    end
end

local function toggleOceanWalk(state)
    local oceanModel = Workspace:FindFirstChild("Map")
        and Workspace.Map:FindFirstChild("AlwaysHereTweenedObjects")
        and Workspace.Map.AlwaysHereTweenedObjects:FindFirstChild("Ocean")
        and Workspace.Map.AlwaysHereTweenedObjects.Ocean:FindFirstChild("Object")
        and Workspace.Map.AlwaysHereTweenedObjects.Ocean.Object:FindFirstChild("ObjectModel")

    if oceanModel then
        local count = 0
        for _, v in pairs(oceanModel:GetDescendants()) do
            if v.Name == "Ocean" and v:IsA("BasePart") then
                v.CanCollide = state
                count = count + 1
            end
        end

        if state then
            StarterGui:SetCore("SendNotification", {Title = "[ OceanWalk 켜짐 ]", Text = "바다 위를 걸을 수 있습니다.", Duration = 3})
        else
            StarterGui:SetCore("SendNotification", {Title = "[ OceanWalk 꺼짐 ]", Text = "다시 물 속으로 빠집니다.", Duration = 3})
        end
    else
        StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "Ocean 경로를 찾을 수 없습니다.", Duration = 3})
    end
end

local function toggleAntiInPlots(state)
    if state and tostring(game.PlaceId):sub(1, 2) ~= "69" then
        StarterGui:SetCore("SendNotification", {Title = "[ AntiInPlots ]", Text = "이 게임에서는 사용할 수 없습니다.", Duration = 2})
        return
    end
    if state then
        if A.antiInPlotsEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ AntiInPlots ]", Text = "이미 켜져 있습니다.", Duration = 2})
            return
        end
        A.antiInPlotsEnabled = true

        getgenv().__DSTH(task.spawn(function()
            local plotItems = Workspace:WaitForChild("PlotItems", 5)
            local playersInPlots, mySpawnFolderName =
                plotItems and plotItems:WaitForChild("PlayersInPlots", 5),
                lp.Name .. "SpawnedInToys"
            local mySpawnFolder = Workspace:WaitForChild(mySpawnFolderName, 5)

            if not playersInPlots or not mySpawnFolder then
                StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "필수 폴더(PlotItems/SpawnedInToys)를 찾을 수 없습니다.", Duration = 3})
                A.antiInPlotsEnabled = false
                return
            end

            StarterGui:SetCore("SendNotification", {Title = "[ AntiInPlots 켜짐 ]", Text = "플롯 내부 플레이어를 납치합니다.", Duration = 3})

            while A.antiInPlotsEnabled do
                if not mySpawnFolder or not mySpawnFolder.Parent then
                    mySpawnFolder = Workspace:FindFirstChild(mySpawnFolderName)
                end

                if mySpawnFolder then
                    local playerList = Players:GetPlayers()
                    for i = 1, #playerList do
                        local player = playerList[i]
                        local char = player.Character
                        if char and char.Parent then
                            local inPlot = playersInPlots:FindFirstChild(player.Name)

                            if inPlot then
                                if char.Parent ~= mySpawnFolder then
                                    pcall(function()
                                        char.Parent = mySpawnFolder
                                    end)
                                end
                            end
                        end
                    end
                end
                task.wait(0.2)
            end
        end))
    else
        if not A.antiInPlotsEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ AntiInPlots ]", Text = "이미 꺼져 있습니다.", Duration = 2})
            return
        end
        A.antiInPlotsEnabled = false
        StarterGui:SetCore("SendNotification", {Title = "[ AntiInPlots 꺼짐 ]", Text = "기능이 비활성화되었습니다.", Duration = 3})
    end
end

local function safeGetCharacterParts(player)
    if not player then return nil end
    local char = player.Character
    if not char then return nil end
    local hrp, head = char:FindFirstChild("HumanoidRootPart"), char:FindFirstChild("Head")
    return char, hrp, head
end


local function TP(target, state)
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return false end

    if state == Z.isFaking then return true end
    Z.isFaking = state

    if state then
        Z.ocf = hrp.CFrame
        RunService:BindToRenderStep("ClientVision", Enum.RenderPriority.Camera.Value - 1, function()
            if hrp and Z.ocf then hrp.CFrame = Z.ocf end
        end)
        Z.hbc = getgenv().__DST(RunService.Heartbeat:Connect(function()
            if not target or not target.Character then return end
            local part = target.Character:FindFirstChild("HumanoidRootPart") or target.Character:FindFirstChild("Torso")
            if not part then return end

            local ping = 0.05
            pcall(function()
                local pingValue = Stats.Network.ServerStatsItem["Data Ping"]
                if pingValue then
                    ping = pingValue:GetValue() / 1000
                end
            end)

            local velocity = part.AssemblyLinearVelocity
            local speed = velocity.Magnitude
            local distance = (part.Position - hrp.Position).Magnitude
            local desiredPrediction = math.clamp((ping * 1.2) + (speed / 140) + (distance / 600), 0.03, 0.15)
            Z.tpPrediction = math.clamp(Z.tpPrediction + (desiredPrediction - Z.tpPrediction) * 0.18, 0.03, 0.15)

            local sCF = part.CFrame + (velocity * Z.tpPrediction)
            Z.ocf = hrp.CFrame
            if not hum.Sit then
                hum:ChangeState(Enum.HumanoidStateType.PlatformStanding)
            else
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
            hrp.CFrame = sCF
        end))
        return true
    else
        pcall(function() RunService:UnbindFromRenderStep("ClientVision") end)
        if Z.hbc then
            Z.hbc:Disconnect()
            Z.hbc = nil
        end
        if Z.ocf and hrp then
            hrp.CFrame = Z.ocf
        end
        return true
    end
end

M.newLeadPredictor = function()
    local ping, nextPing, lead = 0.05, 0, 0.06
    return function(part, hrp)
        local now = os.clock()
        if now >= nextPing then
            nextPing = now + 0.25
            pcall(function()
                local item = Stats.Network.ServerStatsItem["Data Ping"]
                if item then ping = item:GetValue() / 1000 end
            end)
        end
        local vel = part.AssemblyLinearVelocity
        local desired = math.clamp(ping * 1.2 + vel.Magnitude / 140 + (part.Position - hrp.Position).Magnitude / 600, 0.03, 0.15)
        lead = math.clamp(lead + (desired - lead) * 0.18, 0.03, 0.15)
        return vel * lead
    end
end

M.PcldCore = function(cfg)
    local Players, RunService = cfg.Players, cfg.RunService
    local trackers, avatarUserIdMap = cfg.trackers, cfg.avatarUserIdMap
    local LERP_SPEED = 13

    getgenv()[cfg.usedNamesKey] = {}
    getgenv()._pcldThumbCache = getgenv()._pcldThumbCache or {}
    getgenv()[cfg.runningKey] = true

    local thumbType = Enum.ThumbnailType.HeadShot
    local thumbSize = Enum.ThumbnailSize.Size48x48

    local function setTrackerAvatar(tracker, userId)
        if not tracker or not userId then return end
        local billboardGui = tracker:FindFirstChild("PcldNameTag", true)
        if not billboardGui then return end
        local avatarImage = billboardGui:FindFirstChild("AvatarImage")
        if not avatarImage then return end
        if avatarUserIdMap[avatarImage] == userId then return end
        avatarUserIdMap[avatarImage] = userId

        local cache = getgenv()._pcldThumbCache
        local cached = cache[userId]
        if cached then
            avatarImage.Image = cached
            avatarImage.Visible = true
            return
        end

        getgenv().__DSTH(task.spawn(function()
            local ok, content = pcall(function()
                return Players:GetUserThumbnailAsync(userId, thumbType, thumbSize)
            end)
            if ok and content then
                cache[userId] = content
                if avatarImage and avatarImage.Parent and avatarUserIdMap[avatarImage] == userId then
                    avatarImage.Image = content
                    avatarImage.Visible = true
                end
            end
        end))
    end

    local _pcldSet = {}
    local boolUserIdMap = {}
    local _pcldAddConn, _pcldRemConn

    local function _isPcld(obj)
        if not obj:IsA("BasePart") then return false end
        if obj.Name == "PlayerCharacterLocationDetector" then return true end
        if obj:FindFirstChild("PcldBoolOwner") then return true end
        if obj.Name:match("%[.*%] %(.*%)") then return true end
        return false
    end

    for _, obj in pairs(workspace:GetChildren()) do
        if _isPcld(obj) then
            _pcldSet[obj] = true
        end
    end

    _pcldAddConn = getgenv().__DST(workspace.ChildAdded:Connect(function(obj)
        if _isPcld(obj) then
            _pcldSet[obj] = true
        end
    end))
    _pcldRemConn = getgenv().__DST(workspace.ChildRemoved:Connect(function(obj)
        _pcldSet[obj] = nil
    end))

    getgenv()[cfg.addKey] = _pcldAddConn
    getgenv()[cfg.remKey] = _pcldRemConn

    local matcher = M.PcldTracker()
    local pcldOwner = M.PcldOwner({
        Players = Players,
        matcher = matcher,
        boolUserIdMap = boolUserIdMap,
        avatarUserIdMap = avatarUserIdMap,
        setTrackerAvatar = setTrackerAvatar,
    })
    local _ownerTick, OWNER_INTERVAL, _zero = 0, 0.3, CFrame.new(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)

    getgenv()[cfg.heartbeatKey] = getgenv().__DST(RunService.Heartbeat:Connect(function(dt)
        if not getgenv()[cfg.runningKey] then return end

        local now = tick()
        local doOwnerCheck = (now - _ownerTick) >= OWNER_INTERVAL
        if doOwnerCheck then
            _ownerTick = now
        end

        local usedNames, activePclds, alpha =
            {},
            {},
            math.min(1, LERP_SPEED * dt)

        matcher.track(now)
        pcldOwner.frame(now)

        if doOwnerCheck then
            pcldOwner.lockAll(_pcldSet, usedNames, _zero, now)
            pcldOwner.nearbyFallback(_pcldSet, _zero, now)
        end

        for pcld in pairs(_pcldSet) do
            if not pcld.Parent then
                _pcldSet[pcld] = nil
            elseif pcld.CFrame ~= _zero then
                activePclds[pcld] = true
                matcher.sample(pcld, now)

                local tracker = cfg.getOrCreateTracker(pcld)
                cfg.updateTracker(tracker, pcld, alpha, pcldOwner)

                if doOwnerCheck then
                    pcldOwner.resolve(pcld, tracker, usedNames)
                end
            else
                pcldOwner.seeZero(pcld, now)
            end
        end

        for pcld, tracker in pairs(trackers) do
            if not activePclds[pcld] then
                if tracker and tracker.Parent then
                    tracker:Destroy()
                end
                trackers[pcld] = nil
            end
        end
    end))

    return {pcldSet = _pcldSet}
end

M.PcldLines = function(cfg)
    local Players, RunService = cfg.Players, cfg.RunService
    local pcldSet, trackers = cfg.pcldSet, cfg.trackers

    local function anchorOf(tr)
        if tr:IsA("BasePart") then return tr end
        return tr.PrimaryPart or tr:FindFirstChild("Torso")
    end

    local lineLP = Players.LocalPlayer
    local lineId = (getgenv()[cfg.lineIdKey] or 0) + 1
    getgenv()[cfg.lineIdKey] = lineId
    getgenv().__DSTH(task.spawn(function()
        local lineBeam, lineA0, lineA1
        local conns = {}
        local lost = false
        local function clearLine()
            for _, c in ipairs(conns) do c:Disconnect() end
            conns = {}
            if lineBeam then lineBeam:Destroy() end
            if lineA0 then lineA0:Destroy() end
            if lineA1 then lineA1:Destroy() end
            lineBeam, lineA0, lineA1 = nil, nil, nil
            lost = false
        end
        local function isMinePcld(obj)
            if not obj:IsA("BasePart") then return false end
            local tag = "( " .. lineLP.Name .. " )"
            if obj.Name:find(tag, 1, true) then return true end
            for _, child in ipairs(obj:GetChildren()) do
                if child:IsA("BoolValue") then
                    if child:GetAttribute("OwnerUserId") == lineLP.UserId then return true end
                    if child.Name:find(tag, 1, true) then return true end
                end
            end
            return false
        end
        local function connectLine(hrp, target, tracker, anchor)
            lineA0 = getgenv().__DSN("Attachment")
            lineA0.Name = "PcldLineA0"
            lineA0.Parent = hrp
            lineA1 = getgenv().__DSN("Attachment")
            lineA1.Name = "PcldLineA1"
            lineA1.Parent = anchor
            lineBeam = getgenv().__DSN("Beam")
            lineBeam.Name = "PcldLine"
            lineBeam.Attachment0 = lineA0
            lineBeam.Attachment1 = lineA1
            lineBeam.Color = ColorSequence.new(Color3.new(1, 1, 1))
            lineBeam.Width0 = 0.15
            lineBeam.Width1 = 0.15
            lineBeam.FaceCamera = true
            lineBeam.LightEmission = 1
            lineBeam.Transparency = NumberSequence.new(0)
            lineBeam.Segments = 1
            lineBeam.Enabled = (hrp.Position - anchor.Position).Magnitude >= 10
            lineBeam.Parent = anchor
            lost = false
            table.insert(conns, getgenv().__DST(tracker.AncestryChanged:Connect(function(_, parent)
                if not parent then lost = true end
            end)))
            table.insert(conns, getgenv().__DST(target.AncestryChanged:Connect(function(_, parent)
                if not parent then lost = true end
            end)))
            table.insert(conns, getgenv().__DST(target.ChildRemoved:Connect(function(child)
                if child:IsA("BoolValue") then lost = true end
            end)))
            table.insert(conns, getgenv().__DST(target:GetPropertyChangedSignal("Name"):Connect(function()
                if not isMinePcld(target) then lost = true end
            end)))
            table.insert(conns, getgenv().__DST(hrp.AncestryChanged:Connect(function(_, parent)
                if not parent then lost = true end
            end)))
            table.insert(conns, getgenv().__DST(lineLP.CharacterAdded:Connect(function()
                lost = true
            end)))
            table.insert(conns, getgenv().__DST(RunService.Heartbeat:Connect(function()
                if lineBeam and hrp.Parent and tracker.Parent and anchor.Parent then
                    lineBeam.Enabled = (hrp.Position - anchor.Position).Magnitude >= 10
                end
            end)))
        end
        while getgenv()[cfg.runningKey] and getgenv()[cfg.lineIdKey] == lineId do
            if lineBeam and (lost or not lineBeam.Parent) then
                clearLine()
            end
            if not lineBeam then
                local char = lineLP.Character
                local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
                if hrp then
                    for pcld in pairs(pcldSet) do
                        if pcld.Parent and isMinePcld(pcld) then
                            local pcldTracker = trackers[pcld]
                            if pcldTracker and pcldTracker.Parent then
                                local pcldAnchor = anchorOf(pcldTracker)
                                if pcldAnchor then
                                    connectLine(hrp, pcld, pcldTracker, pcldAnchor)
                                    break
                                end
                            end
                        end
                    end
                end
            end
            if lineBeam then
                task.wait(0.5)
            else
                task.wait(0.2)
            end
        end
        clearLine()
    end))

    local otherLines = {}
    local function destroyOther(plr)
        local e = otherLines[plr]
        if e then
            if e.beam then e.beam:Destroy() end
            if e.a0 then e.a0:Destroy() end
            if e.a1 then e.a1:Destroy() end
            otherLines[plr] = nil
        end
    end
    local function playerFromName(text)
        local nm = text:match("%(%s*([^%(%)]-)%s*%)%s*$")
        if nm then
            local plr = Players:FindFirstChild(nm)
            if plr and plr:IsA("Player") then return plr end
        end
        return nil
    end
    local function ownerOfPcld(obj)
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("BoolValue") then
                local uid = child:GetAttribute("OwnerUserId")
                local plr = uid and Players:GetPlayerByUserId(uid)
                if plr then return plr end
                plr = playerFromName(child.Name)
                if plr then return plr end
            end
        end
        return playerFromName(obj.Name)
    end
    getgenv().__DSTH(task.spawn(function()
        while getgenv()[cfg.runningKey] and getgenv()[cfg.lineIdKey] == lineId do
            local desired = {}
            for pcld in pairs(pcldSet) do
                if pcld.Parent then
                    local plr = ownerOfPcld(pcld)
                    if plr and plr ~= lineLP then
                        local tr = trackers[pcld]
                        local trAnchor = tr and tr.Parent and anchorOf(tr)
                        if trAnchor then
                            desired[plr] = { pcld, trAnchor }
                        end
                    end
                end
            end
            for plr in pairs(otherLines) do
                if not desired[plr] then
                    destroyOther(plr)
                end
            end
            for plr, pair in pairs(desired) do
                local char = plr.Character
                local hrp = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
                if hrp then
                    local e = otherLines[plr]
                    if e and not (e.beam.Parent and e.a0.Parent == hrp and e.a1.Parent == pair[2]) then
                        destroyOther(plr)
                        e = nil
                    end
                    if not e then
                        local oa0 = getgenv().__DSN("Attachment")
                        oa0.Name = "PcldLineA0"
                        oa0.Parent = hrp
                        local oa1 = getgenv().__DSN("Attachment")
                        oa1.Name = "PcldLineA1"
                        oa1.Parent = pair[2]
                        local ob = getgenv().__DSN("Beam")
                        ob.Name = "PcldLine"
                        ob.Attachment0 = oa0
                        ob.Attachment1 = oa1
                        ob.Color = ColorSequence.new(Color3.new(1, 1, 1))
                        ob.Width0 = 0.15
                        ob.Width1 = 0.15
                        ob.FaceCamera = true
                        ob.LightEmission = 1
                        ob.Transparency = NumberSequence.new(0)
                        ob.Segments = 1
                        ob.Enabled = false
                        ob.Parent = hrp
                        e = { beam = ob, a0 = oa0, a1 = oa1 }
                        otherLines[plr] = e
                    end
                    e.beam.Enabled = (hrp.Position - pair[1].Position).Magnitude > 10
                else
                    destroyOther(plr)
                end
            end
            task.wait(0.3)
        end
        for plr in pairs(otherLines) do
            destroyOther(plr)
        end
    end))
end

M.PcldTracker = function()
    local Players = game:GetService("Players")
    local C = {
        Gate = 10,
        Sticky = 3,
        CostAlpha = 0.4,
        CostCap = 100,
        StaleAge = 0.5,
        SeenAge = 0.5,
        HistKeep = 1.2,
        TrackInterval = 0.1,
        TeleportDist = 40,
        TeleportSpeed = 500,
        StillResample = 0.25,
        HistoryTime = 2,
        HintInterval = 2,
        OrderMinAnchors = 3,
        OrderConsistency = 0.9
    }
    local pclds, tracks, pairCost = {}, {}, {}
    local known = setmetatable({}, {__mode = "k"})
    local lastTrack = 0

    local function ReadAge(part)
        if not part then return nil end
        local ok, v = pcall(function() return part.ReceiveAge end)
        if ok and type(v) == "number" then return v end
        if gethiddenproperty then
            local ok2, v2 = pcall(gethiddenproperty, part, "ReceiveAge")
            if ok2 and type(v2) == "number" then return v2 end
        end
        return nil
    end

    local function CharParts(p)
        local char = p.Character
        if not char or not char.Parent then return nil end
        local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
        if not hrp then return nil end
        return char, hrp
    end

    local function HeldBy(char)
        local head = char:FindFirstChild("Head")
        local po = head and head:FindFirstChild("PartOwner")
        if po then
            if po:IsA("StringValue") then
                if po.Value ~= "" then return po.Value end
                return nil
            end
            return true
        end
        return nil
    end

    local function GetTrack(p)
        local t = tracks[p]
        if not t then
            t = {player = p, pcld = nil, hist = {}}
            tracks[p] = t
        end
        return t
    end

    local function Ensure(part)
        local e = pclds[part]
        if not e then
            e = {
                part = part,
                samples = {},
                owner = nil,
                pairing = nil,
                confident = false,
                locked = false,
                seed = false,
                order = nil,
                hintT = 0,
                seen = 0
            }
            pclds[part] = e
        end
        return e
    end

    local function SamplePcld(e, now)
        e.seen = now
        local pos = e.part.CFrame.Position
        if pos.X ~= pos.X then return end
        local s = e.samples
        local last = s[#s]
        if not last then
            s[1] = {t = now, pos = pos}
            return
        end
        local moved = (pos - last.pos).Magnitude
        if moved > 0.01 then
            local dtm = math.max(now - last.t, 1e-3)
            if moved > C.TeleportDist and moved / dtm > C.TeleportSpeed then
                e.samples = {{t = now, pos = pos}}
                return
            end
            s[#s + 1] = {t = now, pos = pos}
        elseif now - last.t >= C.StillResample then
            s[#s + 1] = {t = now, pos = pos}
        end
        while #s > 3 and now - s[1].t > C.HistoryTime do table.remove(s, 1) end
    end

    local function Hungarian(cost, N)
        local INF = math.huge
        local u, v, p, way = {}, {}, {}, {}
        for i = 0, N do u[i] = 0 end
        for j = 0, N do
            v[j] = 0
            p[j] = 0
            way[j] = 0
        end
        for i = 1, N do
            p[0] = i
            local j0 = 0
            local minv, used = {}, {}
            for j = 0, N do
                minv[j] = INF
                used[j] = false
            end
            repeat
                used[j0] = true
                local i0 = p[j0]
                local delta = INF
                local j1 = 0
                for j = 1, N do
                    if not used[j] then
                        local cur = cost[i0][j] - u[i0] - v[j]
                        if cur < minv[j] then
                            minv[j] = cur
                            way[j] = j0
                        end
                        if minv[j] < delta then
                            delta = minv[j]
                            j1 = j
                        end
                    end
                end
                for j = 0, N do
                    if used[j] then
                        u[p[j]] = u[p[j]] + delta
                        v[j] = v[j] - delta
                    else
                        minv[j] = minv[j] - delta
                    end
                end
                j0 = j1
            until p[j0] == 0
            repeat
                local j1 = way[j0]
                p[j0] = p[j1]
                j0 = j1
            until j0 == 0
        end
        local assign = {}
        for j = 1, N do
            if p[j] ~= 0 then assign[p[j]] = j end
        end
        return assign
    end

    local function TrailDist(e, hist)
        local last = e.samples[#e.samples]
        if not last then return nil end
        local best = math.huge
        for _, h in ipairs(hist) do
            if h.t >= last.t - 0.6 and h.t <= last.t + 0.1 then
                local d = (h.pos - last.pos).Magnitude
                if d < best then best = d end
            end
        end
        if best == math.huge then return nil end
        return best
    end

    local function Pair(t, e, how, confident)
        if t.pcld and t.pcld ~= e and t.pcld.owner == t.player then t.pcld.owner = nil end
        e.owner = t.player
        e.pairing = how
        e.confident = confident
        if confident then known[t.player] = true end
        t.pcld = e
    end

    local function ProbeOwner(e)
        local part = e.part
        local cands = {}
        local okA, attrs = pcall(function() return part:GetAttributes() end)
        if okA and type(attrs) == "table" then
            for k, val in pairs(attrs) do
                table.insert(cands, k)
                if val ~= nil then table.insert(cands, val) end
            end
        end
        for _, ch in ipairs(part:GetChildren()) do
            table.insert(cands, ch.Name)
            if ch:IsA("ValueBase") then
                local okV, val = pcall(function() return ch.Value end)
                if okV and val ~= nil then table.insert(cands, val) end
            end
        end
        if #cands == 0 then return nil end
        for _, p in ipairs(Players:GetPlayers()) do
            local uid = p.UserId
            local char = p.Character
            for _, c in ipairs(cands) do
                if c == p or (char ~= nil and c == char) or c == p.Name or c == uid or c == tostring(uid) then
                    return p
                end
            end
        end
        return nil
    end

    local function CollectOrphans()
        local ts, es = {}, {}
        for _, p in ipairs(Players:GetPlayers()) do
            local t = tracks[p]
            if t and not t.pcld then table.insert(ts, t) end
        end
        for _, e in pairs(pclds) do
            if e.part.Parent and #e.samples > 0 and not e.owner then table.insert(es, e) end
        end
        return ts, es
    end

    local function ResolveOrder(orphanT, orphanE)
        local order = 0
        for _, c in ipairs(workspace:GetChildren()) do
            local e = pclds[c]
            if e then
                order = order + 1
                e.order = order
            end
        end
        local pIdx = {}
        for i, p in ipairs(Players:GetPlayers()) do pIdx[p] = i end
        local anchors = {}
        for _, e in pairs(pclds) do
            if e.owner and e.confident and e.order and pIdx[e.owner] then
                table.insert(anchors, {eo = e.order, po = pIdx[e.owner]})
            end
        end
        if #anchors < C.OrderMinAnchors then return end
        table.sort(anchors, function(a, b) return a.eo < b.eo end)
        local inc = 0
        for i = 2, #anchors do
            if anchors[i].po > anchors[i - 1].po then inc = inc + 1 end
        end
        if inc / (#anchors - 1) < C.OrderConsistency then return end
        local gE, gT = {}, {}
        for _, e in ipairs(orphanE) do
            if e.order then
                local g = 0
                for _, a in ipairs(anchors) do
                    if a.eo < e.order then g = g + 1 end
                end
                gE[g] = gE[g] or {}
                table.insert(gE[g], e)
            end
        end
        for _, t in ipairs(orphanT) do
            local pi = pIdx[t.player]
            if pi then
                local g = 0
                for _, a in ipairs(anchors) do
                    if a.po < pi then g = g + 1 end
                end
                gT[g] = gT[g] or {}
                table.insert(gT[g], t)
            end
        end
        for g, es in pairs(gE) do
            local ts = gT[g]
            if ts and #ts == #es then
                table.sort(es, function(a, b) return a.order < b.order end)
                table.sort(ts, function(a, b) return pIdx[a.player] < pIdx[b.player] end)
                for i = 1, #es do
                    if not es[i].owner and not ts[i].pcld then Pair(ts[i], es[i], "order", false) end
                end
            end
        end
    end

    local function MatchStep(now)
        for part, e in pairs(pclds) do
            if not part.Parent then
                local t = e.owner and tracks[e.owner]
                if t and t.pcld == e then t.pcld = nil end
                for _, row in pairs(pairCost) do row[e] = nil end
                pclds[part] = nil
            end
        end
        for _, t in pairs(tracks) do
            local e = t.pcld
            if e and pclds[e.part] ~= e then t.pcld = nil end
        end
        for _, e in pairs(pclds) do
            local t = e.owner and tracks[e.owner]
            if not (t and t.pcld == e) then
                e.owner = nil
                e.pairing = nil
                e.confident = false
            end
        end

        local rows, lockedPcld = {}, {}
        for _, p in ipairs(Players:GetPlayers()) do
            local t = GetTrack(p)
            local char, hrp = CharParts(p)
            if char then
                local locked = false
                if t.pcld and t.pcld.locked then
                    locked = true
                elseif HeldBy(char) then
                    locked = true
                elseif t.pcld then
                    local age = ReadAge(hrp.AssemblyRootPart or hrp)
                    locked = age ~= nil and age > C.StaleAge
                end
                if locked then
                    if t.pcld then lockedPcld[t.pcld] = true end
                else
                    table.insert(rows, {p = p, t = t})
                end
            end
        end

        local cols = {}
        for _, e in pairs(pclds) do
            if e.part.Parent and #e.samples > 0 and not e.locked and not lockedPcld[e] and now - e.seen < C.SeenAge then
                table.insert(cols, e)
            end
        end

        for _, r in ipairs(rows) do
            local row = pairCost[r.p]
            if not row then
                row = {}
                pairCost[r.p] = row
            end
            for _, e in ipairs(cols) do
                local dd = TrailDist(e, r.t.hist)
                if dd then
                    dd = math.min(dd, C.CostCap)
                    local c = row[e]
                    if c then
                        row[e] = c + (dd - c) * C.CostAlpha
                    else
                        row[e] = dd
                    end
                end
            end
        end

        local nR, nC = #rows, #cols
        if nR > 0 and nC > 0 then
            local N = math.max(nR, nC)
            local BIG = 1e6
            local cost = {}
            for i = 1, N do
                local line = {}
                local r = rows[i]
                local row = r and pairCost[r.p]
                for j = 1, N do
                    local e = cols[j]
                    local c = BIG
                    if r and e and row and row[e] and row[e] <= C.Gate then
                        c = row[e]
                        if r.t.pcld == e then c = c - C.Sticky end
                    end
                    line[j] = c
                end
                cost[i] = line
            end
            local assign = Hungarian(cost, N)
            for i = 1, nR do
                local j = assign[i]
                if j and j <= nC and cost[i][j] < BIG then
                    local r = rows[i]
                    local e = cols[j]
                    if r.t.pcld ~= e then
                        local prevT = e.owner and tracks[e.owner]
                        if prevT and prevT ~= r.t and prevT.pcld == e then prevT.pcld = nil end
                        Pair(r.t, e, "track", true)
                    end
                end
            end
        end

        for _, r in ipairs(rows) do
            local e = r.t.pcld
            if e then
                local row = pairCost[r.p]
                local c = row and row[e]
                if c and c <= C.Gate then
                    e.confident = true
                    e.pairing = "track"
                end
            end
        end

        local orphanT, orphanE = CollectOrphans()
        if #orphanT > 0 and #orphanE > 0 then
            for _, e in ipairs(orphanE) do
                if not e.owner and now - e.hintT >= C.HintInterval then
                    e.hintT = now
                    local hp = ProbeOwner(e)
                    local ht = hp and tracks[hp]
                    if ht and not ht.pcld then Pair(ht, e, "hint", true) end
                end
            end
            orphanT, orphanE = CollectOrphans()
            if #orphanT > 0 and #orphanE > 0 then
                ResolveOrder(orphanT, orphanE)
                orphanT, orphanE = CollectOrphans()
                if #orphanT == 1 and #orphanE == 1 then
                    Pair(orphanT[1], orphanE[1], "elim", false)
                end
            end
        end
    end

    local api = {}

    api.sample = function(part, now)
        SamplePcld(Ensure(part), now)
    end

    api.track = function(now)
        if now - lastTrack < C.TrackInterval then return end
        lastTrack = now
        for _, p in ipairs(Players:GetPlayers()) do
            local t = GetTrack(p)
            local char, hrp = CharParts(p)
            if char then
                t.hist[#t.hist + 1] = {t = now, pos = hrp.Position}
            end
            while #t.hist > 0 and now - t.hist[1].t > C.HistKeep do table.remove(t.hist, 1) end
        end
        for p, t in pairs(tracks) do
            if not p.Parent then
                local e = t.pcld
                if e and e.owner == p then
                    e.owner = nil
                    e.pairing = nil
                    e.confident = false
                    e.locked = false
                end
                tracks[p] = nil
                pairCost[p] = nil
            end
        end
    end

    api.begin = function()
        for _, e in pairs(pclds) do e.seed = false end
    end

    api.lock = function(part, userId)
        if type(userId) ~= "number" then return end
        local p = Players:GetPlayerByUserId(userId)
        if not p then return end
        local e = Ensure(part)
        local t = GetTrack(p)
        local oldE = t.pcld
        if oldE and oldE ~= e then
            oldE.owner = nil
            oldE.pairing = nil
            oldE.confident = false
            oldE.locked = false
        end
        if e.owner and e.owner ~= p then
            local po = tracks[e.owner]
            if po and po.pcld == e then po.pcld = nil end
        end
        e.owner = p
        e.pairing = "dshub"
        e.confident = true
        e.locked = true
        e.seed = true
        known[p] = true
        t.pcld = e
    end

    api.step = function(now)
        for _, e in pairs(pclds) do
            if e.locked and not e.seed then
                e.locked = false
                local t = e.owner and tracks[e.owner]
                if t and t.pcld == e then t.pcld = nil end
                e.owner = nil
                e.pairing = nil
                e.confident = false
            end
        end
        pcall(MatchStep, now)
    end

    api.known = function(p)
        return known[p] == true
    end

    api.teleported = function(p)
        local t = tracks[p]
        if not t then return false end
        local h = t.hist
        for i = 2, #h do
            if (h[i].pos - h[i - 1].pos).Magnitude >= C.TeleportDist then return true end
        end
        return false
    end

    api.trail = function(part, p)
        local e = pclds[part]
        local t = tracks[p]
        if not e or not t then return nil end
        local d = TrailDist(e, t.hist)
        if not d then return nil end
        return math.min(d, C.CostCap)
    end

    api.owner = function(part)
        local e = pclds[part]
        if not e or not e.owner or not e.confident or e.locked then return nil end
        if not e.owner.Parent then return nil end
        if api.teleported(e.owner) then return nil end
        if e.pairing == "track" then
            local row = pairCost[e.owner]
            local c = row and row[e]
            if not c or c > C.Gate then return nil end
            for _, op in ipairs(Players:GetPlayers()) do
                if op ~= e.owner then
                    local ot = tracks[op]
                    local od = ot and TrailDist(e, ot.hist)
                    if od and od <= C.Gate then return nil end
                end
            end
        elseif e.pairing ~= "hint" then
            return nil
        end
        return e.owner
    end

    return api
end

M.PcldOwner = function(env)
    local Players = env.Players
    local matcher = env.matcher
    local boolUserIdMap = env.boolUserIdMap
    local avatarUserIdMap = env.avatarUserIdMap
    local setTrackerAvatar = env.setTrackerAvatar
    local api = {}

    local function singleBool(pcld)
        local boolValue, count = nil, 0
        for _, child in pairs(pcld:GetChildren()) do
            if child:IsA("BoolValue") then
                count = count + 1
                boolValue = child
            end
        end
        return boolValue, count
    end

    local function userIdOf(boolValue)
        local userId = boolUserIdMap[boolValue]
        if not userId then
            userId = boolValue:GetAttribute("OwnerUserId")
            if userId then
                boolUserIdMap[boolValue] = userId
            end
        end
        if not userId then
            local _, uname = boolValue.Name:match("%[ (.-) %] %( (.-) %)")
            local matchedPlayer = uname and Players:FindFirstChild(uname)
            if matchedPlayer then
                userId = matchedPlayer.UserId
                boolUserIdMap[boolValue] = userId
            end
        end
        return userId
    end

    local ZERO_SETTLE, ZERO_WINDOW, EVENT_LIFE = 3, 2, 8
    local VERIFY_MIN, VERIFY_STEP = 4, 0.1
    local VERIFY_GATE, VERIFY_MARGIN, VERIFY_ALPHA = 10, 3, 0.35
    local ZERO_CF = CFrame.new()
    local createdAt = tick()
    local zeros, events, seen = {}, {}, {}
    local pending, pendingOf, boundNow = {}, {}, {}
    local releasedAt = setmetatable({}, {__mode = "k"})
    local RELEASE_HOLD = 1

    local function isFreshPcld(pcld)
        if pcld.Name ~= "PlayerCharacterLocationDetector" then return false end
        local _, count = singleBool(pcld)
        return count == 0
    end

    local function claim(pcld, player)
        local ownerName = "[ " .. tostring(player.DisplayName or player.Name) .. " ] ( " .. tostring(player.Name) .. " )"
        local newBool = getgenv().__DSN("BoolValue")
        newBool.Name = ownerName
        boolUserIdMap[newBool] = player.UserId
        newBool.Parent = pcld
        newBool:SetAttribute("OwnerUserId", player.UserId)
        pcld.Name = ownerName
        boundNow[player.UserId] = pcld
        local boundChar = player.Character
        getgenv().__DSTH(task.spawn(function()
            while newBool.Parent do
                local char = player.Character
                if boundChar == nil then boundChar = char end
                if not Players:FindFirstChild(player.Name) or char ~= boundChar then
                    if pcld.Parent then
                        pcld.Name = "PlayerCharacterLocationDetector"
                        releasedAt[pcld] = tick()
                    end
                    boolUserIdMap[newBool] = nil
                    if boundNow[player.UserId] == pcld then boundNow[player.UserId] = nil end
                    newBool:Destroy()
                    break
                end
                task.wait(0.1)
            end
        end))
    end

    local function hasPcld(player)
        local pc = boundNow[player.UserId]
        if not pc or not pc.Parent then return false end
        local boolValue, count = singleBool(pc)
        return count == 1 and boolValue ~= nil and userIdOf(boolValue) == player.UserId
    end

    local function startPending(pcld, player, now)
        local old = pendingOf[player]
        if old then pending[old] = nil end
        pending[pcld] = {p = player, char = player.Character, t0 = now, nextS = now, ema = {}, n = {}}
        pendingOf[player] = pcld
    end

    local function sampleEntry(pcld, en)
        for _, q in ipairs(Players:GetPlayers()) do
            local c = matcher.trail(pcld, q)
            if c then
                local prev = en.ema[q]
                en.ema[q] = prev and (prev + (c - prev) * VERIFY_ALPHA) or c
                en.n[q] = (en.n[q] or 0) + 1
            end
        end
    end

    local function judge(en)
        local ownN = en.n[en.p] or 0
        if ownN < VERIFY_MIN then return "wait" end
        local own = en.ema[en.p]
        local best, bestP
        for q, v in pairs(en.ema) do
            if q ~= en.p and q.Parent and (en.n[q] or 0) >= VERIFY_MIN and (not best or v < best) then
                best, bestP = v, q
            end
        end
        if own <= VERIFY_GATE and (not best or best > VERIFY_GATE or best - own >= VERIFY_MARGIN) then
            return "ok"
        end
        if best and best <= VERIFY_GATE and (own > VERIFY_GATE or own - best >= VERIFY_MARGIN) then
            return "other", bestP
        end
        return "wait"
    end

    local function finalize(pcld, en, player)
        pending[pcld] = nil
        if pendingOf[en.p] == pcld then pendingOf[en.p] = nil end
        if player and player.Parent and pcld.Parent and isFreshPcld(pcld) then
            claim(pcld, player)
        end
    end

    local function processPending(now)
        for pcld, en in pairs(pending) do
            local p = en.p
            if not pcld.Parent or not p.Parent or p.Character ~= en.char or not isFreshPcld(pcld) then
                pending[pcld] = nil
                if pendingOf[p] == pcld then pendingOf[p] = nil end
            else
                if now >= en.nextS and pcld.CFrame ~= ZERO_CF then
                    en.nextS = now + VERIFY_STEP
                    sampleEntry(pcld, en)
                end
                local verdict, q = judge(en)
                if verdict == "ok" then
                    finalize(pcld, en, p)
                elseif verdict == "other" and not (matcher.teleported(p) or matcher.teleported(q)) then
                    local qPcld = pendingOf[q]
                    local en2 = qPcld and pending[qPcld]
                    if en2 then
                        local c2p, c2q = en2.ema[p], en2.ema[q]
                        local c1p, c1q = en.ema[p], en.ema[q]
                        if c1p and c1q and c2p and c2q and (en2.n[p] or 0) >= VERIFY_MIN and (en2.n[q] or 0) >= VERIFY_MIN and (c1q + c2p) + VERIFY_MARGIN <= (c1p + c2q) then
                            finalize(pcld, en, q)
                            finalize(qPcld, en2, p)
                        end
                    elseif not hasPcld(q) then
                        finalize(pcld, en, q)
                    end
                end
            end
        end
    end

    api.seeZero = function(pcld, now)
        local z = zeros[pcld]
        if not z then
            z = {born = (now - createdAt < 0.25) and -1e9 or now}
            zeros[pcld] = z
        end
        z.last = now
    end

    api.frame = function(now)
        for _, p in ipairs(Players:GetPlayers()) do
            local st = seen[p]
            local char = p.Character
            if not st then
                seen[p] = {char = char}
                if now - createdAt >= 0.25 then
                    events[p] = {join = true, times = {now}, last = now}
                end
            else
                local prev = st.char
                st.char = char
                if char and char ~= prev then
                    local ev = events[p]
                    if not ev then
                        ev = {join = false, times = {}, last = now}
                        events[p] = ev
                    end
                    ev.times[#ev.times + 1] = now
                    ev.last = now
                end
            end
        end
        for p in pairs(seen) do
            if not p.Parent then
                seen[p] = nil
                events[p] = nil
            end
        end
        for p, ev in pairs(events) do
            if now - ev.last > EVENT_LIFE then events[p] = nil end
        end
        for pcld, z in pairs(zeros) do
            if not pcld.Parent or now - z.last > 0.25 then zeros[pcld] = nil end
        end
        processPending(now)
        if next(events) == nil or next(zeros) == nil then return end

        local cand = {}
        for p, ev in pairs(events) do
            for pcld, z in pairs(zeros) do
                if isFreshPcld(pcld) and not pending[pcld] and not pendingOf[p] then
                    local cost = math.huge
                    for _, t in ipairs(ev.times) do
                        local d = math.abs(z.born - t)
                        if d < cost then cost = d end
                    end
                    if cost <= ZERO_WINDOW then
                        cand[#cand + 1] = {cost = cost, p = p, pcld = pcld}
                    end
                end
            end
        end
        table.sort(cand, function(a, b) return a.cost < b.cost end)
        local countP, countC = {}, {}
        for _, c in ipairs(cand) do
            countP[c.p] = (countP[c.p] or 0) + 1
            countC[c.pcld] = (countC[c.pcld] or 0) + 1
        end
        local usedP, usedC = {}, {}
        for _, c in ipairs(cand) do
            if not usedP[c.p] and not usedC[c.pcld] then
                usedP[c.p] = true
                usedC[c.pcld] = true
                local ev = events[c.p]
                if ev and now - ev.last >= ZERO_SETTLE then
                    events[c.p] = nil
                    if c.p.Parent and (ev.join or matcher.known(c.p)) then
                        if c.pcld.Parent then
                            startPending(c.pcld, c.p, now)
                        end
                    end
                end
            end
        end
    end

    api.lockAll = function(pcldSet, usedNames, zero, now)
        matcher.begin()
        local bestD = {}
        for pcld in pairs(pcldSet) do
            if pcld.Parent and pcld.CFrame ~= zero then
                local boolValue, count = singleBool(pcld)
                if count == 1 and boolValue then
                    local name = boolValue.Name
                    local lockId = boolUserIdMap[boolValue] or boolValue:GetAttribute("OwnerUserId")
                    local ownerP = lockId and Players:GetPlayerByUserId(lockId)
                    local d = (ownerP and matcher.trail(pcld, ownerP)) or math.huge
                    if usedNames[name] == nil or d < bestD[name] then
                        usedNames[name] = boolValue
                        bestD[name] = d
                    end
                end
            end
        end
        for pcld in pairs(pcldSet) do
            if pcld.Parent and pcld.CFrame ~= zero then
                local boolValue, count = singleBool(pcld)
                if count == 1 and boolValue and usedNames[boolValue.Name] == boolValue then
                    local lockId = boolUserIdMap[boolValue] or boolValue:GetAttribute("OwnerUserId")
                    matcher.lock(pcld, lockId)
                    if lockId then boundNow[lockId] = pcld end
                end
            end
        end
        matcher.step(now)
    end

    local FB_RANGE, FB_INTERVAL = 10, 0.25
    local fbTick = 0

    local function aliveRoot(p)
        local char = p.Character
        if not char or not char.Parent then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return nil end
        return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    end

    api.nearbyFallback = function(pcldSet, zero, now)
        if now - fbTick < FB_INTERVAL then return end
        fbTick = now
        local lonely = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Parent and not hasPcld(p) then
                local root = aliveRoot(p)
                if root then
                    lonely[#lonely + 1] = {p = p, pos = root.Position}
                end
            end
        end
        if #lonely == 0 then return end
        local fresh = {}
        for pcld in pairs(pcldSet) do
            if pcld.Parent and pcld.CFrame ~= zero and isFreshPcld(pcld) then
                local relT = releasedAt[pcld]
                if not (relT and tick() - relT < RELEASE_HOLD) then
                    fresh[#fresh + 1] = pcld
                end
            end
        end
        if #fresh == 0 then return end
        local taken = {}
        for _, a in ipairs(lonely) do
            local crowd = false
            for _, b in ipairs(lonely) do
                if b ~= a and (a.pos - b.pos).Magnitude <= FB_RANGE then
                    crowd = true
                    break
                end
            end
            if not crowd then
                local best, bestD = nil, FB_RANGE
                for _, pcld in ipairs(fresh) do
                    if not taken[pcld] and pcld.Parent and isFreshPcld(pcld) then
                        local d = (pcld.Position - a.pos).Magnitude
                        if d <= bestD then
                            local shared = false
                            for _, b in ipairs(lonely) do
                                if b ~= a and (pcld.Position - b.pos).Magnitude <= FB_RANGE then
                                    shared = true
                                    break
                                end
                            end
                            if not shared then
                                best, bestD = pcld, d
                            end
                        end
                    end
                end
                if best then
                    taken[best] = true
                    local en = pending[best]
                    if en and pendingOf[en.p] == best then pendingOf[en.p] = nil end
                    pending[best] = nil
                    local oldP = pendingOf[a.p]
                    if oldP then pending[oldP] = nil end
                    pendingOf[a.p] = nil
                    claim(best, a.p)
                end
            end
        end
    end

    api.playerOf = function(pcld)
        local boolValue, count = singleBool(pcld)
        if count ~= 1 then
            -- 소유권 이양 중이라 BoolValue가 0개/2개 이상 공존하는 과도기 프레임.
            -- 이때는 어떤 값이 진짜 주인인지 신뢰할 수 없으므로 이번 프레임은 스킵한다.
            boolValue = nil
        end
        local targetUserId = boolValue and userIdOf(boolValue)
        local targetPlayer = nil
        if targetUserId then
            for _, p in pairs(Players:GetPlayers()) do
                if p.UserId == targetUserId then
                    targetPlayer = p
                    break
                end
            end
        end
        return targetPlayer, boolValue
    end

    api.resolve = function(pcld, tracker, usedNames)
        local boolValue, boolCount = singleBool(pcld)

        if boolCount >= 2 then
            local keep, keepD = nil, math.huge
            for _, child in pairs(pcld:GetChildren()) do
                if child:IsA("BoolValue") then
                    local uid = userIdOf(child)
                    local op = uid and Players:GetPlayerByUserId(uid)
                    local d = op and matcher.trail(pcld, op)
                    if d and d < keepD then
                        keep, keepD = child, d
                    end
                end
            end
            for _, child in pairs(pcld:GetChildren()) do
                if child:IsA("BoolValue") and child ~= keep then
                    child:Destroy()
                end
            end
            if keep then
                pcld.Name = keep.Name
                boolValue = keep
                boolCount = 1
            else
                boolValue = nil
                boolCount = 0
            end
        end

        local nameTag = tracker:FindFirstChild("PcldNameTag", true)

        if boolCount == 1 and boolValue and (usedNames[boolValue.Name] == nil or usedNames[boolValue.Name] == boolValue) then
            usedNames[boolValue.Name] = boolValue

            local ownerUserId = userIdOf(boolValue)

            if nameTag and nameTag:FindFirstChild("NameText") then
                local disp, uname = boolValue.Name:match("%[ (.-) %] %( (.-) %)")
                if disp and uname then
                    nameTag.NameText.Text = tostring(disp) .. "\n<" .. tostring(uname) .. ">"
                else
                    nameTag.NameText.Text = tostring(boolValue.Name or "")
                end
            end
            if ownerUserId then
                setTrackerAvatar(tracker, ownerUserId)
            end
        else
            if boolValue and usedNames[boolValue.Name] then
                boolUserIdMap[boolValue] = nil
                boolValue:Destroy()
            end
            local closestPlayer = nil
            local matchedPlayer = nil
            local relT = releasedAt[pcld]
            if not (relT and tick() - relT < RELEASE_HOLD) then
                matchedPlayer = matcher.owner(pcld)
            end
            if matchedPlayer then
                local pDisp = tostring(matchedPlayer.DisplayName or matchedPlayer.Name or "")
                local pUname = tostring(matchedPlayer.Name or "")
                local ownerNameForCheck = "[ " .. pDisp .. " ] ( " .. pUname .. " )"

                if not usedNames[ownerNameForCheck] then
                    closestPlayer = matchedPlayer
                    usedNames[ownerNameForCheck] = true
                end
            end

            if closestPlayer then
                local cpDisp = tostring(closestPlayer.DisplayName or closestPlayer.Name or "")
                local cpUname = tostring(closestPlayer.Name or "")
                local ownerNameForPart = "[ " .. cpDisp .. " ] ( " .. cpUname .. " )"
                local ownerNameForTag = cpDisp .. "\n<" .. cpUname .. ">"

                local newBool = getgenv().__DSN("BoolValue")
                newBool.Name = ownerNameForPart
                boolUserIdMap[newBool] = closestPlayer.UserId
                newBool.Parent = pcld
                newBool:SetAttribute("OwnerUserId", closestPlayer.UserId)

                pcld.Name = ownerNameForPart

                if nameTag and nameTag:FindFirstChild("NameText") then
                    nameTag.NameText.Text = ownerNameForTag
                end
                setTrackerAvatar(tracker, closestPlayer.UserId)

                local boundChar = closestPlayer.Character
                getgenv().__DSTH(task.spawn(function(player, value, targetPcld)
                    while value and value.Parent do
                        if not Players:FindFirstChild(player.Name) then
                            if targetPcld and targetPcld.Parent then
                                targetPcld.Name = "PlayerCharacterLocationDetector"
                                releasedAt[targetPcld] = tick()
                                if targetPcld:FindFirstChild("PcldNameTag") then
                                    targetPcld.PcldNameTag:Destroy()
                                end
                            end
                            value:Destroy()
                            break
                        end

                        local char = player.Character
                        if char ~= boundChar then
                            if targetPcld and targetPcld.Parent then
                                targetPcld.Name = "PlayerCharacterLocationDetector"
                                releasedAt[targetPcld] = tick()
                                if targetPcld:FindFirstChild("PcldNameTag") then
                                    targetPcld.PcldNameTag:Destroy()
                                end
                            end
                            value:Destroy()
                            break
                        end

                        local isValid = char and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0

                        if isValid then
                            local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
                            local hum = char.Humanoid
                            if hrp and hrp.Massless == true and not hum.SeatPart then
                                hrp.Massless = false
                                hrp.CFrame = targetPcld.CFrame
                            end
                        end

                        task.wait(0.1)
                    end
                end, closestPlayer, newBool, pcld))
            else
                if nameTag and nameTag:FindFirstChild("NameText") then
                    nameTag.NameText.Text = "Waiting for owner..."
                end
                local waitAvatar = nameTag and nameTag:FindFirstChild("AvatarImage")
                if waitAvatar then
                    waitAvatar.Visible = false
                    avatarUserIdMap[waitAvatar] = 0
                end
            end
        end
    end

    return api
end

M.newOwnerLead = function()
    local predict = M.newLeadPredictor()
    return function(part)
        local c = lp.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        if not h then return part.CFrame end
        return part.CFrame + predict(part, h)
    end
end

local function BACK(originCF)
    TP(nil, false)
    local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = false
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

local function bangFakeTP(targetPlayer, state, offset)
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return false end

    if state == M.bangFakeIsFaking then return true end
    M.bangFakeIsFaking = state

    if state then
        M.bangFakeOCF = hrp.CFrame
        RunService:BindToRenderStep("BangClientVision", Enum.RenderPriority.Camera.Value - 1, function()
            if hrp and M.bangFakeOCF then hrp.CFrame = M.bangFakeOCF end
        end)
        local predict = M.newLeadPredictor()
        M.bangFakeHBC = getgenv().__DST(RunService.Heartbeat:Connect(function()
            if not targetPlayer or not targetPlayer.Character then return end
            local part = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not part then return end

            local sCF = part.CFrame * offset + predict(part, hrp)
            M.bangFakeOCF = hrp.CFrame
            if not hum.Sit then
                hum:ChangeState(Enum.HumanoidStateType.PlatformStanding)
            else
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
            hrp.CFrame = sCF
        end))
        return true
    else
        pcall(function() RunService:UnbindFromRenderStep("BangClientVision") end)
        if M.bangFakeHBC then
            M.bangFakeHBC:Disconnect()
            M.bangFakeHBC = nil
        end
        if M.bangFakeOCF and hrp then
            hrp.CFrame = M.bangFakeOCF
        end
        local offHum = char and char:FindFirstChildOfClass("Humanoid")
        if offHum then offHum.PlatformStand = false end
        return true
    end
end

local function orbitFakeTP(targetPlayer, state)
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return false end

    if state == M.orbitFakeIsFaking then return true end
    M.orbitFakeIsFaking = state

    if state then
        M.orbitFakeOCF = hrp.CFrame
        RunService:BindToRenderStep("OrbitClientVision", Enum.RenderPriority.Camera.Value - 1, function()
            if hrp and M.orbitFakeOCF then hrp.CFrame = M.orbitFakeOCF end
        end)
        local rotation = 0
        local predict = M.newLeadPredictor()
        M.orbitFakeHBC = getgenv().__DST(RunService.Heartbeat:Connect(function()
            if not M.orbitEnabled then return end
            local tgt = M.orbitTarget
            if not tgt or not tgt.Character then return end
            local part = tgt.Character:FindFirstChild("HumanoidRootPart")
            if not part then return end

            rotation = rotation + M.orbitSpeed
            local targetPos = part.Position + predict(part, hrp)
            local orbitPosition = (CFrame.new(targetPos) * CFrame.Angles(0, math.rad(rotation), 0) * CFrame.new(M.orbitDistance, 0, 0)).Position
            local sCF = CFrame.lookAt(orbitPosition, Vector3.new(targetPos.X, orbitPosition.Y, targetPos.Z))

            M.orbitFakeOCF = hrp.CFrame
            if not hum.Sit then
                hum:ChangeState(Enum.HumanoidStateType.PlatformStanding)
            else
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
            hrp.CFrame = sCF
        end))
        return true
    else
        pcall(function() RunService:UnbindFromRenderStep("OrbitClientVision") end)
        if M.orbitFakeHBC then
            M.orbitFakeHBC:Disconnect()
            M.orbitFakeHBC = nil
        end
        if M.orbitFakeOCF and hrp then
            hrp.CFrame = M.orbitFakeOCF
        end
        local offHum = char and char:FindFirstChildOfClass("Humanoid")
        if offHum then offHum.PlatformStand = false end
        return true
    end
end

local function getBangFakeTP(targetPlayer, state)
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return false end

    if state == M.getBangFakeIsFaking then return true end
    M.getBangFakeIsFaking = state

    if state then
        M.getBangFakeOCF = hrp.CFrame
        RunService:BindToRenderStep("GetBangClientVision", Enum.RenderPriority.Camera.Value - 1, function()
            if hrp and M.getBangFakeOCF then hrp.CFrame = M.getBangFakeOCF end
        end)

        local FORWARD_Z, BACKWARD_Z, CYCLE_TIME = -2.5, -1.3, 0.3
        local startTick = tick()

        local predict = M.newLeadPredictor()
        M.getBangFakeHBC = getgenv().__DST(RunService.Heartbeat:Connect(function()
            if not M.getBangEnabled then return end
            local tgt = M.getBangTarget
            if not tgt or not tgt.Character then return end
            local part = tgt.Character:FindFirstChild("HumanoidRootPart")
            if not part then return end

            local phase = ((tick() - startTick) % CYCLE_TIME) / CYCLE_TIME
            local triangle = phase < 0.5 and (phase * 2) or (2 - phase * 2)
            local zOffset = FORWARD_Z + (BACKWARD_Z - FORWARD_Z) * triangle

            local sCF = part.CFrame * CFrame.new(0, 0, zOffset) + predict(part, hrp)
            M.getBangFakeOCF = hrp.CFrame
            if not hum.Sit then
                hum:ChangeState(Enum.HumanoidStateType.PlatformStanding)
            else
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
            hrp.CFrame = sCF
        end))
        return true
    else
        pcall(function() RunService:UnbindFromRenderStep("GetBangClientVision") end)
        if M.getBangFakeHBC then
            M.getBangFakeHBC:Disconnect()
            M.getBangFakeHBC = nil
        end
        if M.getBangFakeOCF and hrp then
            hrp.CFrame = M.getBangFakeOCF
        end
        local offHum = char and char:FindFirstChildOfClass("Humanoid")
        if offHum then offHum.PlatformStand = false end
        return true
    end
end

local function getSuckFakeTP(targetPlayer, state)
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return false end

    if state == M.getSuckFakeIsFaking then return true end
    M.getSuckFakeIsFaking = state

    if state then
        M.getSuckFakeOCF = hrp.CFrame
        RunService:BindToRenderStep("GetSuckClientVision", Enum.RenderPriority.Camera.Value - 1, function()
            if hrp and M.getSuckFakeOCF then hrp.CFrame = M.getSuckFakeOCF end
        end)
        local predict = M.newLeadPredictor()
        M.getSuckFakeHBC = getgenv().__DST(RunService.Heartbeat:Connect(function()
            if not M.getSuckEnabled then return end
            local tgt = M.getSuckTarget
            if not tgt or not tgt.Character then return end
            local part = tgt.Character:FindFirstChild("HumanoidRootPart")
            if not part then return end

            local sCF = part.CFrame * CFrame.new(0, 2.3, -1.1) * CFrame.Angles(0, math.pi, 0) + predict(part, hrp)
            M.getSuckFakeOCF = hrp.CFrame
            if not hum.Sit then
                hum:ChangeState(Enum.HumanoidStateType.PlatformStanding)
            else
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
            hrp.CFrame = sCF
        end))
        return true
    else
        pcall(function() RunService:UnbindFromRenderStep("GetSuckClientVision") end)
        if M.getSuckFakeHBC then
            M.getSuckFakeHBC:Disconnect()
            M.getSuckFakeHBC = nil
        end
        if M.getSuckFakeOCF and hrp then
            hrp.CFrame = M.getSuckFakeOCF
        end
        local offHum = char and char:FindFirstChildOfClass("Humanoid")
        if offHum then offHum.PlatformStand = false end
        return true
    end
end

local function reattackAfterOwnRespawn(newChar)
    getgenv().__DSTH(task.spawn(function()
        local humanoid = newChar:FindFirstChildOfClass("Humanoid") or newChar:WaitForChild("Humanoid", 5)
        local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
        if not humanoid or not hrp then return end

        task.wait(0.3)
        local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 3) or humanoid

        if M.bangTarget and M.bangTarget.Parent == Players and M.bangOffset then
            if M.bangAnimTrack then pcall(function() M.bangAnimTrack:Stop() end) end
            if M.bangAnimation then pcall(function() M.bangAnimation:Destroy() end) end

            M.bangAnimation = getgenv().__DSN("Animation")
            M.bangAnimation.AnimationId = humanoid.RigType == Enum.HumanoidRigType.R15
                and "rbxassetid://5918726674"
                or "rbxassetid://148840371"
            M.bangAnimTrack = animator:LoadAnimation(M.bangAnimation)
            M.bangAnimTrack:Play(0.1, 1, 1)
            M.bangAnimTrack:AdjustSpeed(3)

            if M.bangDiedConnection then M.bangDiedConnection:Disconnect() end
            M.bangDiedConnection = getgenv().__DST(humanoid.Died:Connect(function()
                if M.bangAnimTrack then
                    M.bangAnimTrack:Stop()
                end
                if M.bangAnimation then
                    M.bangAnimation:Destroy()
                    M.bangAnimation = nil
                end
                if M.bangDiedConnection then
                    M.bangDiedConnection:Disconnect()
                    M.bangDiedConnection = nil
                end
                bangFakeTP(nil, false)
            end))
            pcall(function() RunService:UnbindFromRenderStep("BangClientVision") end)
            if M.bangFakeHBC then M.bangFakeHBC:Disconnect(); M.bangFakeHBC = nil end
            M.bangFakeIsFaking = false
            bangFakeTP(M.bangTarget, true, M.bangOffset)
        end

        if M.orbitEnabled and M.orbitTarget and M.orbitTarget.Parent == Players then
            pcall(function() RunService:UnbindFromRenderStep("OrbitClientVision") end)
            if M.orbitFakeHBC then M.orbitFakeHBC:Disconnect(); M.orbitFakeHBC = nil end
            M.orbitFakeIsFaking = false
            orbitFakeTP(M.orbitTarget, true)
        end

        if M.getBangEnabled and M.getBangTarget and M.getBangTarget.Parent == Players then
            if M.getBangAnimTrack then pcall(function() M.getBangAnimTrack:Stop() end) end
            pcall(function() RunService:UnbindFromRenderStep("GetBangClientVision") end)
            if M.getBangFakeHBC then M.getBangFakeHBC:Disconnect(); M.getBangFakeHBC = nil end
            M.getBangFakeIsFaking = false
            local getBangAnim = getgenv().__DSN("Animation")
            getBangAnim.AnimationId = "rbxassetid://189854234"
            M.getBangAnimTrack = animator:LoadAnimation(getBangAnim)
            M.getBangAnimTrack:Play()
            getBangFakeTP(M.getBangTarget, true)
        end

        if M.getSuckEnabled and M.getSuckTarget and M.getSuckTarget.Parent == Players then
            if M.getSuckAnimTrack then pcall(function() M.getSuckAnimTrack:Stop() end) end
            pcall(function() RunService:UnbindFromRenderStep("GetSuckClientVision") end)
            if M.getSuckFakeHBC then M.getSuckFakeHBC:Disconnect(); M.getSuckFakeHBC = nil end
            M.getSuckFakeIsFaking = false
            local getSuckAnim = getgenv().__DSN("Animation")
            getSuckAnim.AnimationId = "rbxassetid://148840371"
            M.getSuckAnimTrack = animator:LoadAnimation(getSuckAnim)
            M.getSuckAnimTrack:Play()
            M.getSuckAnimTrack:AdjustSpeed(3)
            getSuckFakeTP(M.getSuckTarget, true)
        end
    end))
end

getgenv().__DST(lp.CharacterAdded:Connect(reattackAfterOwnRespawn))

local function bringFakeTP(getTargetPart, state, offset)
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return false end

    if state == M.bringFakeIsFaking then return true end
    M.bringFakeIsFaking = state

    if state then
        M.bringFakeOCF = hrp.CFrame
        RunService:BindToRenderStep("BringClientVision", Enum.RenderPriority.Camera.Value - 1, function()
            if hrp and M.bringFakeOCF then hrp.CFrame = M.bringFakeOCF end
        end)
        local predict = M.newLeadPredictor()
        M.bringFakeHBC = getgenv().__DST(RunService.Heartbeat:Connect(function()
            if not M.bringFakeIsFaking then return end
            local part = getTargetPart and getTargetPart()
            if not part then return end

            local sCF = part.CFrame * offset + predict(part, hrp)
            M.bringFakeOCF = hrp.CFrame
            if not hum.Sit then
                hum:ChangeState(Enum.HumanoidStateType.PlatformStanding)
            else
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
            hrp.CFrame = sCF
        end))
        return true
    else
        pcall(function() RunService:UnbindFromRenderStep("BringClientVision") end)
        if M.bringFakeHBC then
            M.bringFakeHBC:Disconnect()
            M.bringFakeHBC = nil
        end
        if M.bringFakeOCF and hrp then
            hrp.CFrame = M.bringFakeOCF
        end
        return true
    end
end

local function loopGotoFakeTP(targetPlayer, state)
    local char = lp.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return false end

    if state == M.loopGotoFakeIsFaking then return true end
    M.loopGotoFakeIsFaking = state

    if state then
        _G.ocf = hrp.CFrame
        RunService:BindToRenderStep("LoopGotoClientVision", Enum.RenderPriority.Camera.Value - 1, function()
            if hrp and _G.ocf then
                hrp.CFrame = _G.ocf
            end
        end)
        local predict = M.newLeadPredictor()
        M.loopGotoFakeHBC = getgenv().__DST(RunService.Heartbeat:Connect(function()
            if not M.loopGotoFakeIsFaking then return end
            local tgt = L.loopGotoTarget
            if not tgt or not tgt.Character then return end
            local part = tgt.Character:FindFirstChild("HumanoidRootPart") or tgt.Character:FindFirstChild("Torso")
            if not part then return end

            local currentVel = hrp.AssemblyLinearVelocity
            if currentVel.Magnitude < 0.001 then
                currentVel = Vector3.new(0, 0.001, 0)
            end

            _G.ocf = hrp.CFrame
            _G.sCF = part.CFrame + predict(part, hrp)

            hrp.CFrame = _G.sCF
            hrp.AssemblyLinearVelocity = currentVel

        end))
        return true
    else
        pcall(function() RunService:UnbindFromRenderStep("LoopGotoClientVision") end)
        if M.loopGotoFakeHBC then
            M.loopGotoFakeHBC:Disconnect()
            M.loopGotoFakeHBC = nil
        end
        if _G.ocf and hrp then
            hrp.CFrame = _G.ocf
        end
        return true
    end
end

local _killInProgress = false

local function executeKill(targetPlayer, isLoopKill, killTimeout)
    if not targetPlayer then return false end

    local character, hrp, head = safeGetCharacterParts(targetPlayer)
    local torso = character and (character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso"))
    if not hrp or not torso then return false end

    local myChar = lp.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return false end
    local originCF, killStartTime = myHrp.CFrame, killTimeout and tick() or nil

    _killInProgress = true

    local dist, skipTpThreshold = (myHrp.Position - hrp.Position).Magnitude, isLoopKill and 23 or 25
    local skipTp = dist <= skipTpThreshold
    if not skipTp then
        TP(targetPlayer, true)
    end

    local predictOwner = M.newLeadPredictor()

    local success, killed = pcall(function()
        if isLoopKill then
            local attemptStart, ownerGained = tick(), false
            while (tick() - attemptStart) < 1 do
                if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("Head") then break end

                ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(torso, torso.CFrame + predictOwner(torso, myHrp))
                local ownerTag = head:FindFirstChild("PartOwner")
                if ownerTag and ownerTag:IsA("StringValue") and ownerTag.Value == lp.Name then
                    ownerGained = true
                    break
                end
                task.wait()
            end

            if not ownerGained then
                _killInProgress = false
                if not skipTp and originCF then BACK(originCF) end
                return false
            end
        else
            while true do
                if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("Head") then break end

                if killStartTime and (tick() - killStartTime) >= killTimeout then
                    _killInProgress = false
                    if not skipTp and originCF then BACK(originCF) end
                    return false
                end

                ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(torso, torso.CFrame + predictOwner(torso, myHrp))
                local ownerTag = head:FindFirstChild("PartOwner")
                if ownerTag and ownerTag:IsA("StringValue") and ownerTag.Value == lp.Name then
                    break
                end
                task.wait()
            end
        end

        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if not skipTp and originCF then
                getgenv().__DSTH(task.spawn(function() BACK(originCF) end))
            end

            ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(hrp, hrp.CFrame)
            ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(hrp, hrp.CFrame)
            ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(hrp, hrp.CFrame)

            if humanoid.BreakJointsOnDeath == true and humanoid.SeatPart == nil then humanoid.BreakJointsOnDeath = false end
            if humanoid and humanoid.SeatPart == nil then humanoid:ChangeState(Enum.HumanoidStateType.Dead) end

            if head:FindFirstChildOfClass("BallSocketConstraint") then head.BallSocketConstraint.Attachment0 = nil end

            local FallenY = workspace.FallenPartsDestroyHeight
            local targetY, storso =
                (FallenY <= -50000 and -49999) or (FallenY <= -100 and -99) or -77777,
                character:FindFirstChild("Torso")

            if storso then
                storso.CFrame = CFrame.new(storso.Position.X, targetY, storso.Position.Z)
            end

            local deadCheckStart, killed = tick(), false
            while (tick() - deadCheckStart) < 1 do
                local curChar = targetPlayer.Character
                local curHuman = curChar and curChar:FindFirstChildOfClass("Humanoid")
                if not curHuman or curHuman.Health <= 0 then
                    killed = true
                    break
                end
                task.wait()
            end

            _killInProgress = false
            return killed
        end

        if not skipTp and originCF then BACK(originCF) end
        _killInProgress = false
        return false
    end)

    _killInProgress = false
    
    if success then
        return killed
    else
        if not skipTp and originCF then BACK(originCF) end
        return false
    end
end

local function executeKillWithCheck(targetPlayer)
    if not targetPlayer then return end
    local targetName, ownerGranted = targetPlayer.Name, executeKill(targetPlayer, false, 1)

    if ownerGranted then
        StarterGui:SetCore("SendNotification", {
            Title = "[ 공격 성공 ]",
            Text = targetName .. "님의 소유권을 획득하여 공격했습니다.",
            Duration = 3
        })
    else
        StarterGui:SetCore("SendNotification", {
            Title = "[ 공격 실패 ]",
            Text = targetName .. "님의 소유권을 획득하지 못했습니다.",
            Duration = 3
        })
    end
end


local function isTargetInPlot(targetPlayer)
    local plotItems = Workspace:FindFirstChild("PlotItems")
    local playersInPlots = plotItems and plotItems:FindFirstChild("PlayersInPlots")
    if playersInPlots and playersInPlots:FindFirstChild(targetPlayer.Name) then
        return true
    end
    local mySpawnFolder = Workspace:FindFirstChild(lp.Name .. "SpawnedInToys")
    if mySpawnFolder then
        local char = targetPlayer.Character
        if char and char:IsDescendantOf(mySpawnFolder) then
            return true
        end
    end
    return false
end

local function notifyTargetInPlot(targetPlayer)
    StarterGui:SetCore("SendNotification", {
        Title = "[ Kill 불가 ]",
        Text = targetPlayer.Name .. "님은 Plot 안에 있습니다.",
        Duration = 3
    })
end

local function notifyTargetLeaveStop(actionName, targetPlayer)
    if not targetPlayer then return end
    StarterGui:SetCore("SendNotification", {
        Title = "[ 종료 ]",
        Text = (targetPlayer.DisplayName or targetPlayer.Name) .. "님이 나가서 " .. actionName .. "이(가) 종료되었습니다.",
        Duration = 3
    })
end

local function stopBang()
    if M.bangDiedConnection then M.bangDiedConnection:Disconnect(); M.bangDiedConnection = nil end
    if M.bangLoopConnection then M.bangLoopConnection:Disconnect(); M.bangLoopConnection = nil end
    if M.bangTargetDiedConn then M.bangTargetDiedConn:Disconnect(); M.bangTargetDiedConn = nil end
    if M.bangTargetRespawnConn then M.bangTargetRespawnConn:Disconnect(); M.bangTargetRespawnConn = nil end
    if M.bangTargetLeaveConn then M.bangTargetLeaveConn:Disconnect(); M.bangTargetLeaveConn = nil end
    M.bangTarget = nil
    M.bangOffset = nil
    bangFakeTP(nil, false)
    if M.bangAnimTrack then M.bangAnimTrack:Stop(); M.bangAnimTrack = nil end
    if M.bangAnimation then M.bangAnimation:Destroy(); M.bangAnimation = nil end
end

local function stopOrbit()
    M.orbitEnabled = false
    M.orbitTarget = nil
    if M.orbitConnection1 then M.orbitConnection1:Disconnect(); M.orbitConnection1 = nil end
    if M.orbitConnection2 then M.orbitConnection2:Disconnect(); M.orbitConnection2 = nil end
    if M.orbitConnection3 then M.orbitConnection3:Disconnect(); M.orbitConnection3 = nil end
    if M.orbitTargetDiedConn then M.orbitTargetDiedConn:Disconnect(); M.orbitTargetDiedConn = nil end
    if M.orbitTargetRespawnConn then M.orbitTargetRespawnConn:Disconnect(); M.orbitTargetRespawnConn = nil end
    if M.orbitTargetLeaveConn then M.orbitTargetLeaveConn:Disconnect(); M.orbitTargetLeaveConn = nil end
    orbitFakeTP(nil, false)
end

local function stopGetBang()
    M.getBangEnabled = false
    M.getBangTarget = nil
    if M.getBangLoop then
        task.cancel(M.getBangLoop)
        M.getBangLoop = nil
    end
    if M.getBangAnimTrack then
        M.getBangAnimTrack:Stop()
        M.getBangAnimTrack = nil
    end
    if M.getBangTargetDiedConn then M.getBangTargetDiedConn:Disconnect(); M.getBangTargetDiedConn = nil end
    if M.getBangTargetRespawnConn then M.getBangTargetRespawnConn:Disconnect(); M.getBangTargetRespawnConn = nil end
    if M.getBangTargetLeaveConn then M.getBangTargetLeaveConn:Disconnect(); M.getBangTargetLeaveConn = nil end
    getBangFakeTP(nil, false)
end

local function startGetBang(targetPlayer)
    stopGetBang()

    if not (lp.Character and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")) then
        return false
    end

    M.getBangEnabled = true
    M.getBangTarget = targetPlayer

    local humanoid = lp.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local animation = getgenv().__DSN("Animation")
        animation.AnimationId = "rbxassetid://189854234"
        M.getBangAnimTrack = humanoid:LoadAnimation(animation)
        M.getBangAnimTrack:Play()
    end

    getBangFakeTP(targetPlayer, true)

    local function hookGetBangTargetHumanoid(character)
        getgenv().__DSTH(task.spawn(function()
            local h = character and (character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5))
            if not h then return end
            if M.getBangTargetDiedConn then M.getBangTargetDiedConn:Disconnect() end
            M.getBangTargetDiedConn = getgenv().__DST(h.Died:Connect(function()
                getBangFakeTP(nil, false)
            end))
        end))
    end
    hookGetBangTargetHumanoid(targetPlayer.Character)
    if M.getBangTargetRespawnConn then M.getBangTargetRespawnConn:Disconnect() end
    M.getBangTargetRespawnConn = getgenv().__DST(targetPlayer.CharacterAdded:Connect(function(newChar)
        getgenv().__DSTH(task.spawn(function()
            newChar:WaitForChild("HumanoidRootPart", 5)
            if M.getBangEnabled and M.getBangTarget == targetPlayer then
                getBangFakeTP(targetPlayer, true)
            end
            hookGetBangTargetHumanoid(newChar)
        end))
    end))
    if M.getBangTargetLeaveConn then M.getBangTargetLeaveConn:Disconnect() end
    M.getBangTargetLeaveConn = getgenv().__DST(Players.PlayerRemoving:Connect(function(player)
        if player == targetPlayer then
            stopGetBang()
            notifyTargetLeaveStop("GetBang", targetPlayer)
        end
    end))

    return true
end

local function stopGetSuck()
    M.getSuckEnabled = false
    M.getSuckTarget = nil
    if M.getSuckConnection then
        M.getSuckConnection:Disconnect()
        M.getSuckConnection = nil
    end
    if M.getSuckAnimTrack then
        M.getSuckAnimTrack:Stop()
        M.getSuckAnimTrack = nil
    end
    if M.getSuckTargetDiedConn then M.getSuckTargetDiedConn:Disconnect(); M.getSuckTargetDiedConn = nil end
    if M.getSuckTargetRespawnConn then M.getSuckTargetRespawnConn:Disconnect(); M.getSuckTargetRespawnConn = nil end
    if M.getSuckTargetLeaveConn then M.getSuckTargetLeaveConn:Disconnect(); M.getSuckTargetLeaveConn = nil end
    getSuckFakeTP(nil, false)
end

local function startGetSuck(targetPlayer)
    stopGetSuck()

    local humanoidRootPart = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    local targetRootPart = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")

    if not (humanoidRootPart and targetRootPart) then
        return false
    end

    M.getSuckEnabled = true
    M.getSuckTarget = targetPlayer

    getSuckFakeTP(targetPlayer, true)

    local animationId = "rbxassetid://148840371"
    local animation = getgenv().__DSN("Animation")
    animation.AnimationId = animationId

    local humanoid = lp.Character:FindFirstChild("Humanoid")
    if humanoid then
        M.getSuckAnimTrack = humanoid:LoadAnimation(animation)
        M.getSuckAnimTrack:Play()
        M.getSuckAnimTrack:AdjustSpeed(3)
    end

    local function hookGetSuckTargetHumanoid(character)
        getgenv().__DSTH(task.spawn(function()
            local h = character and (character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5))
            if not h then return end
            if M.getSuckTargetDiedConn then M.getSuckTargetDiedConn:Disconnect() end
            M.getSuckTargetDiedConn = getgenv().__DST(h.Died:Connect(function()
                getSuckFakeTP(nil, false)
            end))
        end))
    end
    hookGetSuckTargetHumanoid(targetPlayer.Character)
    if M.getSuckTargetRespawnConn then M.getSuckTargetRespawnConn:Disconnect() end
    M.getSuckTargetRespawnConn = getgenv().__DST(targetPlayer.CharacterAdded:Connect(function(newChar)
        getgenv().__DSTH(task.spawn(function()
            newChar:WaitForChild("HumanoidRootPart", 5)
            if M.getSuckEnabled and M.getSuckTarget == targetPlayer then
                getSuckFakeTP(targetPlayer, true)
            end
            hookGetSuckTargetHumanoid(newChar)
        end))
    end))
    if M.getSuckTargetLeaveConn then M.getSuckTargetLeaveConn:Disconnect() end
    M.getSuckTargetLeaveConn = getgenv().__DST(Players.PlayerRemoving:Connect(function(player)
        if player == targetPlayer then
            stopGetSuck()
            notifyTargetLeaveStop("GetSuck", targetPlayer)
        end
    end))

    return true
end

local function stopFling()
    L.flingEnabled = false
    if L.flingConnection then
        L.flingConnection:Disconnect()
        L.flingConnection = nil
    end
    if L.flingPlayerRemovingConn then
        L.flingPlayerRemovingConn:Disconnect()
        L.flingPlayerRemovingConn = nil
    end
    if L.flingDice and L.flingDice.Parent then
        pcall(function()
            ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("DestroyToy"):FireServer(L.flingDice)
        end)
    end
    L.flingDice = nil
    L.flingTarget = nil
    L.flingOwnerConfirmed = false
    L.flingLossTimer = 0
    L.flingLastSpawn = 0
end

local function startFling(targetPlayer)
    stopFling()
    L.flingEnabled = true
    L.flingTarget = targetPlayer
    L.flingDice = nil
    L.flingOwnerConfirmed = false
    L.flingLossTimer = 0
    L.flingLastSpawn = 0
    local folderName = lp.Name .. "SpawnedInToys"

    L.flingPlayerRemovingConn = getgenv().__DST(Players.PlayerRemoving:Connect(function(p)
        if L.flingTarget and p == L.flingTarget then
            StarterGui:SetCore("SendNotification", {Title = "[ Fling 종료 ]", Text = "타겟이 나갔습니다.", Duration = 3})
            stopFling()
        end
    end))

    L.flingConnection = getgenv().__DST(RunService.Heartbeat:Connect(function(dt)
        if not L.flingEnabled then return end

        local targetPlayer = L.flingTarget
        if not targetPlayer or not targetPlayer.Parent then
            StarterGui:SetCore("SendNotification", {Title = "[ Fling 종료 ]", Text = "타겟이 나갔습니다.", Duration = 3})
            stopFling()
            return
        end

        if L.flingDice and not L.flingDice.Parent then
            L.flingDice = nil
            L.flingOwnerConfirmed = false
            L.flingLossTimer = 0
        end

        if not L.flingDice then
            local toysFolder = workspace:FindFirstChild(folderName)
            local foundDice = nil
            if toysFolder then
                for _, child in ipairs(toysFolder:GetChildren()) do
                    if child.Name == "DiceBig" and child:FindFirstChild("SoundPart") then
                        foundDice = child
                    end
                end
            end

            if foundDice then
                L.flingDice = foundDice
                L.flingOwnerConfirmed = false
                L.flingLossTimer = 0
            else
                local now = os.clock()
                if now - L.flingLastSpawn >= 0.5 then
                    L.flingLastSpawn = now
                    L.flingOwnerConfirmed = false
                    L.flingLossTimer = 0
                    local currentChar = lp.Character
                    local currentHead = currentChar and currentChar:FindFirstChild("Head")

                    if currentHead then
                        local spawnCFrame = currentHead.CFrame * CFrame.new(1, 10, 27)
                        getgenv().__DSTH(task.spawn(function()
                            pcall(function()
                                ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction"):InvokeServer("DiceBig", spawnCFrame, Vector3.new(0, 0, 0))
                            end)
                        end))
                    end
                end
            end
            return
        end

        local soundPart = L.flingDice:FindFirstChild("SoundPart")
        if not soundPart then return end

        local partOwner = soundPart:FindFirstChild("PartOwner")

        if L.flingOwnerConfirmed then
            if not partOwner or partOwner.Value ~= lp.Name then
                L.flingLossTimer = L.flingLossTimer + dt
                if L.flingLossTimer >= 0.5 then
                    pcall(function()
                        ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("DestroyToy"):FireServer(L.flingDice)
                    end)
                    L.flingDice = nil
                    L.flingOwnerConfirmed = false
                    L.flingLossTimer = 0
                end
                return
            else
                L.flingLossTimer = 0
            end

            if targetPlayer.Character then
                local torso = targetPlayer.Character:FindFirstChild("Torso") or targetPlayer.Character:FindFirstChild("UpperTorso") or targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                if torso then
                    local ping = lp:GetNetworkPing()
                    local predictedPos = torso.Position + (torso.Velocity * (ping + 0.15))
                    local targetCFrame = CFrame.new(predictedPos) * torso.CFrame.Rotation

                    soundPart.CFrame = targetCFrame
                    soundPart.Velocity = Vector3.new(999999, 999999, 999999)
                    soundPart.RotVelocity = Vector3.new(999999, 999999, 999999)
                end
            end
        else
            ReplicatedStorage:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner"):FireServer(soundPart, soundPart.CFrame)

            if partOwner and partOwner.Value == lp.Name then
                L.flingOwnerConfirmed = true
                L.flingLossTimer = 0
            end
        end
    end))
end

local function stopLoopKill()
    L.loopKillEnabled = false
    L.loopKillAllMode = false
    if L.loopKillAllWatcher then
        task.cancel(L.loopKillAllWatcher)
        L.loopKillAllWatcher = nil
    end
    L.loopKillTargets = {}
    L.currentProcessing = {}
    for player, conn in pairs(L.loopKillConnections) do
        if conn then conn:Disconnect() end
    end
    L.loopKillConnections = {}
    for player, _ in pairs(L.loopKillPlotWatchers) do
        L.loopKillPlotWatchers[player] = nil
    end
    L.loopKillPlotWatchers = {}
    for player, conn in pairs(L.loopKillCharConns) do
        if conn then conn:Disconnect() end
    end
    L.loopKillCharConns = {}
    if getgenv()._loopKillPendingRejoin then
        for k in pairs(getgenv()._loopKillPendingRejoin) do
            getgenv()._loopKillPendingRejoin[k] = nil
        end
    end
end

local function stopLoopKillTarget(targetPlayer)
    local idx = table.find(L.loopKillTargets, targetPlayer)
    if idx then
        table.remove(L.loopKillTargets, idx)
    end
    L.currentProcessing[targetPlayer] = nil
    if L.loopKillConnections[targetPlayer] then
        L.loopKillConnections[targetPlayer]:Disconnect()
        L.loopKillConnections[targetPlayer] = nil
    end
    if L.loopKillPlotWatchers[targetPlayer] then
        L.loopKillPlotWatchers[targetPlayer] = nil
    end
    if L.loopKillCharConns[targetPlayer] then
        L.loopKillCharConns[targetPlayer]:Disconnect()
        L.loopKillCharConns[targetPlayer] = nil
    end
    if #L.loopKillTargets == 0 then
        L.loopKillEnabled = false
        L.loopKillAllMode = false
        if L.loopKillAllWatcher then
            task.cancel(L.loopKillAllWatcher)
            L.loopKillAllWatcher = nil
        end
    end
end

local function stopLoopGoto()
    L.loopGotoEnabled = false
    L.loopGotoTarget = nil
    if L.loopGotoConnection then
        task.cancel(L.loopGotoConnection)
        L.loopGotoConnection = nil
    end
    loopGotoFakeTP(nil, false)
end

local function stopLpBring(skipGrabDestroy)
    L.lpBringEnabled = false
    if L.lpBringLoop then
        if typeof(L.lpBringLoop) == "RBXScriptConnection" then
            pcall(function() L.lpBringLoop:Disconnect() end)
        else
            pcall(function() task.cancel(L.lpBringLoop) end)
        end
        L.lpBringLoop = nil
    end
    for target, conn in pairs(L.lpBringDeathConns) do
        if conn then pcall(function() conn:Disconnect() end) end
    end
    L.lpBringDeathConns = {}
    if not skipGrabDestroy then
        local rs = game:GetService("ReplicatedStorage")
        local grabEvents = rs:FindFirstChild("GrabEvents")
        if grabEvents then
            local destroyGrab = grabEvents:FindFirstChild("DestroyGrabLine")
            if destroyGrab then
                for _, target in ipairs(L.lpBringTargets) do
                    if target and target.Character then
                        local torso = target.Character:FindFirstChild("Torso")
                            or target.Character:FindFirstChild("HumanoidRootPart")
                        if torso then
                            pcall(function() destroyGrab:FireServer(torso) end)
                        end
                    end
                end
            end
        end
    end
    L.lpBringTargets = {}
    if getgenv()._lpBringPaused then
        for k in pairs(getgenv()._lpBringPaused) do getgenv()._lpBringPaused[k] = nil end
    end
    if getgenv()._lpBringFixedCF then
        for k in pairs(getgenv()._lpBringFixedCF) do getgenv()._lpBringFixedCF[k] = nil end
    end
    getgenv()._lpBringAnchorCF = nil
    getgenv()._lpBringSetupDeathWatch = nil
    if getgenv()._lpBringOutOfRange then
        for k in pairs(getgenv()._lpBringOutOfRange) do getgenv()._lpBringOutOfRange[k] = nil end
    end
end

local function stopWalkTo()
    M.walkToEnabled = false
    M.walkToTarget = nil
    if M.walkToLoop then
        task.cancel(M.walkToLoop)
        M.walkToLoop = nil
    end
end

local function startWalkTo(targetPlayer)
    stopWalkTo()
    M.walkToEnabled = true
    M.walkToTarget = targetPlayer

    M.walkToLoop = getgenv().__DSTH(task.spawn(function()
        local leaveConn
        leaveConn = getgenv().__DST(Players.PlayerRemoving:Connect(function(p)
            if p == targetPlayer then
                stopWalkTo()
                if leaveConn then leaveConn:Disconnect() end
                StarterGui:SetCore("SendNotification", {
                    Title = "[ WalkTo 자동 중지 ]",
                    Text = targetPlayer.Name .. "님이 서버에서 나갔습니다.",
                    Duration = 4
                })
            end
        end))

        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude

        local function isSolid(inst)
            if not inst then return false end
            if not inst:IsA("BasePart") then return false end
            if not inst.CanCollide then return false end
            return true
        end

        local function raycastSolid(origin, dir, exclude)
            rayParams.FilterDescendantsInstances = exclude
            local r = Workspace:Raycast(origin, dir, rayParams)
            if r and isSolid(r.Instance) then return r end
            return nil
        end

        local function isPathBlocked(from, to, exclude)
            local dir = to - from
            local flatDir = Vector3.new(dir.X, 0, dir.Z)
            local flatLen = flatDir.Magnitude
            if flatLen < 0.01 then return false, nil end
            local fwd = flatDir / flatLen
            local right, sides, heights = Vector3.new(fwd.Z, 0, -fwd.X), {0, 0.7, -0.7}, {0.2, 1.5, 2.8, 4.2}
            for _, s in ipairs(sides) do
                for _, h in ipairs(heights) do
                    local sv = right * s
                    local o, d =
                        Vector3.new(from.X + sv.X, from.Y + h, from.Z + sv.Z),
                        Vector3.new(dir.X, dir.Y * 0.3, dir.Z)
                    local r = raycastSolid(o, d, exclude)
                    if r then return true, r end
                end
            end
            return false, nil
        end

        local function getGroundY(pos, exclude)
            local downResult = raycastSolid(pos + Vector3.new(0, 1, 0), Vector3.new(0, -60, 0), exclude)
            if downResult then
                return downResult.Position.Y
            end
            return nil
        end

        local function checkStepAhead(myPos, moveDir, exclude)
            local dist = 2.2
            local d, lowO =
                Vector3.new(moveDir.X * dist, 0, moveDir.Z * dist),
                Vector3.new(myPos.X, myPos.Y + 0.15, myPos.Z)
            local lowHit = raycastSolid(lowO, d, exclude)
            if not lowHit then return false end
            local hitTop = lowHit.Instance.Position.Y + lowHit.Instance.Size.Y / 2
            local stepH = hitTop - myPos.Y
            if stepH > 0.2 and stepH < 5.5 then
                local highO = Vector3.new(myPos.X, myPos.Y + stepH + 1.2, myPos.Z)
                if not raycastSolid(highO, d, exclude) then return true end
            end
            return false
        end

        local function findBestWaypoint(myPos, targetPos, exclude)
            local toTarget = targetPos - myPos
            local flatTo = Vector3.new(toTarget.X, 0, toTarget.Z)
            local flatLen = flatTo.Magnitude
            if flatLen < 0.01 then return nil end
            local fwd = flatTo / flatLen
            local right, heightDiff, candidates = Vector3.new(fwd.Z, 0, -fwd.X), targetPos.Y - myPos.Y, {}

            for i = 1, 80 do
                for _, side in ipairs({1, -1}) do
                    local offset = right * (i * 0.5 * side)
                    local c = Vector3.new(myPos.X + offset.X, myPos.Y, myPos.Z + offset.Z)
                    local b1, _ = isPathBlocked(myPos, c, exclude)
                    if not b1 then
                        local b2, _ = isPathBlocked(c, targetPos, exclude)
                        if not b2 then
                            local score = (c - myPos).Magnitude + (c - targetPos).Magnitude
                            table.insert(candidates, {pos = c, score = score})
                            if #candidates >= 6 then break end
                        end
                    end
                end
                if #candidates >= 6 then break end
            end

            if heightDiff > 3 then
                local searchDirs = {}
                for _, angle in ipairs({0, 15, -15, 30, -30, 45, -45}) do
                    local rad = math.rad(angle)
                    local cos, sin = math.cos(rad), math.sin(rad)
                    local rotFwd = Vector3.new(fwd.X * cos - fwd.Z * sin, 0, fwd.X * sin + fwd.Z * cos)
                    table.insert(searchDirs, rotFwd)
                end

                for _, dir in ipairs(searchDirs) do
                    local stepSize, maxSteps, prevGroundY, pathOk, lastPos3D = 2, 40, myPos.Y, true, myPos

                    for step = 1, maxSteps do
                        local stepPos = Vector3.new(
                            myPos.X + dir.X * stepSize * step,
                            prevGroundY + 5,
                            myPos.Z + dir.Z * stepSize * step
                        )
                        local groundY = getGroundY(stepPos, exclude)
                        if groundY == nil then
                            pathOk = false
                            break
                        end

                        local stepSurface, riseH =
                            Vector3.new(stepPos.X, groundY + 3, stepPos.Z),
                            groundY - prevGroundY

                        if riseH > 8 then
                            pathOk = false
                            break
                        end

                        local b, _ = isPathBlocked(stepSurface, targetPos, exclude)
                        if not b then
                            local score = (stepSurface - myPos).Magnitude + (stepSurface - targetPos).Magnitude
                            table.insert(candidates, {pos = stepSurface, score = score})
                            break
                        end

                        prevGroundY = groundY
                        lastPos3D = stepSurface

                        local bToHere, _ = isPathBlocked(myPos, stepSurface, exclude)
                        if bToHere then
                            pathOk = false
                            break
                        end
                    end
                end
            end

            if heightDiff > 3 and #candidates == 0 then
                for radius = 3, 25, 2 do
                    for angle = 0, 359, 20 do
                        local rad = math.rad(angle)
                        local edgePos = Vector3.new(
                            targetPos.X + math.cos(rad) * radius,
                            targetPos.Y,
                            targetPos.Z + math.sin(rad) * radius
                        )
                        local gY = getGroundY(edgePos, exclude)
                        if gY then
                            local surface = Vector3.new(edgePos.X, gY + 3, edgePos.Z)
                            local b, _ = isPathBlocked(myPos, surface, exclude)
                            if not b then
                                local score = (surface - myPos).Magnitude + (surface - targetPos).Magnitude
                                table.insert(candidates, {pos = surface, score = score})
                            end
                        end
                    end
                    if #candidates >= 4 then break end
                end
            end

            if #candidates == 0 then return nil end
            table.sort(candidates, function(a, b) return a.score < b.score end)
            return candidates[1].pos
        end

        local waypoint, lastRecalc, stuckTimer, lastPos, jumpCooldown = nil, 0, 0, nil, 0

        while M.walkToEnabled do
            local now, tChar = tick(), M.walkToTarget and M.walkToTarget.Character
            local tHRP, myChar =
                tChar and (tChar:FindFirstChild("HumanoidRootPart") or tChar:FindFirstChild("Torso")),
                lp.Character
            local myHum, myHRP =
                myChar and myChar:FindFirstChildOfClass("Humanoid"),
                myChar and myChar:FindFirstChild("HumanoidRootPart")

            if tHRP and myHum and myHum.Health > 0 and myHRP then
                local myPos, targetPos = myHRP.Position, tHRP.Position
                local fullDist, flatDist =
                    (targetPos - myPos).Magnitude,
                    Vector3.new(targetPos.X - myPos.X, 0, targetPos.Z - myPos.Z).Magnitude

                do
                    local exclude = {myChar, tChar}

                    if now - lastRecalc >= 0.1 then
                        lastRecalc = now
                        local blocked, _ = isPathBlocked(myPos, targetPos, exclude)
                        if blocked then
                            local open = findBestWaypoint(myPos, targetPos, exclude)
                            waypoint = open
                        else
                            waypoint = nil
                        end
                    end

                    if waypoint then
                        local wpDist = (Vector3.new(waypoint.X, myPos.Y, waypoint.Z) - Vector3.new(myPos.X, myPos.Y, myPos.Z)).Magnitude
                        if wpDist < 2.5 then
                            waypoint = nil
                        end
                    end

                    local dest = waypoint or targetPos

                    local moveFlat = Vector3.new(dest.X - myPos.X, 0, dest.Z - myPos.Z)
                    local moveMag = moveFlat.Magnitude
                    local moveDir = moveMag > 0.01 and (moveFlat / moveMag) or Vector3.zero

                    if now - jumpCooldown >= 0.4 and moveDir.Magnitude > 0.01 then
                        if checkStepAhead(myPos, moveDir, exclude) then
                            myHum.Jump = true
                            jumpCooldown = now
                        end
                    end

                    if lastPos then
                        local moved = (myPos - lastPos).Magnitude
                        if moved < 0.05 then
                            stuckTimer = stuckTimer + 0.05
                            if stuckTimer >= 0.5 and now - jumpCooldown >= 0.4 then
                                myHum.Jump = true
                                jumpCooldown = now
                                stuckTimer = 0
                            end
                        else
                            stuckTimer = 0
                        end
                    end
                    lastPos = myPos

                    myHum:MoveTo(dest)
                end
            end

            task.wait(0.05)
        end

        if leaveConn then leaveConn:Disconnect() end
    end))
end

local function startLoopGoto(targetPlayer)
    stopLoopGoto()
    L.loopGotoEnabled = true
    L.loopGotoTarget = targetPlayer

    if L.loopGotoConnection then task.cancel(L.loopGotoConnection) end
    L.loopGotoConnection = getgenv().__DSTH(task.spawn(function()
        local leaveConn, diedConn, charAddedConn

        local function cleanupTargetConns()
            if diedConn then diedConn:Disconnect(); diedConn = nil end
        end

        local function bindDied(char)
            cleanupTargetConns()
            local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
            if not hum then return end
            if hum.Health <= 0 then
                loopGotoFakeTP(nil, false)
                return
            end
            diedConn = getgenv().__DST(hum.Died:Connect(function()
                loopGotoFakeTP(nil, false)
            end))
        end

        leaveConn = getgenv().__DST(Players.PlayerRemoving:Connect(function(p)
            if p == targetPlayer then
                stopLoopGoto()
                if leaveConn then leaveConn:Disconnect() end
                if charAddedConn then charAddedConn:Disconnect() end
                cleanupTargetConns()
                StarterGui:SetCore("SendNotification", {
                    Title = "[ LoopGoto 자동 중지 ]",
                    Text = targetPlayer.Name .. "님이 서버에서 나갔습니다.",
                    Duration = 4
                })
            end
        end))

        charAddedConn = getgenv().__DST(targetPlayer.CharacterAdded:Connect(function(newChar)
            if not L.loopGotoEnabled then return end
            bindDied(newChar)
            newChar:WaitForChild("HumanoidRootPart", 5)
            loopGotoFakeTP(targetPlayer, true)
        end))

        if targetPlayer.Character then
            bindDied(targetPlayer.Character)
        end

        loopGotoFakeTP(targetPlayer, true)

        while L.loopGotoEnabled do
            task.wait()
        end

        if leaveConn then leaveConn:Disconnect() end
        if charAddedConn then charAddedConn:Disconnect() end
        cleanupTargetConns()
    end))
end

local function attackLoopKillTarget(player)
    if not L.loopKillEnabled then return end
    if not table.find(L.loopKillTargets, player) then return end
    if L.currentProcessing[player] then return end

    if isTargetInPlot(player) then
        notifyTargetInPlot(player)
        return
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    L.currentProcessing[player] = true
    getgenv().__DSTH(task.spawn(function()
        local success = false
        while not success do
            if not L.loopKillEnabled then break end
            if not table.find(L.loopKillTargets, player) then break end
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if not humanoid or humanoid.Health <= 0 then break end
            success = executeKill(player, true, 1.5)
            if not success then
                if not L.loopKillEnabled then break end
                if not table.find(L.loopKillTargets, player) then break end
                task.wait()
            end
        end
        if success then
            task.wait(2)
        end
        L.currentProcessing[player] = nil
    end))
end

local function registerLoopKillCharConn(player)
    if L.loopKillCharConns[player] then
        L.loopKillCharConns[player]:Disconnect()
        L.loopKillCharConns[player] = nil
    end

    L.loopKillCharConns[player] = getgenv().__DST(player.CharacterAdded:Connect(function(newChar)
        if not L.loopKillEnabled then return end
        if not table.find(L.loopKillTargets, player) then return end

        newChar:WaitForChild("Humanoid", 5)
        newChar:WaitForChild("HumanoidRootPart", 5)
        local waitStart = tick()
        while (tick() - waitStart) < 5 do
            if newChar:FindFirstChild("Head") and (newChar:FindFirstChild("Torso") or newChar:FindFirstChild("UpperTorso")) then break end
            task.wait()
        end

        L.currentProcessing[player] = nil
        L.loopKillPlotWatchers[player] = nil

        getgenv().__DSTH(task.spawn(function()
            attackLoopKillTarget(player)
        end))
    end))
end

local function startLoopKill(targetPlayer)
    if not table.find(L.loopKillTargets, targetPlayer) then
        table.insert(L.loopKillTargets, targetPlayer)
    end

    registerLoopKillCharConn(targetPlayer)

    if not L.loopKillConnections[targetPlayer] then
        if not getgenv()._loopKillPendingRejoin then
            getgenv()._loopKillPendingRejoin = {}
        end

        local removeConn, rejoinConn

        removeConn = getgenv().__DST(Players.PlayerRemoving:Connect(function(leavingPlayer)
            if leavingPlayer == targetPlayer then
                local idx = table.find(L.loopKillTargets, leavingPlayer)
                if idx then table.remove(L.loopKillTargets, idx) end
                L.currentProcessing[leavingPlayer] = nil
                L.loopKillPlotWatchers[leavingPlayer] = nil
                if L.loopKillCharConns[leavingPlayer] then
                    L.loopKillCharConns[leavingPlayer]:Disconnect()
                    L.loopKillCharConns[leavingPlayer] = nil
                end

                getgenv()._loopKillPendingRejoin[leavingPlayer.Name] = true

                StarterGui:SetCore("SendNotification", {
                    Title = "[ Loop Kill - 타겟 나감 ]",
                    Text = leavingPlayer.Name .. "님이 나갔습니다. 재입장 시 즉시 공격 재개.",
                    Duration = 4
                })

                rejoinConn = getgenv().__DST(Players.PlayerAdded:Connect(function(newPlayer)
                    if newPlayer.Name == targetPlayer.Name
                        and getgenv()._loopKillPendingRejoin
                        and getgenv()._loopKillPendingRejoin[newPlayer.Name] then

                        getgenv()._loopKillPendingRejoin[newPlayer.Name] = nil
                        if rejoinConn then rejoinConn:Disconnect(); rejoinConn = nil end

                        task.wait(0.1)
                        if L.loopKillEnabled or #L.loopKillTargets > 0 then
                            startLoopKill(newPlayer)
                            StarterGui:SetCore("SendNotification", {
                                Title = "[ Loop Kill 재개 ]",
                                Text = newPlayer.Name .. "님이 재입장해 공격을 즉시 재개합니다.",
                                Duration = 4
                            })
                        end
                    end
                end))

                if L.loopKillConnections[leavingPlayer] == removeConn then
                    L.loopKillConnections[leavingPlayer] = nil
                end
                removeConn:Disconnect()

                if #L.loopKillTargets == 0 and not next(getgenv()._loopKillPendingRejoin) then
                    L.loopKillEnabled = false
                end
            end
        end))

        L.loopKillConnections[targetPlayer] = removeConn
    end

    if not L.loopKillEnabled then
        L.loopKillEnabled = true
    end

    attackLoopKillTarget(targetPlayer)
end

local function stopTarget()
    if T.targetUpdateLoop then
        task.cancel(T.targetUpdateLoop)
        T.targetUpdateLoop = nil
    end
    if T.targetLeaveConn then
        T.targetLeaveConn:Disconnect()
        T.targetLeaveConn = nil
    end
    if T.targetGui then
        pcall(function() T.targetGui:Destroy() end)
        T.targetGui = nil
    end
    T.targetPlayer = nil
end

local function createTargetGui(targetPlayer)
    stopTarget()
    T.targetPlayer = targetPlayer

    local targetUserId, targetName =
        targetPlayer and targetPlayer.UserId or nil,
        targetPlayer and targetPlayer.Name or nil
    local targetDisplayName = targetPlayer and targetPlayer.DisplayName or targetName or "Unknown"

    local function resolveTargetPlayer()
        if targetUserId then
            local byId = Players:GetPlayerByUserId(targetUserId)
            if byId then
                return byId
            end
        end
        if targetName then
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Name == targetName then
                    return p
                end
            end
        end
        return nil
    end

    local sg = getgenv().__DSN("ScreenGui")
    sg.Name = "TargetInfoGui"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999999997
    sg.IgnoreGuiInset = true
    sg.Parent = lp:WaitForChild("PlayerGui")
    T.targetGui = sg

    local frame = getgenv().__DSN("Frame")
    frame.Name = "TargetFrame"
    frame.Size = UDim2.new(0, 230, 0, 162)
    frame.Position = UDim2.new(0, 8, 1, -170)
    frame.AnchorPoint = Vector2.new(0, 0)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    frame.BackgroundTransparency = 0.15
    frame.BorderSizePixel = 0
    frame.Parent = sg
    makeDraggable(frame)

    local corner = getgenv().__DSN("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = getgenv().__DSN("UIStroke")
    stroke.Color = Color3.fromRGB(255, 80, 80)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = frame

    local closeBtn = getgenv().__DSN("TextButton")
    closeBtn.Size = UDim2.new(0, 18, 0, 18)
    closeBtn.Position = UDim2.new(1, -22, 0, 4)
    closeBtn.Text = ""
    closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    closeBtn.TextSize = 11
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BackgroundTransparency = 1
    closeBtn.ZIndex = 10
    closeBtn.Parent = frame
    getgenv().__DST(closeBtn.MouseButton1Click:Connect(function() stopTarget() end))

    local nameLabel = getgenv().__DSN("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -26, 0, 22)
    nameLabel.Position = UDim2.new(0, 8, 0, 4)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Text = targetDisplayName .. " ( " .. targetName .. " ) : In Server"
    nameLabel.Parent = frame

    local divider = getgenv().__DSN("Frame")
    divider.Size = UDim2.new(1, -16, 0, 1)
    divider.Position = UDim2.new(0, 8, 0, 25)
    divider.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    divider.BackgroundTransparency = 0.7
    divider.BorderSizePixel = 0
    divider.Parent = frame

    local posLabel = getgenv().__DSN("TextLabel")
    posLabel.Name = "PosLabel"
    posLabel.Size = UDim2.new(1, -16, 0, 20)
    posLabel.Position = UDim2.new(0, 8, 0, 29)
    posLabel.BackgroundTransparency = 1
    posLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    posLabel.Font = Enum.Font.Gotham
    posLabel.TextSize = 12
    posLabel.TextXAlignment = Enum.TextXAlignment.Left
    posLabel.TextYAlignment = Enum.TextYAlignment.Top
    posLabel.TextWrapped = true
    posLabel.Text = "Target Position : -, -, -"
    posLabel.Parent = frame

    local sitLabel = getgenv().__DSN("TextLabel")
    sitLabel.Name = "SitLabel"
    sitLabel.Size = UDim2.new(1, -16, 0, 18)
    sitLabel.Position = UDim2.new(0, 8, 0, 48)
    sitLabel.BackgroundTransparency = 1
    sitLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    sitLabel.Font = Enum.Font.Gotham
    sitLabel.TextSize = 12
    sitLabel.TextXAlignment = Enum.TextXAlignment.Left
    sitLabel.Text = "Sit : -"
    sitLabel.Parent = frame

    local isHomeLabel = getgenv().__DSN("TextLabel")
    isHomeLabel.Name = "IsHomeLabel"
    isHomeLabel.Size = UDim2.new(1, -16, 0, 18)
    isHomeLabel.Position = UDim2.new(0, 8, 0, 66)
    isHomeLabel.BackgroundTransparency = 1
    isHomeLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    isHomeLabel.Font = Enum.Font.Gotham
    isHomeLabel.TextSize = 12
    isHomeLabel.TextXAlignment = Enum.TextXAlignment.Left
    isHomeLabel.Text = "Is Home : -"
    isHomeLabel.Parent = frame

    local blobLabel = getgenv().__DSN("TextLabel")
    blobLabel.Name = "BlobLabel"
    blobLabel.Size = UDim2.new(1, -80, 0, 18)
    blobLabel.Position = UDim2.new(0, 8, 0, 84)
    blobLabel.BackgroundTransparency = 1
    blobLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    blobLabel.Font = Enum.Font.Gotham
    blobLabel.TextSize = 12
    blobLabel.TextXAlignment = Enum.TextXAlignment.Left
    blobLabel.Text = "Blob : -"
    blobLabel.Parent = frame

    local blobDeleteBtn = getgenv().__DSN("TextButton")
    blobDeleteBtn.Name = "BlobDeleteBtn"
    blobDeleteBtn.Size = UDim2.new(0, 58, 0, 18)
    blobDeleteBtn.Position = UDim2.new(1, -66, 0, 84)
    blobDeleteBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    blobDeleteBtn.BackgroundTransparency = 0.2
    blobDeleteBtn.BorderSizePixel = 0
    blobDeleteBtn.Text = "Delete"
    blobDeleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    blobDeleteBtn.TextSize = 11
    blobDeleteBtn.Font = Enum.Font.GothamBold
    blobDeleteBtn.ZIndex = 10
    blobDeleteBtn.Parent = frame
    local blobDeleteBtnCorner = getgenv().__DSN("UICorner")
    blobDeleteBtnCorner.CornerRadius = UDim.new(0, 4)
    blobDeleteBtnCorner.Parent = blobDeleteBtn
    local _blobDeleteRunning = false
    getgenv().__DST(blobDeleteBtn.MouseButton1Click:Connect(function()
        if _blobDeleteRunning then return end
        _blobDeleteRunning = true
        blobDeleteBtn.Text = "..."
        blobDeleteBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        getgenv().__DSTH(task.spawn(function()
            local tp = T.targetPlayer
            if not tp then
                blobDeleteBtn.Text = "Delete"
                blobDeleteBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
                _blobDeleteRunning = false
                return
            end

            local targetNameStr, FallenY = tp.Name, workspace.FallenPartsDestroyHeight
            local targetY = (FallenY <= -50000 and -49999) or (FallenY <= -100 and -99) or -100
            local dropPos, spawnedToys =
                CFrame.new(0, targetY, 9999),
                workspace:FindFirstChild(targetNameStr .. "SpawnedInToys")
            if not spawnedToys then
                blobDeleteBtn.Text = "Delete"
                blobDeleteBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
                _blobDeleteRunning = false
                return
            end

            local items = {}
            for _, child in ipairs(spawnedToys:GetChildren()) do
                if child.Name == "CreatureBlobman" and child:FindFirstChildOfClass("VehicleSeat") then
                    table.insert(items, child)
                end
            end

            for _, item in ipairs(items) do
                if item and item.Parent then
                    local char = lp.Character
                    local root, hum =
                        char and char:FindFirstChild("HumanoidRootPart"),
                        char and char:FindFirstChildOfClass("Humanoid")
                    if not char or not root or not hum then break end

                    local vs = item:FindFirstChildOfClass("VehicleSeat")
                    if vs and not (vs.Occupant and vs.Occupant ~= hum) and vs.Parent then
                        root.Anchored = true
                        vs:Sit(hum)

                        task.wait(0.1)
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                        task.wait()
                        if item.PrimaryPart then item:SetPrimaryPartCFrame(dropPos) end

                        root.Anchored = true
                        task.wait(0.03)
                        root.Anchored = false

                        task.wait(0.05)
                    end
                end
            end

            blobDeleteBtn.Text = "Delete"
            blobDeleteBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
            _blobDeleteRunning = false
        end))
    end))

    local tractorLabel = getgenv().__DSN("TextLabel")
    tractorLabel.Name = "TractorLabel"
    tractorLabel.Size = UDim2.new(1, -80, 0, 18)
    tractorLabel.Position = UDim2.new(0, 8, 0, 102)
    tractorLabel.BackgroundTransparency = 1
    tractorLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    tractorLabel.Font = Enum.Font.Gotham
    tractorLabel.TextSize = 12
    tractorLabel.TextXAlignment = Enum.TextXAlignment.Left
    tractorLabel.Text = "Tractor : -"
    tractorLabel.Parent = frame

    local tractorDeleteBtn = getgenv().__DSN("TextButton")
    tractorDeleteBtn.Name = "TractorDeleteBtn"
    tractorDeleteBtn.Size = UDim2.new(0, 58, 0, 18)
    tractorDeleteBtn.Position = UDim2.new(1, -66, 0, 102)
    tractorDeleteBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    tractorDeleteBtn.BackgroundTransparency = 0.2
    tractorDeleteBtn.BorderSizePixel = 0
    tractorDeleteBtn.Text = "Delete"
    tractorDeleteBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tractorDeleteBtn.TextSize = 11
    tractorDeleteBtn.Font = Enum.Font.GothamBold
    tractorDeleteBtn.ZIndex = 10
    tractorDeleteBtn.Parent = frame
    local tractorDeleteBtnCorner = getgenv().__DSN("UICorner")
    tractorDeleteBtnCorner.CornerRadius = UDim.new(0, 4)
    tractorDeleteBtnCorner.Parent = tractorDeleteBtn
    local _tractorDeleteRunning = false
    getgenv().__DST(tractorDeleteBtn.MouseButton1Click:Connect(function()
        if _tractorDeleteRunning then return end
        _tractorDeleteRunning = true
        tractorDeleteBtn.Text = "..."
        tractorDeleteBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        getgenv().__DSTH(task.spawn(function()
            local tp = T.targetPlayer
            if not tp then
                tractorDeleteBtn.Text = "Delete"
                tractorDeleteBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
                _tractorDeleteRunning = false
                return
            end

            local targetNameStr, FallenY = tp.Name, workspace.FallenPartsDestroyHeight
            local targetY = (FallenY <= -50000 and -49999) or (FallenY <= -100 and -99) or -100
            local dropPos, spawnedToys =
                CFrame.new(0, targetY, 9999),
                workspace:FindFirstChild(targetNameStr .. "SpawnedInToys")
            if not spawnedToys then
                tractorDeleteBtn.Text = "Delete"
                tractorDeleteBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
                _tractorDeleteRunning = false
                return
            end

            local items = {}
            for _, child in ipairs(spawnedToys:GetChildren()) do
                if (child.Name == "TractorGreen" or child.Name == "TractorRed" or child.Name == "TractorOrange")
                    and child:FindFirstChildOfClass("VehicleSeat") then
                    table.insert(items, child)
                end
            end

            for _, item in ipairs(items) do
                if item and item.Parent then
                    local char = lp.Character
                    local root, hum =
                        char and char:FindFirstChild("HumanoidRootPart"),
                        char and char:FindFirstChildOfClass("Humanoid")
                    if not char or not root or not hum then break end

                    local vs = item:FindFirstChildOfClass("VehicleSeat")
                    if vs and not (vs.Occupant and vs.Occupant ~= hum) and vs.Parent then
                        root.Anchored = true
                        vs:Sit(hum)

                        task.wait(0.1)
                        hum:ChangeState(Enum.HumanoidStateType.Running)
                        task.wait()
                        if item.PrimaryPart then item:SetPrimaryPartCFrame(dropPos) end

                        root.Anchored = true
                        task.wait(0.03)
                        root.Anchored = false

                        task.wait(0.05)
                    end
                end
            end

            tractorDeleteBtn.Text = "Delete"
            tractorDeleteBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
            _tractorDeleteRunning = false
        end))
    end))

    local isGucciLabel = getgenv().__DSN("TextLabel")
    isGucciLabel.Name = "IsBlobGucciLabel"
    isGucciLabel.Size = UDim2.new(1, -16, 0, 18)
    isGucciLabel.Position = UDim2.new(0, 8, 0, 120)
    isGucciLabel.BackgroundTransparency = 1
    isGucciLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    isGucciLabel.Font = Enum.Font.Gotham
    isGucciLabel.TextSize = 12
    isGucciLabel.TextXAlignment = Enum.TextXAlignment.Left
    isGucciLabel.Text = "Is BlobGucci : No"
    isGucciLabel.Parent = frame

    local isTrainGucciLabel = getgenv().__DSN("TextLabel")
    isTrainGucciLabel.Name = "IsTrainGucciLabel"
    isTrainGucciLabel.Size = UDim2.new(1, -16, 0, 18)
    isTrainGucciLabel.Position = UDim2.new(0, 8, 0, 138)
    isTrainGucciLabel.BackgroundTransparency = 1
    isTrainGucciLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
    isTrainGucciLabel.Font = Enum.Font.Gotham
    isTrainGucciLabel.TextSize = 12
    isTrainGucciLabel.TextXAlignment = Enum.TextXAlignment.Left
    isTrainGucciLabel.Text = "Is TrainGucci : No"
    isTrainGucciLabel.Parent = frame

    T.targetUpdateLoop = getgenv().__DSTH(task.spawn(function()
        while T.targetPlayer and T.targetGui and T.targetGui.Parent do
            pcall(function()
                local tp = resolveTargetPlayer() or T.targetPlayer
                if tp then
                    T.targetPlayer = tp
                    targetUserId = tp.UserId
                    targetName = tp.Name
                    targetDisplayName = tp.DisplayName or targetDisplayName
                end

                if tp and tp.Parent == Players then
                    nameLabel.Text = targetDisplayName .. " ( " .. targetName .. " ) : In Server"
                    nameLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                else
                    nameLabel.Text = targetDisplayName .. " ( " .. targetName .. " ) : Left"
                    nameLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                end

                local char = tp and tp.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if root then
                    local cf = root.CFrame
                    local px, py, pz =
                        math.floor(cf.X * 10 + 0.5) / 10,
                        math.floor(cf.Y * 10 + 0.5) / 10,
                        math.floor(cf.Z * 10 + 0.5) / 10
                    posLabel.Text = "Target Position : " .. px .. ", " .. py .. ", " .. pz
                else
                    posLabel.Text = "Target Position : -, -, -"
                end

                local isHome = false
                pcall(function()
                    local mySpawnFolder, plotItems =
                        Workspace:FindFirstChild(lp.Name .. "SpawnedInToys"),
                        Workspace:FindFirstChild("PlotItems")
                    local playersInPlots, char =
                        plotItems and plotItems:FindFirstChild("PlayersInPlots"),
                        tp and tp.Character

                    if mySpawnFolder and char and char:IsDescendantOf(mySpawnFolder) then
                        isHome = true
                    end

                    if not isHome and playersInPlots then
                        if playersInPlots:FindFirstChild(targetName) then
                            isHome = true
                        elseif char and char:IsDescendantOf(playersInPlots) then
                            isHome = true
                        end
                    end
                end)
                if isHome then
                    isHomeLabel.Text = "Is Home : Yes"
                    isHomeLabel.TextColor3 = Color3.fromRGB(100, 230, 100)
                else
                    isHomeLabel.Text = "Is Home : No"
                    isHomeLabel.TextColor3 = Color3.fromRGB(230, 100, 100)
                end

                local blobCount = 0
                pcall(function()
                    local spawnedToys = workspace:FindFirstChild(targetName .. "SpawnedInToys")
                    if spawnedToys then
                        for _, child in ipairs(spawnedToys:GetChildren()) do
                            if child.Name == "CreatureBlobman" then
                                blobCount = blobCount + 1
                            end
                        end
                    end
                end)
                blobLabel.Text = "Blob : " .. blobCount

                local tractorCount = 0
                pcall(function()
                    local spawnedToys = workspace:FindFirstChild(targetName .. "SpawnedInToys")
                    if spawnedToys then
                        for _, child in ipairs(spawnedToys:GetChildren()) do
                            if child.Name == "TractorGreen" or child.Name == "TractorRed" or child.Name == "TractorOrange" then
                                tractorCount = tractorCount + 1
                            end
                        end
                    end
                end)
                tractorLabel.Text = "Tractor : " .. tractorCount

                local isGucci = nil
                pcall(function()
                    local tChar = tp and tp.Character
                    local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
                    if tHum then
                        local seated, seatPart = tHum.Sit, tHum.SeatPart
                        if not seated and seatPart and seatPart:IsA("VehicleSeat") then
                            isGucci = true
                        elseif not seated and not seatPart then
                            isGucci = false
                        end
                    end
                end)
                if isGucci == true then
                    isGucciLabel.Text = "Is BlobGucci : Yes"
                    isGucciLabel.TextColor3 = Color3.fromRGB(100, 230, 100)
                elseif isGucci == false then
                    isGucciLabel.Text = "Is BlobGucci : No"
                    isGucciLabel.TextColor3 = Color3.fromRGB(230, 100, 100)
                else
                    isGucciLabel.Text = "Is BlobGucci : No"
                    isGucciLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
                end

                local isTrainGucci = false
                pcall(function()
                    local tChar = tp and tp.Character
                    local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
                    if tHum then
                        local seated, seatPart = tHum.Sit, tHum.SeatPart
                        if not seated and seatPart and seatPart:IsA("Seat") and not seatPart:IsA("VehicleSeat") then
                            isTrainGucci = true
                        else
                            isTrainGucci = false
                        end
                    end
                end)
                if isTrainGucci == true then
                    isTrainGucciLabel.Text = "Is TrainGucci : Yes"
                    isTrainGucciLabel.TextColor3 = Color3.fromRGB(100, 230, 100)
                else
                    isTrainGucciLabel.Text = "Is TrainGucci : No"
                    isTrainGucciLabel.TextColor3 = Color3.fromRGB(230, 100, 100)
                end

                pcall(function()
                    local tChar = tp and tp.Character
                    local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
                    if tHum then
                        if tHum.Sit then
                            local isHeldValue = Players:FindFirstChild(tp.Name) and Players:FindFirstChild(tp.Name):FindFirstChild("IsHeld")
                            local isHeld = isHeldValue ~= nil and isHeldValue.Value == true
                            if isHeld then
                                sitLabel.Text = "Sit : No"
                                sitLabel.TextColor3 = Color3.fromRGB(230, 100, 100)
                            else
                                sitLabel.Text = "Sit : Yes"
                                sitLabel.TextColor3 = Color3.fromRGB(100, 230, 100)
                            end
                        else
                            sitLabel.Text = "Sit : No"
                            sitLabel.TextColor3 = Color3.fromRGB(230, 100, 100)
                        end
                    else
                        sitLabel.Text = "Sit : -"
                        sitLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
                    end
                end)
            end)
            task.wait(0.1)
        end
    end))

    T.targetLeaveConn = getgenv().__DST(Players.PlayerRemoving:Connect(function(p)
        if p == T.targetPlayer or (targetUserId and p.UserId == targetUserId) then
        end
    end))
end

local function setTarget(keyword)
    if not keyword or keyword == "" then
        stopTarget()
        StarterGui:SetCore("SendNotification", {Title = "[ Target ]", Text = "타겟이 해제되었습니다.", Duration = 2})
        return
    end
    local found, kw = nil, keyword:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            if p.Name:lower():sub(1, #kw) == kw or p.DisplayName:lower():sub(1, #kw) == kw then
                found = p
                break
            end
        end
    end
    if found then
        createTargetGui(found)
        StarterGui:SetCore("SendNotification", {
            Title = "[ Target 설정됨 ]",
            Text = found.DisplayName .. " (@" .. found.Name .. ") 을 타겟으로 지정했습니다.",
            Duration = 3
        })
    else
        StarterGui:SetCore("SendNotification", {
            Title = "[ Target 실패 ]",
            Text = "'" .. keyword .. "' 와 매칭되는 플레이어를 찾지 못했습니다.",
            Duration = 3
        })
    end
end

local function clearVelocity(character)
    if not character then return end
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end
end

local function togglekickAll(state)
    if state then
        if Z.kickAllEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ kick ]", Text = "이미 켜져 있습니다.", Duration = 2})
            return
        end
        Z.kickAllEnabled = true
        
        Z.IsDesyncing = false
        Z.LastWalkCFrame = nil

        if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
            Z.LastWalkCFrame = lp.Character.HumanoidRootPart.CFrame
        end

        Z.MovementTrackerConn = getgenv().__DST(RunService.Heartbeat:Connect(function()
            if Z.kickAllEnabled and not Z.IsDesyncing then
                if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                    Z.LastWalkCFrame = lp.Character.HumanoidRootPart.CFrame
                end
            end
        end))

        RunService:BindToRenderStep("PerfectDesyncRender", Enum.RenderPriority.Camera.Value - 1, function()
            if Z.kickAllEnabled and Z.IsDesyncing and Z.LastWalkCFrame then
                if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                    lp.Character.HumanoidRootPart.CFrame = Z.LastWalkCFrame
                end
            end
        end)

        StarterGui:SetCore("SendNotification", {Title = "[ kick -all 켜짐 ]", Text = "올킥 시작", Duration = 2})

        local lagArgs = {
            workspace:WaitForChild("SpawnLocation"),
            CFrame.new(-2147483648, 0, -2147483648, 1, 0, 0, 0, 1, 0, 0, 0, 1)
        }

        local kickRemote = nil
        Z.kickAllLoopConn = getgenv().__DST(RunService.Heartbeat:Connect(function()
            if not Z.kickAllEnabled then return end
            if not kickRemote or not kickRemote.Parent then
                local ge = ReplicatedStorage:FindFirstChild("GrabEvents")
                kickRemote = ge and ge:FindFirstChild("CreateGrabLine")
                if not kickRemote then return end
            end
            pcall(kickRemote.FireServer, kickRemote, table.unpack(lagArgs))
        end))

        local maxSlots = 24
        local lastTargetTime = tick()

        Z.kickAllLogicConn = getgenv().__DSTH(task.spawn(function()
            local assignedSlotIndices = {}

            while Z.kickAllEnabled do
                local playersList = Players:GetPlayers()
                local targets = {}

                for _, p in ipairs(playersList) do
                    if p ~= lp then
                        local isFriend = false
                        pcall(function() isFriend = lp:IsFriendsWith(p.UserId) end)
                        if not isFriend then table.insert(targets, p) end
                    end
                end

                local currentCenter = Z.LastWalkCFrame and Z.LastWalkCFrame.Position or Vector3.new(0, 0, 0)

                local currentTargetSet = {}
                local usedIndices = {}

                for _, p in ipairs(targets) do
                    currentTargetSet[p] = true
                    if assignedSlotIndices[p] then
                        usedIndices[assignedSlotIndices[p]] = true
                    end
                end

                for p in pairs(assignedSlotIndices) do
                    if not currentTargetSet[p] then
                        assignedSlotIndices[p] = nil
                    end
                end

                for _, p in ipairs(targets) do
                    if not assignedSlotIndices[p] then
                        for slotIdx = 1, maxSlots do
                            if not usedIndices[slotIdx] then
                                assignedSlotIndices[p] = slotIdx
                                usedIndices[slotIdx] = true
                                break
                            end
                        end
                    end
                end

                local assignedSlots = {}
                for p, slotIdx in pairs(assignedSlotIndices) do
                    if slotIdx <= 15 then
                        local slotAngle = (slotIdx - 1) * (2 * math.pi / 15)
                        local layer1Center = currentCenter + Vector3.new(0, 20, 0)
                        local radius1 = 18
                        local slotX = layer1Center.X + radius1 * math.cos(slotAngle)
                        local slotZ = layer1Center.Z + radius1 * math.sin(slotAngle)
                        assignedSlots[p] = CFrame.new(slotX, layer1Center.Y, slotZ)
                    else
                        local idxInLayer2 = slotIdx - 15
                        local slotAngle = (idxInLayer2 - 1) * (2 * math.pi / 9)
                        local layer2Center = currentCenter + Vector3.new(0, 30, 0)
                        local radius2 = 12
                        local slotX = layer2Center.X + radius2 * math.cos(slotAngle)
                        local slotZ = layer2Center.Z + radius2 * math.sin(slotAngle)
                        assignedSlots[p] = CFrame.new(slotX, layer2Center.Y, slotZ)
                    end
                end

                local capturedTargets = {}

                for i, p in ipairs(targets) do
                    if not Z.kickAllEnabled then break end

                    local targetChar = workspace:FindFirstChild(p.Name)
                    if targetChar and targetChar:FindFirstChild("Torso") and targetChar:FindFirstChild("Head") and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then

                        local targetCFrame = assignedSlots[p]
                        if targetCFrame then

                        local dist = (targetChar.Torso.Position - targetCFrame.Position).Magnitude

                        local rayOrigin = targetChar.Torso.Position
                        local rayDirection = Vector3.new(0, -5, 0)
                        local raycastParams = RaycastParams.new()
                        raycastParams.FilterDescendantsInstances = {targetChar, lp.Character}
                        raycastParams.FilterType = Enum.RaycastFilterType.Exclude

                        local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
                        local hitFloor = false

                        if raycastResult then
                            local hitModel = raycastResult.Instance:FindFirstAncestorOfClass("Model")
                            if not (hitModel and Players:GetPlayerFromCharacter(hitModel)) then
                                hitFloor = true
                            end
                        end

                        if not (dist <= 20 and not hitFloor) then

                        Z.IsDesyncing = true
                        
                        local pStartTime = tick()
                        while Z.kickAllEnabled and (tick() - pStartTime) < 0.3 do
                            targetChar = workspace:FindFirstChild(p.Name)
                            if not targetChar or not targetChar:FindFirstChild("Torso") or not targetChar:FindFirstChild("Head") then break end

                            if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                                local hrp = lp.Character.HumanoidRootPart
                                hrp.CFrame = targetChar.Torso.CFrame * CFrame.new(0, 0, 1)
                                hrp.AssemblyLinearVelocity = Vector3.new(0, 0.1, 0)
                            end

                            local ownerArgs = {targetChar.Torso, targetChar.Torso.CFrame}
                            ReplicatedStorage:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner"):FireServer(table.unpack(ownerArgs))

                            local partOwner = targetChar.Head:FindFirstChild("PartOwner")
                            if partOwner and partOwner.Value == lp.Name then
                                table.insert(capturedTargets, {
                                    char = targetChar,
                                    cframe = targetCFrame
                                })
                                lastTargetTime = tick()
                                break
                            end

                            task.wait()
                        end
                        end
                        end
                    end
                end

                if #capturedTargets > 0 then
                    for _, captured in ipairs(capturedTargets) do
                        local tChar = captured.char
                        local tCFrame = captured.cframe

                        if tChar and tChar:FindFirstChild("Torso") then
                            clearVelocity(tChar)
                            tChar.Torso.CFrame = tCFrame

                            local targetHRP = tChar:FindFirstChild("HumanoidRootPart")
                            local targetTorso = tChar:FindFirstChild("Torso")
                            
                            getgenv().__DSTH(task.spawn(function()
                                local freezeStart = tick()
                                while (tick() - freezeStart) < 1.5 do
                                    if not tChar or not tChar.Parent then break end
                                    if targetHRP and targetHRP.Parent then
                                        targetHRP.AssemblyLinearVelocity = Vector3.zero
                                        targetHRP.AssemblyAngularVelocity = Vector3.zero
                                    end
                                    if targetTorso and targetTorso.Parent then
                                        targetTorso.AssemblyLinearVelocity = Vector3.zero
                                        targetTorso.AssemblyAngularVelocity = Vector3.zero
                                    end
                                    task.wait()
                                end
                            end))

                            local destroyArgs = {tChar.Torso}
                            ReplicatedStorage:WaitForChild("GrabEvents"):WaitForChild("DestroyGrabLine"):FireServer(table.unpack(destroyArgs))
                            ReplicatedStorage:WaitForChild("GrabEvents"):WaitForChild("DestroyGrabLine"):FireServer(table.unpack(destroyArgs))
                        end
                    end
                end

                if Z.IsDesyncing and (tick() - lastTargetTime) >= 0.3 then
                    Z.IsDesyncing = false
                    if Z.LastWalkCFrame and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = lp.Character.HumanoidRootPart
                        hrp.CFrame = Z.LastWalkCFrame
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                    end
                end

                task.wait(0.01)
            end
        end))

    else
        if not Z.kickAllEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ kick ]", Text = "이미 꺼져 있습니다.", Duration = 2})
            return
        end
        Z.kickAllEnabled = false
        
        if Z.kickAllLoopConn then
            Z.kickAllLoopConn:Disconnect()
            Z.kickAllLoopConn = nil
        end
        if Z.kickAllLogicConn then
            task.cancel(Z.kickAllLogicConn)
            Z.kickAllLogicConn = nil
        end
        
        if Z.MovementTrackerConn then
            Z.MovementTrackerConn:Disconnect()
            Z.MovementTrackerConn = nil
        end

        RunService:UnbindFromRenderStep("PerfectDesyncRender")

        Z.IsDesyncing = false
        if Z.LastWalkCFrame and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = lp.Character.HumanoidRootPart
            hrp.CFrame = Z.LastWalkCFrame
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            Z.LastWalkCFrame = nil
        end

        StarterGui:SetCore("SendNotification", {Title = "[ kick 꺼짐 ]", Text = "kick -all이 중지되었습니다.", Duration = 2})

        local destroyArgs = {workspace:WaitForChild("SpawnLocation")}
        for i = 1, 5 do
            pcall(function()
                ReplicatedStorage:WaitForChild("GrabEvents"):WaitForChild("DestroyGrabLine"):FireServer(table.unpack(destroyArgs))
            end)
        end
    end
end

local coreGuiTypeNames = {
    ["inventory"] = Enum.CoreGuiType.Backpack,
    ["leaderboard"] = Enum.CoreGuiType.PlayerList,
    ["emotes"] = Enum.CoreGuiType.EmotesMenu
}

for _, enumItem in ipairs(Enum.CoreGuiType:GetEnumItems()) do
    coreGuiTypeNames[enumItem.Name:lower()] = enumItem
end

do
    local ContextActionService = game:GetService("ContextActionService")
    local INPUT_PRIORITY = Enum.ContextActionPriority.High.Value

    local Camera = workspace.CurrentCamera
    getgenv().__DST(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        local newCamera = workspace.CurrentCamera
        if newCamera then
            Camera = newCamera
        end
    end))

    local Spring = {}
    Spring.__index = Spring

    function Spring.new(freq, pos)
        local self = setmetatable({}, Spring)
        self.f = freq
        self.p = pos
        self.v = pos * 0
        return self
    end

    function Spring:Update(dt, goal)
        local f = self.f * 2 * math.pi
        local p0 = self.p
        local v0 = self.v

        local offset = goal - p0
        local decay = math.exp(-f * dt)

        local p1 = goal + (v0 * dt - offset * (f * dt + 1)) * decay
        local v1 = (f * dt * (offset * f - v0) + v0) * decay

        self.p = p1
        self.v = v1

        return p1
    end

    function Spring:Reset(pos)
        self.p = pos
        self.v = pos * 0
    end

    local cameraPos = Vector3.new()
    local cameraRot = Vector2.new()
    local cameraFov = 70
    local fcRunning = false

    local velSpring = Spring.new(5, Vector3.new())
    local panSpring = Spring.new(5, Vector2.new())

    local keyboard = {
        W = 0, A = 0, S = 0, D = 0, E = 0, Q = 0, Up = 0, Down = 0, LeftShift = 0,
    }
    local mouseInput = { Delta = Vector2.new() }

    local NAV_KEYBOARD_SPEED = Vector3.new(1, 1, 1)
    local PAN_MOUSE_SPEED = Vector2.new(1, 1) * (math.pi / 64)
    local NAV_ADJ_SPEED = 0.75
    local NAV_SHIFT_MUL = 0.25
    local navSpeed = 1

    local function InputVel(dt)
        navSpeed = math.clamp(navSpeed + dt * (keyboard.Up - keyboard.Down) * NAV_ADJ_SPEED, 0.01, 4)
        local kKeyboard = Vector3.new(
            keyboard.D - keyboard.A,
            keyboard.E - keyboard.Q,
            keyboard.S - keyboard.W
        ) * NAV_KEYBOARD_SPEED
        local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
        return kKeyboard * (navSpeed * (shift and NAV_SHIFT_MUL or 1))
    end

    local function InputPan(dt)
        local kMouse = mouseInput.Delta * PAN_MOUSE_SPEED
        mouseInput.Delta = Vector2.new()
        return kMouse
    end

    local function Keypress(action, state, input)
        keyboard[input.KeyCode.Name] = state == Enum.UserInputState.Begin and 1 or 0
        return Enum.ContextActionResult.Sink
    end

    local function MousePan(action, state, input)
        local delta = input.Delta
        mouseInput.Delta = Vector2.new(-delta.y, -delta.x)
        return Enum.ContextActionResult.Sink
    end

    local function Zero(t)
        for k, v in pairs(t) do
            t[k] = v * 0
        end
    end

    local function StartCapture()
        ContextActionService:BindActionAtPriority("FreecamKeyboard", Keypress, false, INPUT_PRIORITY,
            Enum.KeyCode.W,
            Enum.KeyCode.A,
            Enum.KeyCode.S,
            Enum.KeyCode.D,
            Enum.KeyCode.E,
            Enum.KeyCode.Q,
            Enum.KeyCode.Up,
            Enum.KeyCode.Down
        )
        ContextActionService:BindActionAtPriority("FreecamMousePan", MousePan, false, INPUT_PRIORITY, Enum.UserInputType.MouseMovement)
    end

    local function StopCapture()
        navSpeed = 1
        Zero(keyboard)
        Zero(mouseInput)
        ContextActionService:UnbindAction("FreecamKeyboard")
        ContextActionService:UnbindAction("FreecamMousePan")
    end

    local function GetFocusDistance(cameraFrame)
        local znear = 0.1
        local viewport = Camera.ViewportSize
        local projy = 2 * math.tan(cameraFov / 2)
        local projx = viewport.x / viewport.y * projy
        local fx = cameraFrame.rightVector
        local fy = cameraFrame.upVector
        local fz = cameraFrame.lookVector

        local minVect = Vector3.new()
        local minDist = 512

        for x = 0, 1, 0.5 do
            for y = 0, 1, 0.5 do
                local cx = (x - 0.5) * projx
                local cy = (y - 0.5) * projy
                local offset = fx * cx - fy * cy + fz
                local origin = cameraFrame.p + offset * znear
                local _, hit = workspace:FindPartOnRay(Ray.new(origin, offset.unit * minDist))
                local dist = (hit - origin).magnitude
                if minDist > dist then
                    minDist = dist
                    minVect = offset.unit
                end
            end
        end

        return fz:Dot(minVect) * minDist
    end

    local function StepFreecam(dt)
        local vel = velSpring:Update(dt, InputVel(dt))
        local pan = panSpring:Update(dt, InputPan(dt))

        local zoomFactor = math.sqrt(math.tan(math.rad(70 / 2)) / math.tan(math.rad(cameraFov / 2)))

        cameraRot = cameraRot + pan * Vector2.new(0.75, 1) * 8 * (dt / zoomFactor)
        cameraRot = Vector2.new(math.clamp(cameraRot.x, -math.rad(90), math.rad(90)), cameraRot.y % (2 * math.pi))

        local cameraCFrame = CFrame.new(cameraPos) * CFrame.fromOrientation(cameraRot.x, cameraRot.y, 0) * CFrame.new(vel * Vector3.new(1, 1, 1) * 64 * dt)
        cameraPos = cameraCFrame.p

        Camera.CFrame = cameraCFrame
        Camera.Focus = cameraCFrame * CFrame.new(0, 0, -GetFocusDistance(cameraCFrame))
        Camera.FieldOfView = cameraFov
    end

    local savedMouseBehavior, savedMouseIconEnabled, savedCameraType, savedCameraFocus, savedCameraCFrame

    local function PushPlayerState()
        Camera.FieldOfView = 70

        savedCameraType = Camera.CameraType
        Camera.CameraType = Enum.CameraType.Custom

        savedCameraCFrame = Camera.CFrame
        savedCameraFocus = Camera.Focus

        savedMouseIconEnabled = UserInputService.MouseIconEnabled
        UserInputService.MouseIconEnabled = true

        savedMouseBehavior = UserInputService.MouseBehavior
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end

    local function PopPlayerState()
        Camera.FieldOfView = 70

        Camera.CameraType = savedCameraType
        savedCameraType = nil

        Camera.CFrame = savedCameraCFrame
        savedCameraCFrame = nil

        Camera.Focus = savedCameraFocus
        savedCameraFocus = nil

        UserInputService.MouseIconEnabled = savedMouseIconEnabled
        savedMouseIconEnabled = nil

        UserInputService.MouseBehavior = savedMouseBehavior
        savedMouseBehavior = nil
    end

    Z.StartFreecam = function(pos)
        if fcRunning then
            Z.StopFreecam()
        end
        local cameraCFrame = Camera.CFrame
        if pos then
            cameraCFrame = pos
        end
        cameraRot = Vector2.new()
        cameraPos = cameraCFrame.p
        cameraFov = Camera.FieldOfView

        velSpring:Reset(Vector3.new())
        panSpring:Reset(Vector2.new())

        PushPlayerState()
        RunService:BindToRenderStep("Freecam", Enum.RenderPriority.Camera.Value, StepFreecam)
        StartCapture()
        fcRunning = true
    end

    Z.StopFreecam = function()
        if not fcRunning then return end
        StopCapture()
        RunService:UnbindFromRenderStep("Freecam")
        PopPlayerState()
        workspace.Camera.FieldOfView = 70
        fcRunning = false
    end
end

Z.ShutdownCommands = function()
    local genv = getgenv()
    local function disc(c)
        if c then pcall(function() c:Disconnect() end) end
    end
    local function getMenuRemote(name)
        local menu = ReplicatedStorage:FindFirstChild("MenuToys")
        return menu and menu:FindFirstChild(name)
    end

    local steps = {
        function() if A.charAntiLagEnabled then toggleCharAntiLag(false) end end,
        function() if S.shaderEnabled then toggleShader(false) end end,
        function() if A.antiFlingEnabled then toggleAntiFling(false) end end,
        function() if Z.kickAllEnabled then togglekickAll(false) end end,
        function() if L.autoWarningResetEnabled then toggleAutoWarningReset(false) end end,
        function() if M.jerkEnabled then toggleJerk(false) end end,
        function() if Z.StopFreecam then Z.StopFreecam() end end,
        function() if M.bangTarget or M.bangLoopConnection then stopBang() end end,
        function() if M.getBangEnabled then stopGetBang() end end,
        function() if M.getSuckEnabled then stopGetSuck() end end,
        function() if L.flingEnabled then stopFling() end end,
        function() if M.walkToEnabled then stopWalkTo() end end,
        function() if T.targetPlayer or T.targetUpdateLoop or T.targetGui then stopTarget() end end,
        function() if M.orbitEnabled then stopOrbit() end end,
        function()
            if M.headSitTarget or M.headSitConnection then
                disc(M.headSitConnection); M.headSitConnection = nil
                disc(M.headSitTargetLeaveConn); M.headSitTargetLeaveConn = nil
                disc(M.headSitRespawnConn); M.headSitRespawnConn = nil
                disc(M.headSitDiedConn); M.headSitDiedConn = nil
                M.headSitTarget = nil
                local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.Sit = false end
            end
        end,
        function()
            if M.invisEnabled then
                M.invisEnabled = false
                disc(M.invisLoopConnection); M.invisLoopConnection = nil
                disc(M.invisCamConnection); M.invisCamConnection = nil
            end
        end,
        function()
            if M.noBlurEnabled then
                M.noBlurEnabled = false
                for _, c in ipairs(M.noBlurConns or {}) do disc(c) end
                M.noBlurConns = nil
                for obj, wasEnabled in pairs(M.noBlurSaved or {}) do
                    if obj and obj.Parent then pcall(function() obj.Enabled = wasEnabled end) end
                end
                M.noBlurSaved = nil
            end
        end,
        function()
            if M.xrayLoopConnection or M.xrayEnabled then
                disc(M.xrayLoopConnection); M.xrayLoopConnection = nil
                M.xrayEnabled = false
                M.xrayApply(0)
            end
        end,
        function()
            disc(M.thirdpConnection); M.thirdpConnection = nil
            disc(M.zoomWheelConn); M.zoomWheelConn = nil
            disc(M.zoomPinchConn); M.zoomPinchConn = nil
        end,
        function()
            M.vflyToggleEnabled = false
            M.vflyToggleActive = false
            M.vflyToggleSpeed = nil
            disc(M.vflyInputConn); M.vflyInputConn = nil
            disc(M.vflyInputEndConn); M.vflyInputEndConn = nil
        end,
        function()
            if M.voidTpEnabled or M.voidTpHBC then
                M.voidTpEnabled = false
                AntiGrabTP_ActiveV1 = false
                disc(M.voidTpHBC); M.voidTpHBC = nil
                local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                if hrp and M.voidTpOriginalPosition then hrp.CFrame = M.voidTpOriginalPosition end
                M.voidTpOriginalPosition = nil
            end
        end,
        function()
            if M.loopTpEnabled or M.loopTpHBC then
                M.loopTpEnabled = false
                AntiGrabTP_ActiveV2 = false
                disc(M.loopTpHBC); M.loopTpHBC = nil
                local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                if hrp and M.loopTpOriginalPosition then hrp.CFrame = M.loopTpOriginalPosition end
                M.loopTpOriginalPosition = nil
            end
        end,
        function()
            if L.lpwdEnabled then
                L.lpwdEnabled = false
                if L.lpwdLoop then task.cancel(L.lpwdLoop); L.lpwdLoop = nil end
                for _, conn in pairs(L.lpwdLeaveConns) do disc(conn) end
                L.lpwdLeaveConns = {}
                pcall(function() if type(genv.AntiStickyGBT) ~= "nil" then genv.AntiStickyGBT = false end end)
                pcall(function() AntiStickyGBT = false end)
                local listRef = type(genv.playersInLoop1V) == "table" and genv.playersInLoop1V
                    or (type(playersInLoop1V) == "table" and playersInLoop1V or nil)
                if listRef then
                    for _, tp in ipairs(L.lpwdTargets) do
                        for i, v in ipairs(listRef) do
                            if v == tp.Name then table.remove(listRef, i); break end
                        end
                    end
                end
                L.lpwdTargets = {}
            end
        end,
        function()
            if next(L.lpPendikSessions) then
                for _, s in pairs(L.lpPendikSessions) do
                    s.enabled = false
                    if s.charConn then disc(s.charConn); s.charConn = nil end
                end
                L.lpPendikSessions = {}
            end
        end,
        function()
            if _G.AutoSitConnection then disc(_G.AutoSitConnection); _G.AutoSitConnection = nil end
        end,
        function()
            if genv.Loopovenall and genv.Loopovenall.Stop then genv.Loopovenall.Stop() end
        end,
        function()
            if _G.ChamsToggle or _G.ChamsConnections then
                _G.ChamsToggle = false
                if _G.ChamsConnections then
                    for _, c in pairs(_G.ChamsConnections) do disc(c) end
                    _G.ChamsConnections = {}
                end
                for _, obj in pairs(workspace:GetDescendants()) do
                    if obj:IsA("Highlight") and obj.Name == "ChamsESP_Highlight" then obj:Destroy() end
                end
            end
        end,
        function()
            if _G.AntiVoidT then
                _G.AntiVoidT = false
                local folder = workspace:FindFirstChild("AntiVoidPlatforms")
                if folder then folder:Destroy() end
                local platform = workspace:FindFirstChild("AntiVoidPlatform")
                if platform then platform:Destroy() end
                workspace.FallenPartsDestroyHeight = -110
            end
            if _G.UniqueInfiniteVoidActive then
                _G.UniqueInfiniteVoidActive = false
                workspace.FallenPartsDestroyHeight = -100
            end
        end,
        function()
            if genv.AntiBombRunning then
                genv.AntiBombRunning = false
                local folder = workspace:FindFirstChild(lp.Name .. "SpawnedInToys")
                local oven = folder and folder:FindFirstChild("OvenDarkGray")
                local remote = getMenuRemote("DestroyToy")
                if oven and remote then
                    remote:FireServer(oven)
                    local points = lp:FindFirstChild("UsedToyPoints")
                    if points then points.Value = points.Value - 5 end
                end
            end
        end,
        function()
            if _G.RGB_Toggle then
                _G.RGB_Toggle = false
                _G.RGB_State = "off"
                local folder = workspace:FindFirstChild(lp.Name .. "SpawnedInToys")
                local desk = folder and folder:FindFirstChild("RB")
                if desk then
                    local remote = getMenuRemote("DestroyToy")
                    if remote then remote:FireServer(desk) else desk:Destroy() end
                end
            end
        end,
        function()
            if genv._lagLoopEnabled then
                genv._lagLoopEnabled = false
                if genv._lagLoopThread then pcall(task.cancel, genv._lagLoopThread); genv._lagLoopThread = nil end
                local spawnLoc = workspace:FindFirstChild("SpawnLocation")
                local grabEvents = ReplicatedStorage:FindFirstChild("GrabEvents")
                local destroyLine = grabEvents and grabEvents:FindFirstChild("DestroyGrabLine")
                if spawnLoc and destroyLine then
                    for _ = 1, 5 do destroyLine:FireServer(spawnLoc) end
                end
            end
        end,
        function()
            genv.Pcld2OwnerRunning = false
            pcall(function() local f = workspace:FindFirstChild("PCLD2"); if f then f:Destroy() end end)
            genv._pcld2UsedNames = nil
        end,
        function()
            for _, key in ipairs({"Pcld2HeartbeatConn", "_pcld2AddConn", "_pcld2RemConn", "_pcldAddConn", "_pcldRemConn",
                "fGrabConnection", "LoopGrabInputConnection", "FKeyInputConnection", "HouseGrabConnection", "GrabDistanceConnection"}) do
                if genv[key] then disc(genv[key]); genv[key] = nil end
            end
        end,
        function()
            for _, key in ipairs({"LoopGrabActive", "FTargetGrabActive", "KickGrabActive", "FKeyAttackActive", "NoclipGrab",
                "PacketLag", "AntiHoleItems", "AntiVehicleToyEnabled"}) do
                if genv[key] then genv[key] = false end
            end
            for _, key in ipairs({"MasslessGrabToggle", "AntiBananaT"}) do
                if _G[key] then _G[key] = false end
            end
        end,
    }

    for _, step in ipairs(steps) do
        pcall(step)
    end
end

local processCommandPart2
local processCommandPart3
local function processCommand(msg)
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
    if #msg == 0 then return end

    if _scriptTerminated then return end

    local prefixLen = #COMMAND_PREFIX
    if COMMAND_PREFIX ~= "." then
        if msg:sub(1, prefixLen) == COMMAND_PREFIX then
            msg = "." .. msg:sub(prefixLen + 1)
        end
    end

    local lowerMsg = msg:lower()

    do
        local FTAP_ONLY_PLACE_ID = 6961824067
        local FTAP_COMMANDS = {
            ["ab"]=true, ["ab2"]=true, ["abv2"]=true, ["aip"]=true, ["noclipbarrier"]=true, ["antibomb"]=true, ["antifling"]=true, ["antiinplots"]=true, ["antilag"]=true, ["antivoid"]=true, ["antivt"]=true, ["autoreset"]=true, ["av"]=true, ["avinf"]=true, ["avt"]=true, ["barrier"]=true, ["bb"]=true, ["breakbarrier"]=true, ["breakpcld"]=true, ["bring"]=true, ["bringall"]=true, ["delarms"]=true, ["dellarm"]=true, ["dellegs"]=true, ["dellimbs"]=true, ["dellleg"]=true, ["delpcld"]=true, ["delrarm"]=true, ["delrleg"]=true, ["fling"]=true, ["gb"]=true, ["getblob"]=true, ["getplot"]=true, ["gp"]=true, ["hg"]=true, ["hide"]=true, ["hidepcld"]=true, ["housegrab"]=true, ["kg"]=true, ["kick"]=true, ["kickgrab"]=true, ["kill"]=true, ["lag"]=true, ["lg"]=true, ["loopbring"]=true, ["loopgoto"]=true, ["loopgrab"]=true, ["loopkill"]=true, ["looptp"]=true, ["loopwd"]=true, ["lpbring"]=true, ["lpgo"]=true, ["lpkill"]=true, ["lppendik"]=true, ["lpwd"]=true, ["ltp"]=true, ["masslessgrab"]=true, ["mg"]=true, ["ng"]=true, ["noclipgrab"]=true, ["oceanwalk"]=true, ["ow"]=true, ["packet"]=true, ["packetlag"]=true, ["pcld"]=true, ["pendik"]=true, ["ragdollgrab"]=true, ["reach"]=true, ["rg"]=true, ["sg"]=true, ["showpcld"]=true, ["spesp"]=true, ["spingrab"]=true, ["stickypartesp"]=true, ["takefood"]=true, ["takefood2"]=true, ["target"]=true, ["tc"]=true, ["tf"]=true, ["tf2"]=true, ["traincontrol"]=true, ["unab"]=true, ["unab2"]=true, ["unabv2"]=true, ["unaip"]=true, ["unnoclipbarrier"]=true, ["unantibomb"]=true, ["unantifling"]=true, ["unantiinplots"]=true, ["unantilag"]=true, ["unantivoid"]=true, ["unantivt"]=true, ["unautoreset"]=true, ["unav"]=true, ["unavt"]=true, ["unbarrier"]=true, ["unbreakpcld"]=true, ["unbringall"]=true, ["undelpcld"]=true, ["unfling"]=true, ["unhg"]=true, ["unhousegrab"]=true, ["unkg"]=true, ["unkick"]=true, ["unkickgrab"]=true, ["unlag"]=true, ["unlg"]=true, ["unloopbring"]=true, ["unloopgoto"]=true, ["unloopgrab"]=true, ["unloopkill"]=true, ["unlooptp"]=true, ["unloopwd"]=true, ["unlpbring"]=true, ["unlpgo"]=true, ["unlpkill"]=true, ["unlppendik"]=true, ["unlpwd"]=true, ["unltp"]=true, ["unmasslessgrab"]=true, ["unmg"]=true, ["unng"]=true, ["unnoclipgrab"]=true, ["unoceanwalk"]=true, ["unow"]=true, ["unpacket"]=true, ["unpacketlag"]=true, ["unpcld"]=true, ["unragdollgrab"]=true, ["unreach"]=true, ["unrg"]=true, ["unsg"]=true, ["unspesp"]=true, ["unspingrab"]=true, ["unstickypartesp"]=true, ["untakefood"]=true, ["untakefood2"]=true, ["untarget"]=true, ["untf"]=true, ["untf2"]=true, ["unvg"]=true, ["unvoidgrab"]=true, ["unvoidtp"]=true, ["unvtp"]=true, ["vg"]=true, ["voidgrab"]=true, ["voidtp"]=true, ["vtp"]=true,
        }
        local ftapCmdWord = lowerMsg:match("^%.([%w가-힣]+)")
        if ftapCmdWord and FTAP_COMMANDS[ftapCmdWord] and game.PlaceId ~= FTAP_ONLY_PLACE_ID then
            StarterGui:SetCore("SendNotification", {Title = "[ FTAP 명령어 ]", Text = "이 명령어는 FTAP에서만 사용할 수 있습니다.", Duration = 3})
            return
        end
    end

    if lowerMsg:match("^%.unautoexe%s+%S") or lowerMsg:match("^%.unautoexecute%s+%S") then
        local argStr = msg:match("^%.%a+%s+(.-)%s*$")
        if argStr and argStr ~= "" then
            if AutoExecConfig.CustomCommands[argStr] then
                AutoExecConfig.CustomCommands[argStr] = nil
                saveAutoExecConfig()
                StarterGui:SetCore("SendNotification", {Title = "[ 자동 실행 해제 ]", Text = "." .. argStr .. " 가 자동 실행에서 제거되었습니다.", Duration = 3})
            else
                StarterGui:SetCore("SendNotification", {Title = "[ 안내 ]", Text = "." .. argStr .. " 는 등록된 자동 실행 명령이 아닙니다.", Duration = 3})
            end
        end
        return
    end

    if lowerMsg:match("^%.autoexe%s+%S") or lowerMsg:match("^%.autoexecute%s+%S") then
        local argStr = msg:match("^%.%a+%s+(.-)%s*$")
        if argStr and argStr ~= "" then
            local baseCmd = argStr:match("^(%S+)")
            if not baseCmd or not VALID_COMMANDS_SET[baseCmd:lower()] then
                StarterGui:SetCore("SendNotification", {Title = "[ 안내 ]", Text = "." .. argStr .. " 는 존재하지 않는 명령어라 자동 실행에 등록할 수 없습니다.", Duration = 3})
                return
            end
            AutoExecConfig.CustomCommands[argStr] = game.PlaceId
            saveAutoExecConfig()
            StarterGui:SetCore("SendNotification", {Title = "[ 자동 실행 등록 ]", Text = "." .. argStr .. " 가 이 게임(PlaceId: " .. game.PlaceId .. ")에서만 자동 실행으로 등록되었습니다.", Duration = 3})
            processCommand("." .. argStr)
        end
        return
    end

    if lowerMsg == ".autoexe" or lowerMsg == ".autoexecute" then
            do openAutoExecGui()
        end
        return
    end

    if lowerMsg == ".exit" or lowerMsg == ".run" then
        pcall(function() game:Shutdown() end)
        pcall(function() lp:Kick("Exit command") end)
        return
    end

    if lowerMsg == ".kick -all" then
        togglekickAll(true)
    elseif lowerMsg == ".unkick" then
        togglekickAll(false)
        return
    end

    if lowerMsg == ".tptool" or lowerMsg == ".teleporttool" then
        local char = lp.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local backpack = lp:FindFirstChildOfClass("Backpack")
        if not backpack then return end
        local TpTool = getgenv().__DSN("Tool")
        TpTool.Name = "Teleport Tool"
        TpTool.RequiresHandle = false
        TpTool.Parent = backpack
        getgenv().__DST(TpTool.Activated:Connect(function()
            local currentChar = lp.Character
            local currentRoot = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
            local mouse = lp:GetMouse()
            local pos = mouse and mouse.Hit
            if not currentRoot or not pos then return end
            currentRoot.CFrame = CFrame.new(pos.X, pos.Y + 3, pos.Z, select(4, currentRoot.CFrame:components()))
        end))
        return
    end

    if lowerMsg:match("^%.prefix%s+(.+)$") or lowerMsg == ".prefix" then
        if lowerMsg == ".prefix" then
            StarterGui:SetCore("SendNotification", {
                Title = "[ Prefix ]",
                Text = "현재 접두사: '" .. COMMAND_PREFIX .. "'  |  사용법: .prefix [접두사]  (예: .prefix ;)",
                Duration = 4
            })
            return
        end
        local newPrefix = msg:match("^[%.%p%w]prefix%s+(.+)$") or msg:match("^%.prefix%s+(.+)$")
        if newPrefix then
            newPrefix = newPrefix:gsub("%s+$", "")
            COMMAND_PREFIX = newPrefix
            pcall(function()
                writefile("DShub prefix.txt", newPrefix)
            end)
            StarterGui:SetCore("SendNotification", {
                Title = "[ Prefix 변경됨 ]",
                Text = "명령어 접두사가 '" .. newPrefix .. "' 으로 변경되었습니다.\n예: " .. newPrefix .. "fly, " .. newPrefix .. "tp 등",
                Duration = 4
            })
        end
        return
    end

    if lowerMsg == ".iconesp" or lowerMsg == ".ie" then toggleIconEsp(true)
    elseif lowerMsg == ".uniconesp" or lowerMsg == ".unie" then toggleIconEsp(false)
    elseif lowerMsg == ".ne" or lowerMsg == ".nameesp" then toggleNameEsp(true)
    elseif lowerMsg == ".unne" or lowerMsg == ".unnameesp" then toggleNameEsp(false)
    elseif lowerMsg == ".stickypartesp" or lowerMsg == ".spesp" then toggleStickyPartEsp(true)
    elseif lowerMsg == ".unstickypartesp" or lowerMsg == ".unspesp" then toggleStickyPartEsp(false)
    elseif lowerMsg:sub(1, 6) == ".chat " then sendChatMessage(msg:sub(7))
    elseif lowerMsg:sub(1, 5) == ".say " then sendChatMessage(msg:sub(6))

    elseif lowerMsg == ".fpsboost" or lowerMsg == ".fps" then toggleFpsBoost(true)
    elseif lowerMsg == ".unfpsboost" or lowerMsg == ".unfps" then toggleFpsBoost(false)

    elseif lowerMsg == ".shader" then toggleShader(true)
    elseif lowerMsg == ".unshader" then toggleShader(false)

    elseif lowerMsg == ".antiafk" then toggleAntiAfk(true)
    elseif lowerMsg == ".unantiafk" then toggleAntiAfk(false)

    elseif lowerMsg == ".showpcld2" or lowerMsg == ".pcld2" then
    local Players, RunService, StarterGui =
        game:GetService("Players"),
        game:GetService("RunService"),
        game:GetService("StarterGui")

    if getgenv().Pcld2OwnerRunning then
        StarterGui:SetCore("SendNotification", {
            Title = "[ PCLD2 ESP ]",
            Text = "PCLD2 ESP스크립트가 이미 실행 중입니다.",
            Duration = 5
        })
        return
    end

    if getgenv().PcldOwnerRunning then
        getgenv().PcldOwnerRunning = false
        if getgenv().PcldHeartbeatConn then
            pcall(function() getgenv().PcldHeartbeatConn:Disconnect() end)
            getgenv().PcldHeartbeatConn = nil
        end
        if getgenv()._pcldAddConn then
            pcall(function() getgenv()._pcldAddConn:Disconnect() end)
            getgenv()._pcldAddConn = nil
        end
        if getgenv()._pcldRemConn then
            pcall(function() getgenv()._pcldRemConn:Disconnect() end)
            getgenv()._pcldRemConn = nil
        end
        local pcldFolder = workspace:FindFirstChild("PCLD")
        if pcldFolder then pcldFolder:Destroy() end
        getgenv()._pcldUsedNames = nil
    end

    if getgenv().Pcld2OwnerRunning then
        getgenv().Pcld2OwnerRunning = false

        if getgenv().Pcld2HeartbeatConn then
            pcall(function()
                getgenv().Pcld2HeartbeatConn:Disconnect()
            end)
            getgenv().Pcld2HeartbeatConn = nil
        end

        if getgenv()._pcld2AddConn then
            pcall(function()
                getgenv()._pcld2AddConn:Disconnect()
            end)
            getgenv()._pcld2AddConn = nil
        end

        if getgenv()._pcld2RemConn then
            pcall(function()
                getgenv()._pcld2RemConn:Disconnect()
            end)
            getgenv()._pcld2RemConn = nil
        end

        local pcld2Folder = workspace:FindFirstChild("PCLD2")
        if pcld2Folder then
            pcld2Folder:Destroy()
        end
    end

    StarterGui:SetCore("SendNotification", {
        Title = "[ PCLD2 ESP ]",
        Text = "PCLD2 ESP 스크립트가 성공적으로 실행되었습니다.",
        Duration = 5
    })

    local pcld2Folder = workspace:FindFirstChild("PCLD2")
    if pcld2Folder then
        pcld2Folder:Destroy()
    end
    pcld2Folder = getgenv().__DSN("Folder")
    pcld2Folder.Name = "PCLD2"
    pcld2Folder.Parent = workspace

    local trackers = {}
    local avatarUserIdMap = {}

    local R6_DEFAULTS = {
        Head = {Size = Vector3.new(2, 1, 1), Offset = CFrame.new(0, 1.5, 0)},
        Torso = {Size = Vector3.new(2.02, 2.02, 1.02), Offset = CFrame.new(0, 0, 0)},
        ["Left Arm"] = {Size = Vector3.new(1.02, 2.02, 1.02), Offset = CFrame.new(-1.5, 0, 0)},
        ["Right Arm"] = {Size = Vector3.new(1.02, 2.02, 1.02), Offset = CFrame.new(1.5, 0, 0)},
        ["Left Leg"] = {Size = Vector3.new(1.02, 2.02, 1.02), Offset = CFrame.new(-0.5, -2, 0)},
        ["Right Leg"] = {Size = Vector3.new(1.02, 2.02, 1.02), Offset = CFrame.new(0.5, -2, 0)},
    }

    local R15_NAME_MAP = {
        Torso = "UpperTorso",
        ["Left Arm"] = "LeftUpperArm",
        ["Right Arm"] = "RightUpperArm",
        ["Left Leg"] = "LeftUpperLeg",
        ["Right Leg"] = "RightUpperLeg",
    }

    local function getOrCreateTracker(pcld)
        if trackers[pcld] then return trackers[pcld] end

        local rigModel = getgenv().__DSN("Model")
        rigModel.Name = "PCLD_Rig"
        rigModel.Parent = pcld2Folder

        local basePivot = pcld.CFrame * CFrame.new(0, 0.5, 0.25)

        for partName, data in pairs(R6_DEFAULTS) do
            local part = getgenv().__DSN("Part")
            part.Name = partName
            part.Anchored = true
            part.CanCollide = false
            part.CanQuery = false
            part.CanTouch = false
            part.Massless = true
            part.Transparency = 0.8
            part.Material = Enum.Material.Neon
            part.Color = Color3.new(0, 0, 0)
            part.Size = data.Size
            part.CFrame = basePivot * data.Offset
            part.Parent = rigModel

            local selectionBox = getgenv().__DSN("SelectionBox")
            selectionBox.Name = "PcldOutline"
            selectionBox.Adornee = part
            selectionBox.LineThickness = 0.01
            selectionBox.Color3 = Color3.new(1, 1, 1)
            selectionBox.SurfaceTransparency = 0.8
            selectionBox.SurfaceColor3 = Color3.new(0, 0, 0)
            selectionBox.Transparency = 0.3
            selectionBox.Parent = part
        end

        local torso = rigModel:FindFirstChild("Torso")
        if torso then rigModel.PrimaryPart = torso end

        local billboardGui = getgenv().__DSN("BillboardGui")
        billboardGui.Name = "PcldNameTag"
        billboardGui.Adornee = rigModel:FindFirstChild("Head") or torso
        billboardGui.Size = UDim2.new(4.6, 0, 1.1, 0)
        billboardGui.StudsOffset = Vector3.new(0, 1.5, 0)
        billboardGui.AlwaysOnTop = false
        billboardGui.Parent = rigModel

        local avatarImage = getgenv().__DSN("ImageLabel")
        avatarImage.Name = "AvatarImage"
        avatarImage.Size = UDim2.new(0.22, 0, 0.85, 0)
        avatarImage.Position = UDim2.new(0.13, 0, -0.1, 0)
        avatarImage.BackgroundTransparency = 1
        avatarImage.ScaleType = Enum.ScaleType.Fit
        avatarImage.Visible = false
        avatarImage.Parent = billboardGui
        avatarUserIdMap[avatarImage] = 0

        local textLabel = getgenv().__DSN("TextLabel")
        textLabel.Name = "NameText"
        textLabel.Size = UDim2.new(0.5, 0, 0.8, 0)
        textLabel.Position = UDim2.new(0.34, 0, 0, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.TextColor3 = Color3.new(1, 1, 1)
        textLabel.TextStrokeTransparency = 0
        textLabel.TextScaled = true
        textLabel.TextWrapped = true
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.Text = "Waiting for owner..."
        textLabel.Parent = billboardGui

        rigModel:SetAttribute("TargetCFrame", pcld.CFrame)

        trackers[pcld] = rigModel
        return rigModel
    end

    local function updateTracker(tracker, pcld, alpha, pcldOwner)
        local currentPivot = tracker:GetAttribute("TargetCFrame") or pcld.CFrame
        local targetPivot = currentPivot:Lerp(pcld.CFrame, alpha)
        tracker:SetAttribute("TargetCFrame", targetPivot)

        local targetPlayer = pcldOwner.playerOf(pcld)

        local targetChar = targetPlayer and targetPlayer.Character
        local targetHrp = targetChar and (targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso"))
        local displayPivot = targetPivot * CFrame.new(0, 0.5, 0.25)

        do
            local nameTagVis = tracker:FindFirstChild("PcldNameTag")
            if nameTagVis then
                -- targetHrp가 없는 모든 경우(캐릭터 로딩/리스폰 중, 주인 미배정 등)를 포함해
                -- 매 프레임 반드시 명시적으로 값을 세팅한다. 이전에는 조건이 안 맞으면
                -- Enabled 값을 그대로 두어(=갱신 누락) 한 번 false로 고정되면 영원히
                -- 이름표가 안 나타나는 버그가 있었다.
                if targetHrp then
                    nameTagVis.Enabled = (targetHrp.Position - targetPivot.Position).Magnitude >= 10
                else
                    nameTagVis.Enabled = true
                end
            end
        end

        for partName, data in pairs(R6_DEFAULTS) do
            local rigPart = tracker:FindFirstChild(partName)
            if rigPart then
                local synced = false
                local sizeOffset = (partName == "Head") and Vector3.new(0, 0, 0) or Vector3.new(0.02, 0.02, 0.02)

                if targetChar and targetHrp then
                    local sourcePart = targetChar:FindFirstChild(partName)
                        or targetChar:FindFirstChild(R15_NAME_MAP[partName] or "")
                    if sourcePart then
                        local relCF = targetHrp.CFrame:ToObjectSpace(sourcePart.CFrame)
                        rigPart.Size = sourcePart.Size + sizeOffset
                        rigPart.CFrame = displayPivot * relCF
                        synced = true
                    end
                end
                if not synced then
                    rigPart.Size = data.Size
                    rigPart.CFrame = displayPivot * data.Offset
                end
            end
        end
    end

    local core = M.PcldCore({
        Players = Players,
        RunService = RunService,
        trackers = trackers,
        avatarUserIdMap = avatarUserIdMap,
        getOrCreateTracker = getOrCreateTracker,
        updateTracker = updateTracker,
        runningKey = "Pcld2OwnerRunning",
        heartbeatKey = "Pcld2HeartbeatConn",
        addKey = "_pcld2AddConn",
        remKey = "_pcld2RemConn",
        usedNamesKey = "_pcld2UsedNames",
    })

    M.PcldLines({
        Players = Players,
        RunService = RunService,
        pcldSet = core.pcldSet,
        trackers = trackers,
        runningKey = "Pcld2OwnerRunning",
        lineIdKey = "_pcld2LineId",
    })

    if getgenv().ForceStopPcldLoop then
        pcall(function() getgenv().ForceStopPcldLoop:Disconnect() end)
        getgenv().ForceStopPcldLoop = nil
    end

elseif lowerMsg == ".hidepcld2" or lowerMsg == ".unpcld2" then
    local StarterGui = game:GetService("StarterGui")

    getgenv().Pcld2OwnerRunning = false
    if getgenv().Pcld2HeartbeatConn then
        pcall(function() getgenv().Pcld2HeartbeatConn:Disconnect() end)
        getgenv().Pcld2HeartbeatConn = nil
    end
    if getgenv()._pcld2AddConn then
        pcall(function() getgenv()._pcld2AddConn:Disconnect() end)
        getgenv()._pcld2AddConn = nil
    end
    if getgenv()._pcld2RemConn then
        pcall(function() getgenv()._pcld2RemConn:Disconnect() end)
        getgenv()._pcld2RemConn = nil
    end
    local pcld2Folder = workspace:FindFirstChild("PCLD2")
    if pcld2Folder then pcld2Folder:Destroy() end
    getgenv()._pcld2UsedNames = nil

    StarterGui:SetCore("SendNotification", {
        Title = "[ PCLD2 ESP ]",
        Text = "Pcld2 ESP가 종료되었습니다.",
        Duration = 5
    })

elseif lowerMsg == ".hidepcld" or lowerMsg == ".unpcld" then
    local StarterGui = game:GetService("StarterGui")

    getgenv().PcldOwnerRunning = false

    StarterGui:SetCore("SendNotification", {
        Title = "[ PCLD ESP ]",
        Text = "Pcld ESP가 종료되었습니다.",
        Duration = 5
    })

    if getgenv().PcldHeartbeatConn then
        pcall(function() getgenv().PcldHeartbeatConn:Disconnect() end)
        getgenv().PcldHeartbeatConn = nil
    end

    if getgenv()._pcldAddConn then
        pcall(function() getgenv()._pcldAddConn:Disconnect() end)
        getgenv()._pcldAddConn = nil
    end

    if getgenv()._pcldRemConn then
        pcall(function() getgenv()._pcldRemConn:Disconnect() end)
        getgenv()._pcldRemConn = nil
    end

    if getgenv().ForceStopPcldLoop then
        pcall(function() getgenv().ForceStopPcldLoop:Disconnect() end)
        getgenv().ForceStopPcldLoop = nil
    end

    local pcldFolder = workspace:FindFirstChild("PCLD")
    if pcldFolder then
        pcldFolder:Destroy()
    end
    getgenv()._pcldUsedNames = nil

    getgenv().Pcld2OwnerRunning = false
    if getgenv().Pcld2HeartbeatConn then
        pcall(function() getgenv().Pcld2HeartbeatConn:Disconnect() end)
        getgenv().Pcld2HeartbeatConn = nil
    end
    if getgenv()._pcld2AddConn then
        pcall(function() getgenv()._pcld2AddConn:Disconnect() end)
        getgenv()._pcld2AddConn = nil
    end
    if getgenv()._pcld2RemConn then
        pcall(function() getgenv()._pcld2RemConn:Disconnect() end)
        getgenv()._pcld2RemConn = nil
    end
    local pcld2Folder = workspace:FindFirstChild("PCLD2")
    if pcld2Folder then pcld2Folder:Destroy() end
    getgenv()._pcld2UsedNames = nil

elseif lowerMsg == ".showpcld" or lowerMsg == ".pcld" then
    local Players, RunService, StarterGui =
        game:GetService("Players"),
        game:GetService("RunService"),
        game:GetService("StarterGui")

    if getgenv().PcldOwnerRunning then
        StarterGui:SetCore("SendNotification", {
            Title = "[ PCLD ESP ]",
            Text = "PCLD ESP스크립트가 이미 실행 중입니다.",
            Duration = 5
        })
        return
    end

    if getgenv().Pcld2OwnerRunning then
        getgenv().Pcld2OwnerRunning = false
        if getgenv().Pcld2HeartbeatConn then
            pcall(function() getgenv().Pcld2HeartbeatConn:Disconnect() end)
            getgenv().Pcld2HeartbeatConn = nil
        end
        if getgenv()._pcld2AddConn then
            pcall(function() getgenv()._pcld2AddConn:Disconnect() end)
            getgenv()._pcld2AddConn = nil
        end
        if getgenv()._pcld2RemConn then
            pcall(function() getgenv()._pcld2RemConn:Disconnect() end)
            getgenv()._pcld2RemConn = nil
        end
        local pcld2Folder = workspace:FindFirstChild("PCLD2")
        if pcld2Folder then pcld2Folder:Destroy() end
        getgenv()._pcld2UsedNames = nil
    end

    if getgenv().PcldOwnerRunning then
        getgenv().PcldOwnerRunning = false

        if getgenv().PcldHeartbeatConn then
            pcall(function()
                getgenv().PcldHeartbeatConn:Disconnect()
            end)
            getgenv().PcldHeartbeatConn = nil
        end

        if getgenv()._pcldAddConn then
            pcall(function()
                getgenv()._pcldAddConn:Disconnect()
            end)
            getgenv()._pcldAddConn = nil
        end

        if getgenv()._pcldRemConn then
            pcall(function()
                getgenv()._pcldRemConn:Disconnect()
            end)
            getgenv()._pcldRemConn = nil
        end

        if getgenv().ForceStopPcldLoop then
            pcall(function() getgenv().ForceStopPcldLoop:Disconnect() end)
            getgenv().ForceStopPcldLoop = nil
        end

        local pcldFolder = workspace:FindFirstChild("PCLD")
        if pcldFolder then
            pcldFolder:Destroy()
        end
    end

    StarterGui:SetCore("SendNotification", {
        Title = "[ PCLD ESP ]",
        Text = "PCLD ESP 스크립트가 성공적으로 실행되었습니다.",
        Duration = 5
    })

    local pcldFolder = workspace:FindFirstChild("PCLD")
    if pcldFolder then
        pcldFolder:Destroy()
    end
    pcldFolder = getgenv().__DSN("Folder")
    pcldFolder.Name = "PCLD"
    pcldFolder.Parent = workspace

    local trackers = {}
    local avatarUserIdMap = {}

    local function getOrCreateTracker(pcld)
        if trackers[pcld] then return trackers[pcld] end

        local tracker = getgenv().__DSN("Part")
        tracker.Name = "PCLDTracker"
        tracker.Anchored = true
        tracker.CanCollide = false
        tracker.CanQuery = false
        tracker.CanTouch = false
        tracker.Massless = true
        tracker.Transparency = 0.7
        tracker.Material = Enum.Material.Neon
        tracker.Color = Color3.new(0, 0, 0)
        tracker.Size = pcld.Size
        tracker.CFrame = pcld.CFrame
        tracker.Parent = pcldFolder

        local selectionBox = getgenv().__DSN("SelectionBox")
        selectionBox.Name = "PcldOutline"
        selectionBox.Adornee = tracker
        selectionBox.LineThickness = 0.01
        selectionBox.Color3 = Color3.new(1, 1, 1)
        selectionBox.SurfaceTransparency = 0.97
        selectionBox.SurfaceColor3 = Color3.new(0, 0, 0)
        selectionBox.Transparency = 0.3
        selectionBox.Parent = tracker

        local billboardGui = getgenv().__DSN("BillboardGui")
        billboardGui.Name = "PcldNameTag"
        billboardGui.Adornee = tracker
        billboardGui.Size = UDim2.new(4.6, 0, 1.1, 0)
        billboardGui.StudsOffset = Vector3.new(0, 0.5, 0)
        billboardGui.AlwaysOnTop = false
        billboardGui.Parent = tracker

        local avatarImage = getgenv().__DSN("ImageLabel")
        avatarImage.Name = "AvatarImage"
        avatarImage.Size = UDim2.new(0.22, 0, 0.85, 0)
        avatarImage.Position = UDim2.new(0.13, 0, -0.1, 0)
        avatarImage.BackgroundTransparency = 1
        avatarImage.ScaleType = Enum.ScaleType.Fit
        avatarImage.Visible = false
        avatarImage.Parent = billboardGui
        avatarUserIdMap[avatarImage] = 0

        local textLabel = getgenv().__DSN("TextLabel")
        textLabel.Name = "NameText"
        textLabel.Size = UDim2.new(0.5, 0, 0.8, 0)
        textLabel.Position = UDim2.new(0.34, 0, 0, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.TextColor3 = Color3.new(1, 1, 1)
        textLabel.TextStrokeTransparency = 0
        textLabel.TextScaled = true
        textLabel.TextWrapped = true
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.Text = "Waiting for owner..."
        textLabel.Parent = billboardGui

        trackers[pcld] = tracker
        return tracker
    end

    local function updateTracker(tracker, pcld, alpha, pcldOwner)
        tracker.CFrame = tracker.CFrame:Lerp(pcld.CFrame, alpha)
        if tracker.Size ~= pcld.Size then
            tracker.Size = pcld.Size
        end

        do
            local nameTagVis = tracker:FindFirstChild("PcldNameTag")
            if nameTagVis then
                local targetPlayer, boolVal = pcldOwner.playerOf(pcld)
                local targetChar = targetPlayer and targetPlayer.Character
                local targetHrp = targetChar and (targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso"))
                if targetHrp then
                    nameTagVis.Enabled = (targetHrp.Position - tracker.Position).Magnitude >= 10
                elseif not boolVal then
                    nameTagVis.Enabled = true
                end
            end
        end
    end

    local core = M.PcldCore({
        Players = Players,
        RunService = RunService,
        trackers = trackers,
        avatarUserIdMap = avatarUserIdMap,
        getOrCreateTracker = getOrCreateTracker,
        updateTracker = updateTracker,
        runningKey = "PcldOwnerRunning",
        heartbeatKey = "PcldHeartbeatConn",
        addKey = "_pcldAddConn",
        remKey = "_pcldRemConn",
        usedNamesKey = "_pcldUsedNames",
    })
    local _pcldSet = core.pcldSet

    M.PcldLines({
        Players = Players,
        RunService = RunService,
        pcldSet = core.pcldSet,
        trackers = trackers,
        runningKey = "PcldOwnerRunning",
        lineIdKey = "_pcldLineId",
    })

    if getgenv().ForceStopPcldLoop then
        pcall(function() getgenv().ForceStopPcldLoop:Disconnect() end)
        getgenv().ForceStopPcldLoop = nil
    end


    elseif lowerMsg == ".delpcld" or lowerMsg == ".breakpcld" then
        toggleAutoReset(true)
    elseif lowerMsg == ".undelpcld" or lowerMsg == ".unbreakpcld" then
        toggleAutoReset(false)

    elseif lowerMsg == ".loopreset" or lowerMsg == ".lpreset" then
        toggleloopreset(true)
    elseif lowerMsg == ".unloopreset" or lowerMsg == ".unlpreset" then
        toggleloopreset(false)

    elseif lowerMsg == ".autoreset" then
        toggleAutoWarningReset(true)
    elseif lowerMsg == ".unautoreset" then
        toggleAutoWarningReset(false)

    elseif lowerMsg == ".takefood" or lowerMsg == ".tf" then
        loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/takefood'))()
    elseif lowerMsg == ".untakefood" or lowerMsg == ".untf" or lowerMsg == ".untf2" or lowerMsg == ".untakefood2" then
        if getgenv().AntiHoleItems then
            getgenv().AntiHoleItems = false
            
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "[ 안티 홀드파트 ]",
                Text = "꺼짐",
                Duration = 3
            })
        else
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "[ 안티 홀드파트 ]",
                Text = "이미 꺼져있음",
                Duration = 3
            })
        end

    elseif lowerMsg == ".tf2" or lowerMsg == ".takefood2" then
        loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/takefood2'))()

    elseif lowerMsg == ".antifling" then toggleAntiFling(true)
    elseif lowerMsg == ".unantifling" then toggleAntiFling(false)
    elseif lowerMsg == ".noclipbarrier" or lowerMsg == ".barrier" then
        toggleNoclipBarrier(true)
    elseif lowerMsg == ".unnoclipbarrier" or lowerMsg == ".unbarrier" then
        toggleNoclipBarrier(false)

    elseif lowerMsg == ".breakbarrier" or lowerMsg == ".bb" then
        pcall(function()
            loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/breakbarrier'))()
        end)
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "[ Breakbarrier ]",
            Text = "Barrier breaker: [ ON ]",
            Duration = 3
        })

    elseif lowerMsg == ".ab" or lowerMsg == ".antibomb" then
        loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/antibombspawn'))()
    elseif lowerMsg == ".unantibomb" or lowerMsg == ".unab" then
        if not getgenv().AntiBombRunning then
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "[ 안티 폭탄 ]",
                Text = "이미 꺼져있습니다.",
                Duration = 3
            })
            return
        end

        getgenv().AntiBombRunning = false

        local Players, ReplicatedStorage, Workspace =
            game:GetService("Players"),
            game:GetService("ReplicatedStorage"),
            game:GetService("Workspace")

        local LocalPlayer = Players.LocalPlayer
        local myToyFolderName = LocalPlayer.Name .. "SpawnedInToys"
        local myToyFolder = Workspace:FindFirstChild(myToyFolderName)

        if myToyFolder then
            local myOven = myToyFolder:FindFirstChild("OvenDarkGray")
            if myOven then
                ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("DestroyToy"):FireServer(myOven)

                if LocalPlayer:FindFirstChild("UsedToyPoints") then
                    LocalPlayer.UsedToyPoints.Value = LocalPlayer.UsedToyPoints.Value - 5
                end

                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "[ 안티 폭탄 ]",
                    Text = "오븐을 삭제하고 작동을 중지했습니다.",
                    Duration = 3
                })
            end
        end

    elseif lowerMsg == ".abv2" or lowerMsg == ".ab2" then
        loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/antibombspawnv2'))()
    elseif lowerMsg == ".unabv2" or lowerMsg == ".unab2" then
        if not getgenv().AntiBombRunning then
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "[ 안티 폭탄 ]",
                Text = "이미 꺼져있습니다.",
                Duration = 3
            })
            return
        end

        getgenv().AntiBombRunning = false

        local Players, ReplicatedStorage, Workspace =
            game:GetService("Players"),
            game:GetService("ReplicatedStorage"),
            game:GetService("Workspace")

        local LocalPlayer = Players.LocalPlayer
        local myToyFolderName = LocalPlayer.Name .. "SpawnedInToys"
        local myToyFolder = Workspace:FindFirstChild(myToyFolderName)

        if myToyFolder then
            local myOven = myToyFolder:FindFirstChild("OvenDarkGray")
            if myOven then
                ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("DestroyToy"):FireServer(myOven)

                if LocalPlayer:FindFirstChild("UsedToyPoints") then
                    LocalPlayer.UsedToyPoints.Value = LocalPlayer.UsedToyPoints.Value - 5
                end

                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "[ 안티 폭탄 ]",
                    Text = "오븐을 삭제하고 작동을 중지했습니다.",
                    Duration = 3
                })
            end
        end

    elseif lowerMsg == ".antiinplots" or lowerMsg == ".aip" then
        toggleAntiInPlots(true)
    elseif lowerMsg == ".unantiinplots" or lowerMsg == ".unaip" then
        toggleAntiInPlots(false)

    elseif lowerMsg == ".oceanwalk" or lowerMsg == ".ow" then
        toggleOceanWalk(true)

    elseif lowerMsg == ".unoceanwalk" or lowerMsg == ".unow" then
        toggleOceanWalk(false)

    elseif lowerMsg == ".autoexit" then
        toggleAntiLag(true)

    elseif lowerMsg == ".unautoexit" then
        if not A.antiLagLoop then
            StarterGui:SetCore("SendNotification", {Title = "[ Auto-Exit ]", Text = "이미 꺼져 있습니다.", Duration = 2})
        else
            toggleAntiLag(false)
        end

    elseif lowerMsg == ".antilag" then
        toggleCharAntiLag(true)

    elseif lowerMsg == ".unantilag" then
        toggleCharAntiLag(false)

    elseif lowerMsg == ".rj" or lowerMsg:sub(1, 4) == ".rj " then
        local rjArg = ""
        if lowerMsg:sub(1, 4) == ".rj " then rjArg = lowerMsg:sub(5):gsub("^%s+", ""):gsub("%s+$", "") end

        if rjArg ~= "no" then
            pcall(function()
                if queue_on_teleport then
                    queue_on_teleport("repeat task.wait() until game:GetService('Players').LocalPlayer and game:GetService('Players').LocalPlayer.Character loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/Admin'))()")
                end
            end)
        end
        pcall(function()
            if #Players:GetPlayers() <= 1 then TeleportService:Teleport(game.PlaceId, lp)
            else TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp) end
        end)

    elseif lowerMsg == ".antivoid" or lowerMsg == ".av" then
        if _G.UniqueInfiniteVoidActive then
            _G.UniqueInfiniteVoidActive = false
            workspace.FallenPartsDestroyHeight = -100
        end
        loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/antivoid'))()
    elseif lowerMsg == ".avinf" then
        if _G.AntiVoidT then
            _G.AntiVoidT = false
            local existingPlatform = workspace:FindFirstChild("AntiVoidPlatform")
            if existingPlatform then
                existingPlatform:Destroy()
            end
            workspace.FallenPartsDestroyHeight = -100
        end
        loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/antivoidinf'))()

    elseif lowerMsg == ".unantivoid" or lowerMsg == ".unav" then
        if _G.AntiVoidT ~= true then
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "[ AntiVoid ]",
                Text = "이미 꺼져있습니다.",
                Duration = 2
            })
            return
        end
        _G.AntiVoidT = false

        local existingFolder = workspace:FindFirstChild("AntiVoidPlatforms")
        if existingFolder then
            existingFolder:Destroy()
        end

        workspace.FallenPartsDestroyHeight = -110

        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "[ AntiVoid ]",
            Text = "Anti Void가 꺼졌습니다.",
            Duration = 2
        })

    elseif lowerMsg == ".avt" or lowerMsg == ".Antivt" then
        loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/antivehicletoys'))()
    elseif lowerMsg == ".unavt" or lowerMsg == ".unantivt" then
        if getgenv().AntiVehicleToyEnabled then
            getgenv().AntiVehicleToyEnabled = false
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "[ Anti-Vehicle Toy ]";
                Text = "Disabled (꺼짐)";
                Duration = 3;
            })
        else
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "[ 안내 ]";
                Text = "Anti-Vehicle-Toy (이미 꺼져있음)";
                Duration = 3;
            })
        end

    elseif lowerMsg == ".srv" or lowerMsg == ".srv9" then
        script_key="EyzbQBQoLtYghakFRYkYEMmFFiOohtSL";
        loadstring(game:HttpGet("https://srv9.xyz/scripts/loader"))()

    elseif lowerMsg == ".lax" or lowerMsg == ".laxhub" then
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Ddjsbcnuu/RunssianCaracal/refs/heads/main/Caracal"))()

    elseif lowerMsg == ".chams" then
        if _G.ChamsToggle == nil then
            _G.ChamsToggle = false
        end

        _G.ChamsToggle = not _G.ChamsToggle
        _G.ChamsRun = (_G.ChamsRun or 0) + 1
        local runId = _G.ChamsRun

        local Players = game:GetService("Players")
        local Workspace = game:GetService("Workspace")
        local LocalPlayer = Players.LocalPlayer

        local SCAN_STEP = 30
        local SCAN_DELAY = 0.05
        local HIGHLIGHT_COST = 10

        if not _G.ChamsConnections then
            _G.ChamsConnections = {}
        end

        local function clearChams()
            for _, connection in pairs(_G.ChamsConnections) do
                connection:Disconnect()
            end
            _G.ChamsConnections = {}

            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("Highlight") and obj.Name == "ChamsESP_Highlight" then
                    obj:Destroy()
                end
            end
        end

        local function applyChams(character)
            if not _G.ChamsToggle then return false end
            if not character then return false end

            if not character:FindFirstChild("ChamsESP_Highlight") then
                local highlight = getgenv().__DSN("Highlight")
                highlight.Name = "ChamsESP_Highlight"
                highlight.FillColor = Color3.fromRGB(255, 0, 0)
                highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                highlight.FillTransparency = 0.5
                highlight.OutlineTransparency = 0
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.Parent = character
                return true
            end
            return false
        end

        local function isNPC(model)
            if not model or not model:IsA("Model") then return false end
            if Players:GetPlayerFromCharacter(model) then return false end

            local humanoid = model:FindFirstChildOfClass("Humanoid")
            local bodyPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")

            return humanoid ~= nil and bodyPart ~= nil
        end

        local function handlePlayer(player)
            if player == LocalPlayer then return end

            if player.Character then
                applyChams(player.Character)
            end

            local conn = getgenv().__DST(player.CharacterAdded:Connect(function(char)
                task.wait(0.5)
                applyChams(char)
            end))
            table.insert(_G.ChamsConnections, conn)
        end

        local function handleNPC(model)
            if isNPC(model) then
                return applyChams(model)
            end
            return false
        end

        if _G.ChamsToggle then
            for _, player in pairs(Players:GetPlayers()) do
                handlePlayer(player)
            end

            local joinConn = getgenv().__DST(Players.PlayerAdded:Connect(handlePlayer))
            table.insert(_G.ChamsConnections, joinConn)

            local descConn = getgenv().__DST(Workspace.DescendantAdded:Connect(function(obj)
                if obj:IsA("Humanoid") then
                    local model = obj.Parent
                    getgenv().__DSTH(task.delay(0.5, function()
                        if _G.ChamsToggle and _G.ChamsRun == runId then
                            handleNPC(model)
                        end
                    end))
                end
            end))
            table.insert(_G.ChamsConnections, descConn)

            getgenv().__DSTH(task.spawn(function()
                local stack = {Workspace}
                local top = 1
                local cost = 0
                while top > 0 do
                    if not _G.ChamsToggle or _G.ChamsRun ~= runId then return end
                    local obj = stack[top]
                    stack[top] = nil
                    top = top - 1
                    if obj.Parent then
                        if obj:IsA("Humanoid") then
                            if handleNPC(obj.Parent) then
                                cost = cost + HIGHLIGHT_COST
                            end
                        end
                        for _, child in ipairs(obj:GetChildren()) do
                            top = top + 1
                            stack[top] = child
                        end
                    end
                    cost = cost + 1
                    if cost >= SCAN_STEP then
                        cost = 0
                        task.wait(SCAN_DELAY)
                    end
                end
            end))

            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "DShub",
                    Text = "Chams ESP: ON",
                    Duration = 3
                })
            end)
        else
            clearChams()
            pcall(function()
                game:GetService("StarterGui"):SetCore("SendNotification", {
                    Title = "DShub",
                    Text = "Chams ESP: OFF",
                    Duration = 3
                })
            end)
        end
    elseif lowerMsg == ".unchams" then
        local Players = game:GetService("Players")
        local Workspace = game:GetService("Workspace")

        _G.ChamsToggle = false

        if _G.ChamsConnections then
            for _, connection in pairs(_G.ChamsConnections) do
                connection:Disconnect()
            end
            _G.ChamsConnections = {}
        end

        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Highlight") and obj.Name == "ChamsESP_Highlight" then
                obj:Destroy()
            end
        end

    elseif lowerMsg == ".getplot" or lowerMsg == ".gp" then
        getgenv().__DSTH(task.spawn(function()
            pcall(function() loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/getplot'))() end)
        end))
    elseif lowerMsg == ".hg" or lowerMsg == ".housegrab" then
        getgenv().__DSTH(task.spawn(function()
            pcall(function() loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/housegrab'))() end)
        end))
    elseif lowerMsg == ".unhg" or lowerMsg == ".unhousegrab" then
        local StarterGui = game:GetService("StarterGui")

        if getgenv().HouseGrabConnection then
            getgenv().HouseGrabConnection:Disconnect()
            getgenv().HouseGrabConnection = nil

            StarterGui:SetCore("SendNotification", {
                Title = "[ House Grab ]",
                Text = "스크립트가 꺼졌습니다. (OFF)",
                Duration = 3
            })
        else
            StarterGui:SetCore("SendNotification", {
                Title = "[ House Grab ]",
                Text = "실행 중인 House Grab이 없습니다.",
                Duration = 3
            })
        end

    elseif lowerMsg == ".kg" or lowerMsg == ".kickgrab" then
        if getgenv().KickGrabActive then
            StarterGui:SetCore("SendNotification", {Title = "[ Kick Grab ]", Text = "이미 켜져있습니다!", Duration = 3})
        else
            loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/kickgrab'))()
        end

    elseif lowerMsg == ".unkg" or lowerMsg == ".unkickgrab" then
        if not getgenv().KickGrabActive then
            game.StarterGui:SetCore("SendNotification", {
                Title = "[ Kick Grab ]",
                Text = "이미 꺼져있습니다!",
                Duration = 3
            })
            return
        end

        getgenv().KickGrabActive = false
        getgenv().FKeyAttackActive = false

        if getgenv().FKeyInputConnection then
            getgenv().FKeyInputConnection:Disconnect()
            getgenv().FKeyInputConnection = nil
        end

        game.StarterGui:SetCore("SendNotification", {
            Title = "[ Kick Grab ]",
            Text = "Kick Grab이 종료되었습니다.",
            Duration = 3
        })

    elseif lowerMsg == ".vg" or lowerMsg == ".voidgrab" then
        loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/voidgrab'))()
    elseif lowerMsg == ".unvg" or lowerMsg == ".unvoidgrab" then
        if not getgenv().LoopGrabActive then
            game.StarterGui:SetCore("SendNotification", {
                Title = "[ Void Grab ]",
                Text = "이미 꺼져있습니다!",
                Duration = 3
            })
            return
        end

        getgenv().LoopGrabActive = false
        game.StarterGui:SetCore("SendNotification", {
            Title = "[ Void Grab ]",
            Text = "bozi Grab이 꺼졌습니다.",
            Duration = 3
        })

    elseif lowerMsg == ".svhop" then
        StarterGui:SetCore("SendNotification", {Title = "[ 서버 이동 ]", Text = "다른 서버를 찾는 중...", Duration = 3})
        if not http_request then
            StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "HTTP 미지원", Duration = 3})
        else
        getgenv().__DSTH(task.spawn(function()
            local servers, cursor = {}, ""
            for _page = 1, 5 do
                local urlWithCursor = string.format(
                    "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100%s",
                    game.PlaceId,
                    cursor ~= "" and ("&cursor=" .. cursor) or ""
                )
                local ok, result = pcall(function()
                    local req = http_request({Url = urlWithCursor, Method = "GET"})
                    return HttpService:JSONDecode(req.Body)
                end)
                if not ok or not result or not result.data then break end
                for _, v in ipairs(result.data) do
                    if type(v) == "table"
                        and v.id ~= game.JobId
                        and type(v.playing) == "number" and v.playing > 0
                        and type(v.maxPlayers) == "number" and v.maxPlayers > v.playing
                    then
                        table.insert(servers, v.id)
                    end
                end
                if #servers > 0 then break end
                local nextCursor = result.nextPageCursor
                if not nextCursor or nextCursor == nil or nextCursor == "null" then break end
                cursor = tostring(nextCursor)
            end

            if #servers == 0 then
                StarterGui:SetCore("SendNotification", {Title = "[ 실패 ]", Text = "이동할 서버를 찾지 못했습니다.", Duration = 3})
                return
            end

            local function tryTeleport(jobId)
                local ok1 = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, lp)
                end)
                if ok1 then return true end
                local ok2 = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, {lp})
                end)
                if ok2 then return true end
                local ok3 = pcall(function()
                    local opts = getgenv().__DSN("TeleportOptions")
                    opts.ServerInstanceId = jobId
                    TeleportService:TeleportAsync(game.PlaceId, {lp}, opts)
                end)
                if ok3 then return true end
                return false
            end

            local triedIds, maxRetry, succeeded = {}, math.min(10, #servers), false

            for attempt = 1, maxRetry do
                local candidates = {}
                for _, id in ipairs(servers) do
                    if not triedIds[id] then
                        table.insert(candidates, id)
                    end
                end
                if #candidates == 0 then break end

                local picked = candidates[math.random(1, #candidates)]
                triedIds[picked] = true

                if attempt == 1 then
                    StarterGui:SetCore("SendNotification", {Title = "[ 이동 시작 ]", Text = "서버로 이동합니다...", Duration = 3})
                else
                    StarterGui:SetCore("SendNotification", {Title = "[ 서버 재시도 " .. attempt .. "/" .. maxRetry .. " ]", Text = "다른 서버로 재시도 중...", Duration = 3})
                end

                task.wait(0.3)

                local initFailedConn, isFull = nil, false
                initFailedConn = getgenv().__DST(TeleportService.TeleportInitFailed:Connect(function(player, result, errorMsg)
                    if player == lp then
                        isFull = true
                        initFailedConn:Disconnect()
                    end
                end))

                local tpOk = tryTeleport(picked)

                if not tpOk then
                    pcall(function() initFailedConn:Disconnect() end)
                    local ok4 = pcall(function() teleport(game.PlaceId) end)
                    if not ok4 then
                        StarterGui:SetCore("SendNotification", {Title = "[ 텔레포트 차단 ]", Text = "이 익스플로잇에서 텔레포트가 차단됐습니다.", Duration = 4})
                    end
                    return
                end

                local waited = 0
                while waited < 6 and not isFull do
                    task.wait(0.2)
                    waited = waited + 0.2
                end
                pcall(function() initFailedConn:Disconnect() end)

                if not isFull then
                    succeeded = true
                    break
                else
                    StarterGui:SetCore("SendNotification", {Title = "[ 서버 꽉 참 ]", Text = "서버가 꽉 찼습니다. 다른 서버를 찾는 중...", Duration = 2})
                    task.wait(0.3)
                end
            end

            if not succeeded then
                StarterGui:SetCore("SendNotification", {Title = "[ 실패 ]", Text = "모든 서버가 꽉 찼거나 이동에 실패했습니다.", Duration = 4})
            end
        end))
        end

    elseif lowerMsg == ".에임봇" or lowerMsg == ".aimbot" then
        getgenv().__DSTH(task.spawn(function() pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/dosi1100-cmyk/script/refs/heads/main/aimbot"))() end) end))

    elseif lowerMsg == ".getblob" or lowerMsg == ".gb" then
        if _G.AutoSitConnection then
            _G.AutoSitConnection:Disconnect()
            _G.AutoSitConnection = nil
        end

        -- .ltp/.vtp 루프 텔레포트가 켜져 있으면 블롭맨 착석 로직과 매 프레임 위치가 충돌해 좌석에 앉지 못하므로,
        -- 착석에 성공할 때까지 잠시 정지시켜 둔다 (켜짐 상태 자체는 유지, 착석 성공 시 자동으로 재개됨).
        if M.voidTpHBC then
            M.voidTpHBC:Disconnect()
            M.voidTpHBC = nil
        end
        if M.loopTpHBC then
            M.loopTpHBC:Disconnect()
            M.loopTpHBC = nil
        end

        local Players, rs, RunService, Camera =
            game:GetService("Players"),
            game:GetService("ReplicatedStorage"),
            game:GetService("RunService"),
            workspace.CurrentCamera
        local plr, selectedVehicles, hasSpawned, isStealing = Players.LocalPlayer, {"CreatureBlobman"}, false, false

        local function BlobTP(target)
            local TCHAR = target.Character
            local THRP, localChar = TCHAR and TCHAR:FindFirstChild("Torso"), plr.Character
            local localHRP = localChar and localChar:FindFirstChild("HumanoidRootPart")

            if TCHAR and THRP and localHRP then
                local dist, ping = (THRP.Position - localHRP.Position).Magnitude, plr:GetNetworkPing()
                local offset = THRP.Position + (THRP.Velocity * (ping + 0.15))

                if dist > 30 then 
                    localHRP.CFrame = CFrame.new(offset) * THRP.CFrame.Rotation * CFrame.new(0,-13,0) 
                    localHRP.AssemblyLinearVelocity = Vector3.zero
                    localHRP.AssemblyAngularVelocity = Vector3.zero
                end
                return true
            end
            return false
        end

        function SetOwner(target)
            local head, myHrp =
                target.Character and target.Character:FindFirstChild("HumanoidRootPart"),
                plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if head and myHrp then
                rs.GrabEvents.SetNetworkOwner:FireServer(head, head.CFrame + head.AssemblyLinearVelocity * (plr:GetNetworkPing() + 0.15))
                return true
            end
            return false
        end

        function FindMyVehicles(inventory)
            local vehicles = {}
            if not inventory then return vehicles end

            for _, item in pairs(inventory:GetChildren()) do
                for _, vehicleName in pairs(selectedVehicles) do
                    if item.Name == vehicleName then
                        local seat = item:FindFirstChild("VehicleSeat")
                        if seat then
                            table.insert(vehicles, {
                                seat = seat,
                                vehicleItem = item,
                                occupant = seat.Occupant
                            })
                        end
                    end
                end
            end
            return vehicles
        end

        _G.AutoSitConnection = getgenv().__DST(RunService.Heartbeat:Connect(function()
            local char = plr.Character
            if not char or not char:FindFirstChild("Humanoid") or not char:FindFirstChild("HumanoidRootPart") then return end
            
            local hum, root = char.Humanoid, char.HumanoidRootPart

            if hum.SeatPart ~= nil and hum.Sit == true then
                if hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" then
                    if _G.AutoSitConnection then
                        _G.AutoSitConnection:Disconnect()
                        _G.AutoSitConnection = nil
                    end

                    -- 착석에 성공했으므로 getblob 시작 시 잠시 정지시켰던 루프 텔레포트를 재개
                    if M.voidTpEnabled and not M.voidTpHBC then
                        M.voidTpHBC = getgenv().__DST(RunService.Heartbeat:Connect(function()
                            if not M.voidTpEnabled or not AntiGrabTP_ActiveV1 then return end
                            if _killInProgress then return end
                            local c = lp.Character
                            local hrpNow = c and c:FindFirstChild("HumanoidRootPart")
                            if not hrpNow then return end
                            local randomX, randomZ = math.random(-9999999, 9999999), math.random(-9999999, 9999999)
                            hrpNow.CFrame = CFrame.new(randomX, 9999999, randomZ)
                        end))
                    end
                    if M.loopTpEnabled and not M.loopTpHBC then
                        M.loopTpHBC = getgenv().__DST(RunService.Heartbeat:Connect(function()
                            if not M.loopTpEnabled or not AntiGrabTP_ActiveV2 then return end
                            if _killInProgress then return end
                            local c = lp.Character
                            local hrpNow = c and c:FindFirstChild("HumanoidRootPart")
                            if not hrpNow then return end
                            local randomX, randomY, randomZ = math.random(-1500, 1500), math.random(0, 1500), math.random(-1500, 1500)
                            hrpNow.CFrame = CFrame.new(randomX, randomY, randomZ)
                        end))
                    end
                end
                return
            end

            if isStealing then return end

            local myInv = workspace:FindFirstChild(plr.Name.."SpawnedInToys")
            local myVehicles, targetVehicle = FindMyVehicles(myInv), nil

            for _, v in ipairs(myVehicles) do
                if v.occupant == nil then
                    targetVehicle = v
                    break
                end
            end

            if not targetVehicle then
                for _, v in ipairs(myVehicles) do
                    if v.occupant ~= nil and v.occupant ~= hum then
                        local targetPlr = Players:GetPlayerFromCharacter(v.occupant.Parent)
                        if targetPlr then
                            isStealing = true
                            getgenv().__DSTH(task.spawn(function()
                                BlobTP(targetPlr)
                                task.wait(0.3)
                                SetOwner(targetPlr)
                                task.wait(0.05)
                                v.seat:Sit(hum)
                                isStealing = false
                            end))
                            return
                        end
                    end
                end
            end

            if not targetVehicle and #myVehicles == 0 then
                if not hasSpawned then
                    hasSpawned = true
                    local spawnCFrame = root.CFrame * CFrame.new(0, 0, 20)
                    rs:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction"):InvokeServer(
                        selectedVehicles[1],
                        spawnCFrame,
                        Vector3.new(0, 0, 0)
                    )
                end
                return
            end

            if targetVehicle then
                local seat = targetVehicle.seat
                local dist = (root.Position - seat.Position).Magnitude
                
                if dist > 20 then
                    root.CFrame = CFrame.new(seat.Position + Vector3.new(0, 3, 0))
                else
                    local prompt = seat:FindFirstChild("ProximityPrompt")
                    if prompt then
                        rs.CharacterEvents.Struggle:FireServer()
                        fireproximityprompt(prompt)
                    else
                        seat:Sit(hum)
                    end
                end
            end
        end))

    elseif lowerMsg == ".target" then
        stopTarget()
        StarterGui:SetCore("SendNotification", {Title = "[ Target ]", Text = "타겟이 해제되었습니다.", Duration = 2})

    elseif lowerMsg == ".untarget" then
        stopTarget()
        StarterGui:SetCore("SendNotification", {Title = "[ Target ]", Text = "타겟이 해제되었습니다.", Duration = 2})

    elseif lowerMsg:match("^%.target%s+(.+)$") then
        local keyword = msg:match("^%.target%s+(.+)$") or msg:match("^%.Target%s+(.+)$") or lowerMsg:match("^%.target%s+(.+)$")
        setTarget(keyword)

    elseif lowerMsg == ".jerk" then
        toggleJerk(true)

    elseif lowerMsg == ".unjerk" then
        toggleJerk(false)

    elseif lowerMsg:match("^%.enable%s+%S") then
        local input = lowerMsg:match("^%.enable%s+(%S+)")
        if input == "reset" then
            StarterGui:SetCore("ResetButtonCallback", true); getgenv().__DSR.resetOff = false
            StarterGui:SetCore("SendNotification", {Title = "[ Enable ]", Text = "reset이 활성화되었습니다.", Duration = 2})
        else
            local coreGuiType = coreGuiTypeNames[input]
            if coreGuiType then
                StarterGui:SetCoreGuiEnabled(coreGuiType, true)
                StarterGui:SetCore("SendNotification", {Title = "[ Enable ]", Text = input .. "이(가) 활성화되었습니다.", Duration = 2})
            else
                StarterGui:SetCore("SendNotification", {Title = "[ Enable ]", Text = "알 수 없는 항목입니다: " .. input, Duration = 2})
            end
        end

    elseif lowerMsg:match("^%.disable%s+%S") then
        local input = lowerMsg:match("^%.disable%s+(%S+)")
        if input == "reset" then
            StarterGui:SetCore("ResetButtonCallback", false); getgenv().__DSR.resetOff = true
            StarterGui:SetCore("SendNotification", {Title = "[ Disable ]", Text = "reset이 비활성화되었습니다.", Duration = 2})
        else
            local coreGuiType = coreGuiTypeNames[input]
            if coreGuiType then
                StarterGui:SetCoreGuiEnabled(coreGuiType, false)
                StarterGui:SetCore("SendNotification", {Title = "[ Disable ]", Text = input .. "이(가) 비활성화되었습니다.", Duration = 2})
            else
                StarterGui:SetCore("SendNotification", {Title = "[ Disable ]", Text = "알 수 없는 항목입니다: " .. input, Duration = 2})
            end
        end

    elseif lowerMsg == ".position" or lowerMsg == ".pos" then
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local pos = hrp.Position
            local posText = string.format("%.2f, %.2f, %.2f", pos.X, pos.Y, pos.Z)
            pcall(function() setclipboard(posText) end)
            StarterGui:SetCore("SendNotification", {
                Title = "[ Position ]",
                Text = "현재 위치 복사됨 : " .. posText,
                Duration = 4
            })
        else
            StarterGui:SetCore("SendNotification", {
                Title = "[ Position ]",
                Text = "캐릭터를 찾을 수 없습니다.",
                Duration = 3
            })
        end

    elseif lowerMsg:match("^%.copy%s+(.+)$") then
        local keyword, found = lowerMsg:match("^%.copy%s+(.+)$"):lower(), nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name:lower():find(keyword, 1, true) or p.DisplayName:lower():find(keyword, 1, true) then
                found = p
                break
            end
        end
        if found then
            local copyText = found.Name .. " | " .. tostring(found.UserId)
            pcall(function() setclipboard(copyText) end)
            StarterGui:SetCore("SendNotification", {
                Title = "[ 복사됨 ]",
                Text = found.DisplayName .. " (@" .. found.Name .. ") | ID: " .. tostring(found.UserId),
                Duration = 4
            })
        else
            StarterGui:SetCore("SendNotification", {
                Title = "[ .copy 실패 ]",
                Text = "'" .. keyword .. "' 와 매칭되는 플레이어를 찾지 못했습니다.",
                Duration = 3
            })
        end

    elseif lowerMsg == ".lag" then
        if getgenv()._lagLoopEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ Lag ]", Text = "이미 켜져 있습니다.", Duration = 2})
        else
            getgenv()._lagLoopEnabled = true

            local args = {
                workspace:WaitForChild("SpawnLocation"),
                CFrame.new(-2200000000, 0, -2200000000, 1, 0, 0, 0, 1, 0, 0, 0, 1)
            }

            getgenv()._lagLoopThread = getgenv().__DSTH(task.spawn(function()
                while getgenv()._lagLoopEnabled do
                    pcall(function()
                        game:GetService("ReplicatedStorage"):WaitForChild("GrabEvents"):WaitForChild("CreateGrabLine"):FireServer(table.unpack(args))
                    end)
                    task.wait(1 / 60)
                end
            end))

            StarterGui:SetCore("SendNotification", {
                Title = "[ Lag 루프 켜짐 ]",
                Text = ".lag CreateGrabLine 루프 실행 중",
                Duration = 3
            })
        end

    elseif lowerMsg == ".unlag" then
        if getgenv()._lagLoopEnabled then
            getgenv()._lagLoopEnabled = false
            if getgenv()._lagLoopThread then
                task.cancel(getgenv()._lagLoopThread)
                getgenv()._lagLoopThread = nil
            end

            local destroyArgs = { workspace:WaitForChild("SpawnLocation") }
            for i = 1, 5 do
                game:GetService("ReplicatedStorage"):WaitForChild("GrabEvents"):WaitForChild("DestroyGrabLine"):FireServer(table.unpack(destroyArgs))
            end

            StarterGui:SetCore("SendNotification", {Title = "[ Lag 루프 꺼짐 ]", Text = "이벤트 호출이 중지되었습니다.", Duration = 3})
        else
            StarterGui:SetCore("SendNotification", {Title = "[ Lag ]", Text = "이미 꺼져 있습니다.", Duration = 2})
        end

    elseif lowerMsg == ".packet" or lowerMsg == ".packetlag" then
        loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/mousepointer'))()

    elseif lowerMsg == ".unpacket" or lowerMsg == ".unpacketlag" then
        local StarterGui = game:GetService("StarterGui")

        if not getgenv().PacketLag then
            StarterGui:SetCore("SendNotification", {
                Title = "[ 알림 ]",
                Text = "이미 꺼져있음",
                Duration = 3,
            })
            return
        end

        getgenv().PacketLag = false

        StarterGui:SetCore("SendNotification", {
            Title = "[ 패킷렉 꺼짐",
            Text = "꺼짐",
            Duration = 3,
        })

    elseif lowerMsg:match("^%.%d+%.?%d*%$$") or lowerMsg:match("^%.[1-9]%d*%$$") or lowerMsg == ".1$" then
        local amountStr = msg:match("^%.(.-)%$$")
        local amount = tonumber(amountStr)
        if amount then
            local apiUrl = "https://query1.finance.yahoo.com/v8/finance/chart/KRW=X"
            local success, response = pcall(function()
                return game:HttpGet(apiUrl)
            end)
            if success and response then
                local ok, decodedData = pcall(function() return game:GetService("HttpService"):JSONDecode(response) end)
                if ok and decodedData and decodedData.chart and decodedData.chart.result and decodedData.chart.result[1] then
                    local meta = decodedData.chart.result[1].meta
                    if meta and meta.regularMarketPrice then
                        local krwRate = meta.regularMarketPrice
                        local total = math.floor(krwRate * amount)
                        local totalStr, formatted = tostring(total), ""
                        local len = #totalStr
                        for i = 1, len do
                            formatted = formatted .. totalStr:sub(i, i)
                            local remaining = len - i
                            if remaining > 0 and remaining % 3 == 0 then
                                formatted = formatted .. ","
                            end
                        end
                        StarterGui:SetCore("SendNotification", {
                            Title = "[ 환율 계산 결과 ]",
                            Text = amount .. "$ = " .. formatted .. "원",
                            Duration = 8
                        })
                    else
                        StarterGui:SetCore("SendNotification", {Title = "[ 환율 오류 ]", Text = "환율 정보를 가져올 수 없습니다.", Duration = 4})
                    end
                else
                    StarterGui:SetCore("SendNotification", {Title = "[ 환율 오류 ]", Text = "데이터 파싱 실패.", Duration = 4})
                end
            else
                StarterGui:SetCore("SendNotification", {Title = "[ 요청 실패 ]", Text = "API 요청 실패. HttpGet 지원 여부를 확인하세요.", Duration = 4})
            end
        end

    elseif lowerMsg == ".도움" or lowerMsg == ".help" then
        if helpFrame then helpFrame.Visible = not helpFrame.Visible end

    elseif lowerMsg == ".reset" or lowerMsg == ".die" then
        local Players = game:GetService("Players")
        local speaker = Players.LocalPlayer

        if speaker.Character then
            local humanoid = speaker.Character:FindFirstChildWhichIsA("Humanoid")

            if type(replicatesignal) == "function" then
                pcall(function() replicatesignal(speaker.Kill) end)
            elseif humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Dead)
            else
                speaker.Character:BreakJoints()
            end
        end

    elseif lowerMsg:sub(1, 7) == ".speed " then
        local val = tonumber(msg:sub(8))
        if val and lp.Character and lp.Character:FindFirstChild("Humanoid") then
            lp.Character.Humanoid.WalkSpeed = val
            StarterGui:SetCore("SendNotification", {Title = "[ 속도 설정 ]", Text = "WalkSpeed: " .. val, Duration = 2})
        end

    elseif lowerMsg:sub(1, 5) == ".hip " then
        local val = tonumber(msg:sub(6))
        if val and lp.Character and lp.Character:FindFirstChild("Humanoid") then
            lp.Character.Humanoid.HipHeight = val
            StarterGui:SetCore("SendNotification", {Title = "[ 힙 높이 설정 ]", Text = "HipHeight: " .. val, Duration = 2})
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 사용법 ]", Text = ".hip <숫자> (예: .hip 3)", Duration = 3})
        end

    elseif lowerMsg:sub(1, 5) == ".fov " then
        local val = tonumber(msg:sub(6))
        if val then
            M.fovLockValue = val
            local function applyFov()
                local cam = workspace.CurrentCamera
                if cam and M.fovLockValue and cam.FieldOfView ~= M.fovLockValue then
                    cam.FieldOfView = M.fovLockValue
                end
            end
            local function bindFovCamera()
                if M.fovLockConnection then M.fovLockConnection:Disconnect(); M.fovLockConnection = nil end
                local cam = workspace.CurrentCamera
                if cam then
                    M.fovLockConnection = getgenv().__DST(cam:GetPropertyChangedSignal("FieldOfView"):Connect(applyFov))
                end
                applyFov()
            end
            if not M.fovLockCameraConnection then
                M.fovLockCameraConnection = getgenv().__DST(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindFovCamera))
            end
            bindFovCamera()
            StarterGui:SetCore("SendNotification", {Title = "[ FOV 변경 ]", Text = "시야각이 " .. val .. "(으)로 고정되었습니다.", Duration = 2})
        end

    elseif lowerMsg:sub(1, 11) == ".loopspeed " or lowerMsg:sub(1, 9) == ".lpspeed " then
        local val
        if lowerMsg:sub(1, 11) == ".loopspeed " then val = tonumber(msg:sub(12)) else val = tonumber(msg:sub(10)) end
        if val then
            M.targetWalkSpeed = val
            if not M.loopSpeedConnection then
                M.loopSpeedConnection = getgenv().__DST(RunService.Heartbeat:Connect(function()
                    if lp.Character and lp.Character:FindFirstChild("Humanoid") then
                        lp.Character.Humanoid.WalkSpeed = M.targetWalkSpeed
                    end
                end))
            end
            StarterGui:SetCore("SendNotification", {Title = "[ 속도 고정됨 ]", Text = "항상 " .. val .. "로 유지됩니다.", Duration = 2})
        end

    elseif lowerMsg == ".unloopspeed" or lowerMsg == ".unlpspeed" then
        if M.loopSpeedConnection then
            M.loopSpeedConnection:Disconnect()
            M.loopSpeedConnection = nil
            StarterGui:SetCore("SendNotification", {Title = "[ 속도 고정 해제 ]", Text = "이제 속도가 고정되지 않습니다.", Duration = 2})
        else StarterGui:SetCore("SendNotification", {Title = "[ 알림 ]", Text = "속도 고정이 켜져있지 않습니다.", Duration = 2}) end

    elseif lowerMsg:sub(1, 11) == ".jumppower " or lowerMsg:sub(1, 5) == ".jpp " then
        local val
        if lowerMsg:sub(1, 11) == ".jumppower " then val = tonumber(msg:sub(12)) else val = tonumber(msg:sub(6)) end
        if val and lp.Character and lp.Character:FindFirstChild("Humanoid") then
            lp.Character.Humanoid.UseJumpPower = true
            lp.Character.Humanoid.JumpPower = val
            StarterGui:SetCore("SendNotification", {Title = "[ 점프력 설정 ]", Text = "JumpPower: " .. val, Duration = 2})
        end

    elseif lowerMsg:sub(1, 15) == ".loopjumppower " or lowerMsg:sub(1, 9) == ".loopjpp " or lowerMsg:sub(1, 7) == ".lpjpp " then
        local val
        if lowerMsg:sub(1, 15) == ".loopjumppower " then val = tonumber(msg:sub(16)) elseif lowerMsg:sub(1, 9) == ".loopjpp " then val = tonumber(msg:sub(10)) else val = tonumber(msg:sub(8)) end
        if val then
            M.targetJumpPower = val
            if not M.loopJumpConnection then
                M.loopJumpConnection = getgenv().__DST(RunService.Heartbeat:Connect(function()
                    if lp.Character and lp.Character:FindFirstChild("Humanoid") then
                        lp.Character.Humanoid.UseJumpPower = true
                        lp.Character.Humanoid.JumpPower = M.targetJumpPower
                    end
                end))
            end
            StarterGui:SetCore("SendNotification", {Title = "[ 점프력 고정됨 ]", Text = "항상 " .. val .. "로 유지됩니다.", Duration = 2})
        end

    elseif lowerMsg == ".unloopjumppower" or lowerMsg == ".unloopjpp" or lowerMsg == ".unlpjpp" then
        if M.loopJumpConnection then
            M.loopJumpConnection:Disconnect()
            M.loopJumpConnection = nil
            StarterGui:SetCore("SendNotification", {Title = "[ 점프력 고정 해제 ]", Text = "이제 점프력이 고정되지 않습니다.", Duration = 2})
        else StarterGui:SetCore("SendNotification", {Title = "[ 알림 ]", Text = "점프력 고정이 켜져있지 않습니다.", Duration = 2}) end

    elseif lowerMsg == ".unjpp" then
        if lp.Character and lp.Character:FindFirstChild("Humanoid") then lp.Character.Humanoid.JumpPower = 50 end
        StarterGui:SetCore("SendNotification", {Title = "[ 점프력 초기화 ]", Text = "점프력이 50으로 초기화되었습니다.", Duration = 2})

    elseif lowerMsg:sub(1,8) == ".tpwalk " then
        local num = tonumber(msg:sub(9))
        if num and num > 0 then
            startTpwalk(num)
        else StarterGui:SetCore("SendNotification", {Title = "[ 사용법 ]", Text = ".tpwalk <숫자>", Duration = 4}) end

    elseif lowerMsg:sub(1,4) == ".tw " then
        local num = tonumber(msg:sub(5))
        if num and num > 0 then
            startTpwalk(num)
        else StarterGui:SetCore("SendNotification", {Title = "[ 사용법 ]", Text = ".tw <숫자>", Duration = 4}) end

    elseif lowerMsg == ".untpwalk" or lowerMsg == ".untw" then
        if not M.tpwalkEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ TpWalk ]", Text = "이미 꺼져 있습니다.", Duration = 2})
        else
            stopTpwalk()
        end

    elseif lowerMsg:sub(1,4) == ".tp " then
        local x, y, z = msg:match("^%.tp%s+(%-?[%d%.]+)%s*,%s*(%-?[%d%.]+)%s*,%s*(%-?[%d%.]+)")
        if not (x and y and z) then
            x, y, z = msg:match("^%.tp%s+(%-?[%d%.]+)%s+(%-?[%d%.]+)%s+(%-?[%d%.]+)")
        end
        if x and y and z then
            local tx, ty, tz = tonumber(x), tonumber(y), tonumber(z)
            local char = lp.Character
            local hrp, hum =
                char and char:FindFirstChild("HumanoidRootPart"),
                char and char:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                hrp.Velocity = Vector3.zero
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.CFrame = CFrame.new(tx, ty, tz)
                hrp.Anchored = true
                task.wait(0.03)
                hrp.Anchored = false
                hrp.Velocity = Vector3.zero
                hrp.AssemblyLinearVelocity = Vector3.zero
                StarterGui:SetCore("SendNotification", {Title = "[ 텔레포트 ]", Text = string.format("X: %s, Y: %s, Z: %s 로 이동했습니다.", x, y, z), Duration = 3})
            else
                StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "캐릭터를 찾을 수 없습니다.", Duration = 3})
            end
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 사용법 ]", Text = ".tp X,Y,Z 또는 .tp X Y Z (예: .tp 0,100,0 / .tp 0 100 0)", Duration = 4})
        end

    elseif lowerMsg == ".hide" then
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(32.81, -7.35, -628.67)
            hrp.Anchored = true
            task.wait(0.03)
            hrp.Anchored = false
            hrp.Velocity = Vector3.zero
            hrp.AssemblyLinearVelocity = Vector3.zero
            StarterGui:SetCore("SendNotification", {Title = "[ 숨기기 ]", Text = "지정 위치로 이동했습니다.", Duration = 3})
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "캐릭터를 찾을 수 없습니다.", Duration = 3})
        end

    elseif lowerMsg == ".핑" then
        local ping = math.floor(lp:GetNetworkPing() * 1000)
        StarterGui:SetCore("SendNotification", {Title = "[ 핑 확인 ]", Text = "현재 핑: " .. ping .. "ms", Duration = 3})

    elseif lowerMsg == ".친구" or lowerMsg == ".친구 목록" or lowerMsg == ".fl" or lowerMsg == ".friendlist" then toggleFriendList()

    elseif lowerMsg == ".서버정보" or lowerMsg == ".svinfo" then
        if not serverInfoGui or not serverInfoGui.Parent then createServerInfoGui() else serverInfoGui.Enabled = not serverInfoGui.Enabled end
    else
        processCommandPart2(msg, lowerMsg)
    end
end

processCommandPart2 = function(msg, lowerMsg)
    if lowerMsg:sub(1, 6) == ".kill " then
        local targetNamePart, targetPlayers = lowerMsg:sub(7):match("^%s*(.-)%s*$"), {}
        if targetNamePart == "-all" then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp and not lp:IsFriendsWith(p.UserId) then table.insert(targetPlayers, p) end
            end
        else
            for namePart in targetNamePart:gmatch("[^,]+") do
                namePart = namePart:match("^%s*(.-)%s*$")
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= lp then
                        local pName, pDisplay = p.Name:lower(), p.DisplayName:lower()
                        if pName:sub(1, #namePart) == namePart or pDisplay:sub(1, #namePart) == namePart then
                            if not table.find(targetPlayers, p) then
                                table.insert(targetPlayers, p)
                            end
                            break
                        end
                    end
                end
            end
        end
        if #targetPlayers > 0 then
            local names = {}
            for _, p in ipairs(targetPlayers) do table.insert(names, p.Name) end
            local isAll = (targetNamePart == "-all")
            if isAll then
                StarterGui:SetCore("SendNotification", {Title = "[ Kill -all ]", Text = "모든 플레이어를 순차적으로 죽입니. (Plot 안 플레이어 제외)", Duration = 4})
                getgenv().__DSTH(task.spawn(function()
                    for _, targetPlayer in ipairs(targetPlayers) do
                        if targetPlayer and targetPlayer.Parent then
                            if isTargetInPlot(targetPlayer) then
                            else
                                executeKill(targetPlayer, false, 1)
                            end
                        end
                    end
                    StarterGui:SetCore("SendNotification", {Title = "[ Kill -all 완료 ]", Text = "모든 플레이어 처리가 완료되었습니다. (Plot 안 플레이어 제외)", Duration = 3})
                end))
            else
                local killedNames, inPlotNames = {}, {}
                for _, targetPlayer in ipairs(targetPlayers) do
                    if isTargetInPlot(targetPlayer) then
                        table.insert(inPlotNames, targetPlayer.Name)
                    else
                        table.insert(killedNames, targetPlayer.Name)
                        getgenv().__DSTH(task.spawn(function() executeKillWithCheck(targetPlayer) end))
                    end
                end
                if #inPlotNames > 0 then
                    StarterGui:SetCore("SendNotification", {
                        Title = "[ Kill 취소 ]",
                        Text = table.concat(inPlotNames, ", ") .. "님은 Plot 안에 있습니다.",
                        Duration = 4
                    })
                end
                if #killedNames > 0 then
                    StarterGui:SetCore("SendNotification", {Title = "[ Kill ]", Text = table.concat(killedNames, ", ") .. "님을 공격합니다.", Duration = 2})
                end
            end
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "플레이어를 찾을 수 없습니다.", Duration = 3})
        end

    elseif lowerMsg:sub(1, 9) == ".getbang " then
        local targetNamePart = lowerMsg:sub(10):match("^%s*(.-)%s*$")
        local targetPlayer
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then
                local pName, pDisplay = p.Name:lower(), p.DisplayName:lower()
                if pName:sub(1, #targetNamePart) == targetNamePart or pDisplay:sub(1, #targetNamePart) == targetNamePart then
                    targetPlayer = p
                    break
                end
            end
        end
        if targetPlayer then
            local ok = startGetBang(targetPlayer)
            if ok then
                StarterGui:SetCore("SendNotification", {Title = "[ Get Bang ]", Text = targetPlayer.Name .. "님에게 작동합니다.", Duration = 3})
            else
                StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "캐릭터를 찾을 수 없습니다.", Duration = 3})
            end
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "플레이어를 찾을 수 없습니다.", Duration = 3})
        end

    elseif lowerMsg == ".ungetbang" then
        stopGetBang()
        StarterGui:SetCore("SendNotification", {Title = "[ Get Bang 종료 ]", Text = "Get Bang을 중지했습니다.", Duration = 3})

    elseif lowerMsg:sub(1, 9) == ".getsuck " then
        local targetNamePart = lowerMsg:sub(10):match("^%s*(.-)%s*$")
        local targetPlayer
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then
                local pName, pDisplay = p.Name:lower(), p.DisplayName:lower()
                if pName:sub(1, #targetNamePart) == targetNamePart or pDisplay:sub(1, #targetNamePart) == targetNamePart then
                    targetPlayer = p
                    break
                end
            end
        end
        if targetPlayer then
            local ok = startGetSuck(targetPlayer)
            if ok then
                StarterGui:SetCore("SendNotification", {Title = "[ Get Suck ]", Text = targetPlayer.Name .. "님에게 작동합니다.", Duration = 3})
            else
                StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "캐릭터를 찾을 수 없습니다.", Duration = 3})
            end
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "플레이어를 찾을 수 없습니다.", Duration = 3})
        end

    elseif lowerMsg == ".ungetsuck" then
        stopGetSuck()
        StarterGui:SetCore("SendNotification", {Title = "[ Get Suck 종료 ]", Text = "Get Suck을 중지했습니다.", Duration = 3})

    elseif lowerMsg:sub(1, 10) == ".loopkill " or lowerMsg:sub(1, 8) == ".lpkill " then
        local targetNamePart, targetPlayers =
            (lowerMsg:sub(1, 10) == ".loopkill " and lowerMsg:sub(11) or lowerMsg:sub(9)):match("^%s*(.-)%s*$"),
            {}
        if targetNamePart == "-all" then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= lp and not lp:IsFriendsWith(p.UserId) then table.insert(targetPlayers, p) end
            end
        else
            for namePart in targetNamePart:gmatch("[^,]+") do
                namePart = namePart:match("^%s*(.-)%s*$")
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= lp then
                        local pName, pDisplay = p.Name:lower(), p.DisplayName:lower()
                        if pName:sub(1, #namePart) == namePart or pDisplay:sub(1, #namePart) == namePart then
                            if not table.find(targetPlayers, p) then
                                table.insert(targetPlayers, p)
                            end
                            break
                        end
                    end
                end
            end
        end
        if #targetPlayers > 0 then
            local names, inPlotNames, isAll = {}, {}, (targetNamePart == "-all")
            for _, targetPlayer in ipairs(targetPlayers) do
                table.insert(names, targetPlayer.Name)
                startLoopKill(targetPlayer)
                if isTargetInPlot(targetPlayer) then
                    table.insert(inPlotNames, targetPlayer.Name)
                end
            end
            for _, name in ipairs(inPlotNames) do
                StarterGui:SetCore("SendNotification", {
                    Title = "[ Plot 내부 감지 ]",
                    Text = name .. "님은 현재 Plot 안에 있습니다. 집 밖으로 나올 때까지 대기합니다.",
                    Duration = 5
                })
                task.wait(0.1)
            end
            local notifText = table.concat(names, ", ") .. "님을 계속해서 죽입니다."
            if isAll then
                notifText = "친구를 제외한 모든 플레이어를 계속해서 죽입니다."
                L.loopKillAllMode = true
                if L.loopKillAllWatcher then
                    task.cancel(L.loopKillAllWatcher)
                    L.loopKillAllWatcher = nil
                end
                L.loopKillAllWatcher = getgenv().__DSTH(task.spawn(function()
                    while L.loopKillAllMode and L.loopKillEnabled do
                        task.wait(0.1)
                        for _, p in ipairs(Players:GetPlayers()) do
                            if p ~= lp and not lp:IsFriendsWith(p.UserId) and not table.find(L.loopKillTargets, p) then
                                if not isTargetInPlot(p) then
                                    local char = p.Character
                                    if char and char.Parent == Workspace then
                                        startLoopKill(p)
                                        StarterGui:SetCore("SendNotification", {
                                            Title = "[ Loop Kill -all ]",
                                            Text = p.Name .. "님이 Plot 밖으로 나와 타겟에 추가됩니다.",
                                            Duration = 3
                                        })
                                    end
                                end
                            end
                        end
                    end
                end))
            end
            StarterGui:SetCore("SendNotification", {Title = "[ Loop Kill ]", Text = notifText, Duration = 3})
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "플레이어를 찾을 수 없습니다.", Duration = 3})
        end

    elseif lowerMsg == ".unloopkill" or lowerMsg == ".unlpkill" then
        stopLoopKill()
        StarterGui:SetCore("SendNotification", {Title = "[ Loop Kill 종료 ]", Text = "연속 킬을 중지했습니다.", Duration = 3})

    elseif lowerMsg:sub(1, 12) == ".unloopkill " or lowerMsg:sub(1, 10) == ".unlpkill " then
        local targetNamePart, removedNames, notFoundNames =
            (lowerMsg:sub(1, 12) == ".unloopkill " and lowerMsg:sub(13) or lowerMsg:sub(11)):match("^%s*(.-)%s*$"),
            {},
            {}
        for namePart in targetNamePart:gmatch("[^,]+") do
            namePart = namePart:match("^%s*(.-)%s*$")
            local found = false
            for _, p in ipairs(L.loopKillTargets) do
                local pName, pDisplay = p.Name:lower(), p.DisplayName:lower()
                if pName:sub(1, #namePart) == namePart or pDisplay:sub(1, #namePart) == namePart then
                    table.insert(removedNames, p.Name)
                    stopLoopKillTarget(p)
                    found = true
                    break
                end
            end
            if not found then
                table.insert(notFoundNames, namePart)
            end
        end
        if #removedNames > 0 then
            local remainNames = {}
            for _, p in ipairs(L.loopKillTargets) do table.insert(remainNames, p.Name) end
            local remainText = #remainNames > 0 and ("남은 타겟: " .. table.concat(remainNames, ", ")) or "더 이상 타겟이 없습니다."
            StarterGui:SetCore("SendNotification", {
                Title = "[ Loop Kill 타겟 제거 ]",
                Text = table.concat(removedNames, ", ") .. "님을 타겟에서 제외했습니다. " .. remainText,
                Duration = 4
            })
        else
            StarterGui:SetCore("SendNotification", {
                Title = "[ 오류 ]",
                Text = "타겟 목록에서 해당 플레이어를 찾을 수 없습니다.",
                Duration = 3
            })
        end

    elseif lowerMsg:sub(1, 7) == ".fling " then
        local targetNamePart = lowerMsg:sub(8):match("^%s*(.-)%s*$")
        local targetPlayer = nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then
                local pName, pDisplay = p.Name:lower(), p.DisplayName:lower()
                if pName:sub(1, #targetNamePart) == targetNamePart or pDisplay:sub(1, #targetNamePart) == targetNamePart then
                    targetPlayer = p
                    break
                end
            end
        end
        if targetPlayer then
            startFling(targetPlayer)
            StarterGui:SetCore("SendNotification", {Title = "[ Fling ]", Text = targetPlayer.Name .. "님을 주사위로 계속 공격합니다.", Duration = 3})
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "플레이어를 찾을 수 없습니다.", Duration = 3})
        end

    elseif lowerMsg == ".unfling" then
        stopFling()
        StarterGui:SetCore("SendNotification", {Title = "[ Fling 종료 ]", Text = "주사위 플링을 중지했습니다.", Duration = 3})

    elseif lowerMsg:sub(1, 10) == ".loopgoto " then
        local targetNamePart, targetPlayer = lowerMsg:sub(11):match("^%s*(.-)%s*$"), nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then
                local pName, pDisplay = p.Name:lower(), p.DisplayName:lower()
                if pName:sub(1, #targetNamePart) == targetNamePart or pDisplay:sub(1, #targetNamePart) == targetNamePart then
                    targetPlayer = p
                    break
                end
            end
        end
        if targetPlayer then
            startLoopGoto(targetPlayer)
            StarterGui:SetCore("SendNotification", {
                Title = "[ Loop Goto ]",
                Text = targetPlayer.Name .. "님을 계속 따라갑니다. .unloopgoto로 중지",
                Duration = 4
            })
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "플레이어를 찾을 수 없습니다.", Duration = 3})
        end

    elseif lowerMsg == ".unloopgoto" then
        stopLoopGoto()
        StarterGui:SetCore("SendNotification", {Title = "[ Loop Goto 종료 ]", Text = "따라가기를 중지했습니다.", Duration = 3})

    elseif lowerMsg:sub(1, 6) == ".lpgo " then
        local targetNamePart, targetPlayer = lowerMsg:sub(7):match("^%s*(.-)%s*$"), nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then
                local pName, pDisplay = p.Name:lower(), p.DisplayName:lower()
                if pName:sub(1, #targetNamePart) == targetNamePart or pDisplay:sub(1, #targetNamePart) == targetNamePart then
                    targetPlayer = p
                    break
                end
            end
        end
        if targetPlayer then
            startLoopGoto(targetPlayer)
            StarterGui:SetCore("SendNotification", {
                Title = "[ Loop Goto ]",
                Text = targetPlayer.Name .. "님을 계속 따라갑니다. .unlpgo로 중지",
                Duration = 4
            })
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "플레이어를 찾을 수 없습니다.", Duration = 3})
        end

    elseif lowerMsg == ".unlpgo" then
        stopLoopGoto()
        StarterGui:SetCore("SendNotification", {Title = "[ Loop Goto 종료 ]", Text = "따라가기를 중지했습니다.", Duration = 3})

    elseif lowerMsg:sub(1, 8) == ".walkto " then
        local targetNamePart, targetPlayer = lowerMsg:sub(9):match("^%s*(.-)%s*$"), nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then
                local pName, pDisplay = p.Name:lower(), p.DisplayName:lower()
                if pName:sub(1, #targetNamePart) == targetNamePart or pDisplay:sub(1, #targetNamePart) == targetNamePart then
                    targetPlayer = p
                    break
                end
            end
        end
        if targetPlayer then
            startWalkTo(targetPlayer)
            StarterGui:SetCore("SendNotification", {
                Title = "[ WalkTo ]",
                Text = targetPlayer.Name .. "님에게 걸어갑니다. .unwalkto로 중지",
                Duration = 4
            })
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "플레이어를 찾을 수 없습니다.", Duration = 3})
        end

    elseif lowerMsg == ".unwalkto" then
        stopWalkTo()
        StarterGui:SetCore("SendNotification", {Title = "[ WalkTo 종료 ]", Text = "걸어가기를 중지했습니다.", Duration = 3})

    elseif lowerMsg:sub(1, 6) == ".join " then
        local targetNamePart = lowerMsg:sub(7)
        local success, onlineFriends = pcall(function() return lp:GetFriendsOnline(200) end)
        if success then
            local foundFriend = nil
            for _, friend in ipairs(onlineFriends) do
                local fName, fDisplay = friend.UserName:lower(), friend.DisplayName:lower()
                if fName:sub(1, #targetNamePart) == targetNamePart or fDisplay:sub(1, #targetNamePart) == targetNamePart then
                    foundFriend = friend
                    break
                end
            end
            if foundFriend then
                StarterGui:SetCore("SendNotification", {Title = "[ 접속 시도 ]", Text = foundFriend.UserName .. "님에게 이동합니다...", Duration = 3})
                local placeId = foundFriend.PlaceId
                if placeId then
                    if placeId ~= game.PlaceId then TeleportService:Teleport(placeId, lp)
                    else
                        pcall(function() TeleportService:TeleportToPlaceInstance(placeId, foundFriend.GameId, lp) end)
                    end
                end
            else StarterGui:SetCore("SendNotification", {Title = "[ 찾을 수 없음 ]", Text = "친구가 오프라인이거나 찾을 수 없습니다.", Duration = 3}) end
        end

    elseif lowerMsg == ".jobid" then
        setclipboard(tostring(game.JobId))
        StarterGui:SetCore("SendNotification", {Title = "[ 복사 완료 ]", Text = "Job ID가 복사되었습니다.", Duration = 2})

    elseif lowerMsg:sub(1, 5) == ".age " then
        local targetNamePart, targetP = lowerMsg:sub(6), nil
        for _, p in ipairs(Players:GetPlayers()) do
            local pName, pDisplay = p.Name:lower(), p.DisplayName:lower()
            if pName:sub(1, #targetNamePart) == targetNamePart or pDisplay:sub(1, #targetNamePart) == targetNamePart then
                targetP = p
                break
            end
        end
        if targetP then
            local days = targetP.AccountAge
            local years, remainingDays = math.floor(days / 365), days % 365
            local months, createdTime = math.floor(remainingDays / 30), os.time() - (days * 86400)
            local createdDate, ageText =
                os.date("%Y년 %m월 %d일", createdTime),
                days .. "일 (약 " .. years .. "년 " .. months .. "개월)"
            StarterGui:SetCore("SendNotification", { Title = targetP.Name .. " 정보", Text = "계정 나이: " .. ageText .. "\n가입일: " .. createdDate, Duration = 6 })
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "플레이어를 찾을 수 없습니다.", Duration = 3})
        end

    elseif lowerMsg == ".fullbright" or lowerMsg == ".fb" then
        if not S.fullbrightLoop then
            S.savedLightingSettings = { Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows, OutdoorAmbient = Lighting.OutdoorAmbient, Ambient = Lighting.Ambient }
            S.fullbrightLoop = getgenv().__DST(RunService.RenderStepped:Connect(function()
                Lighting.Brightness = 1.5
                Lighting.ClockTime = 13
                Lighting.FogEnd = 70000
                Lighting.GlobalShadows = false
                Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
                Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            end))
            StarterGui:SetCore("SendNotification", {Title = "[ Fullbright 켜짐 ]", Text = "맵이 최대 밝기로 유지됩니다.", Duration = 3})
        else
            S.fullbrightLoop:Disconnect()
            S.fullbrightLoop = nil
            if S.savedLightingSettings.Brightness then
                Lighting.Brightness = S.savedLightingSettings.Brightness
                Lighting.ClockTime = S.savedLightingSettings.ClockTime
                Lighting.FogEnd = S.savedLightingSettings.FogEnd
                Lighting.GlobalShadows = S.savedLightingSettings.GlobalShadows
                Lighting.OutdoorAmbient = S.savedLightingSettings.OutdoorAmbient
                Lighting.Ambient = S.savedLightingSettings.Ambient
            end
            StarterGui:SetCore("SendNotification", {Title = "[ Fullbright 꺼짐 ]", Text = "원래 밝기로 복구되었습니다.", Duration = 3})
        end

    elseif lowerMsg == ".unfullbright" or lowerMsg == ".unfb" then
        if S.fullbrightLoop then
            S.fullbrightLoop:Disconnect()
            S.fullbrightLoop = nil
            if S.savedLightingSettings.Brightness then
                Lighting.Brightness = S.savedLightingSettings.Brightness
                Lighting.ClockTime = S.savedLightingSettings.ClockTime
                Lighting.FogEnd = S.savedLightingSettings.FogEnd
                Lighting.GlobalShadows = S.savedLightingSettings.GlobalShadows
                Lighting.OutdoorAmbient = S.savedLightingSettings.OutdoorAmbient
                Lighting.Ambient = S.savedLightingSettings.Ambient
            else
                Lighting.Brightness = 0.1
                Lighting.GlobalShadows = true
            end
            StarterGui:SetCore("SendNotification", {Title = "[ Fullbright 해제 ]", Text = "밝기를 원래대로 되돌렸습니다.", Duration = 3})
        else
            StarterGui:SetCore("SendNotification", {Title = "[ Fullbright ]", Text = "이미 꺼져 있습니다.", Duration = 2})
        end

    elseif lowerMsg:sub(1, 6) == ".xray " then
        local levelArg = tonumber(lowerMsg:sub(7):match("^%s*(.-)%s*$"))
        if levelArg and levelArg >= 0 and levelArg <= 1 then
            M.xrayLevel = levelArg
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "0~1 사이의 숫자를 입력해주세요. 예: .xray 0.2", Duration = 3})
            return
        end
        M.xrayEnabled = true
        M.xrayApply(M.xrayLevel)
        StarterGui:SetCore("SendNotification", {Title = "[ Xray 켜짐 ]", Text = "투명도: " .. M.xrayLevel, Duration = 3})

    elseif lowerMsg == ".xray" then
        M.xrayLevel = M.xrayDefaultLevel
        M.xrayEnabled = true
        M.xrayApply(M.xrayLevel)
        StarterGui:SetCore("SendNotification", {Title = "[ Xray 켜짐 ]", Text = "투명도: " .. M.xrayLevel .. " (기본값)", Duration = 3})

    elseif lowerMsg == ".unxray" or lowerMsg == ".noxray" then
        M.xrayEnabled = false
        M.xrayApply(0)
        StarterGui:SetCore("SendNotification", {Title = "[ Xray 꺼짐 ]", Text = "원래 투명도로 복구되었습니다.", Duration = 3})

    elseif lowerMsg == ".togglexray" then
        M.xrayEnabled = not M.xrayEnabled
        local applyLevel = M.xrayEnabled and M.xrayLevel or 0
        M.xrayApply(applyLevel)
        StarterGui:SetCore("SendNotification", {Title = M.xrayEnabled and "[ Xray 켜짐 ]" or "[ Xray 꺼짐 ]", Text = M.xrayEnabled and ("투명도: " .. M.xrayLevel) or "원래 투명도로 복구되었습니다.", Duration = 3})

    elseif lowerMsg:sub(1, 8) == ".lpxray " then
        local levelArg = tonumber(lowerMsg:sub(9):match("^%s*(.-)%s*$"))
        if levelArg and levelArg >= 0 and levelArg <= 1 then
            M.xrayLevel = levelArg
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 오류 ]", Text = "0~1 사이의 숫자를 입력해주세요. 예: .lpxray 0.3", Duration = 3})
            return
        end
        if M.xrayLoopConnection then M.xrayLoopConnection:Disconnect() end
        M.xrayEnabled = true
        local xrayCache, xrayTimer, xrayBuilding = {}, math.huge, false
        M.xrayLoopConnection = getgenv().__DST(RunService.RenderStepped:Connect(function(dt)
            xrayTimer = xrayTimer + dt
            if xrayTimer >= 1 and not xrayBuilding then
                xrayTimer = 0
                xrayBuilding = true
                getgenv().__DSTH(task.spawn(function()
                    local list, n, seen, hum = {}, 0, 0, {}
                    for _, v in ipairs(workspace:GetDescendants()) do
                        if v:IsA("BasePart") then
                            local p = v.Parent
                            local skip = hum[p]
                            if skip == nil then
                                local pp = p and p.Parent
                                skip = (p and (p:FindFirstChildWhichIsA("Humanoid") or (pp and pp:FindFirstChildWhichIsA("Humanoid")))) and true or false
                                hum[p] = skip
                            end
                            if p and not skip then
                                n = n + 1
                                list[n] = v
                            end
                        end
                        seen = seen + 1
                        if seen % 400 == 0 then task.wait() end
                    end
                    xrayCache = list
                    xrayBuilding = false
                end))
            end
            local level = M.xrayLevel
            for i = 1, #xrayCache do
                local v = xrayCache[i]
                if v.LocalTransparencyModifier ~= level then
                    v.LocalTransparencyModifier = level
                end
            end
        end))
        StarterGui:SetCore("SendNotification", {Title = "[ LoopXray 켜짐 ]", Text = "투명도: " .. M.xrayLevel, Duration = 3})

    elseif lowerMsg == ".lpxray" then
        M.xrayLevel = M.xrayDefaultLevel
        if M.xrayLoopConnection then M.xrayLoopConnection:Disconnect() end
        M.xrayEnabled = true
        local xrayCache, xrayTimer, xrayBuilding = {}, math.huge, false
        M.xrayLoopConnection = getgenv().__DST(RunService.RenderStepped:Connect(function(dt)
            xrayTimer = xrayTimer + dt
            if xrayTimer >= 1 and not xrayBuilding then
                xrayTimer = 0
                xrayBuilding = true
                getgenv().__DSTH(task.spawn(function()
                    local list, n, seen, hum = {}, 0, 0, {}
                    for _, v in ipairs(workspace:GetDescendants()) do
                        if v:IsA("BasePart") then
                            local p = v.Parent
                            local skip = hum[p]
                            if skip == nil then
                                local pp = p and p.Parent
                                skip = (p and (p:FindFirstChildWhichIsA("Humanoid") or (pp and pp:FindFirstChildWhichIsA("Humanoid")))) and true or false
                                hum[p] = skip
                            end
                            if p and not skip then
                                n = n + 1
                                list[n] = v
                            end
                        end
                        seen = seen + 1
                        if seen % 400 == 0 then task.wait() end
                    end
                    xrayCache = list
                    xrayBuilding = false
                end))
            end
            local level = M.xrayLevel
            for i = 1, #xrayCache do
                local v = xrayCache[i]
                if v.LocalTransparencyModifier ~= level then
                    v.LocalTransparencyModifier = level
                end
            end
        end))
        StarterGui:SetCore("SendNotification", {Title = "[ LoopXray 켜짐 ]", Text = "투명도: " .. M.xrayLevel .. " (기본값)", Duration = 3})

    elseif lowerMsg == ".unloopxray" then
        if M.xrayLoopConnection then
            M.xrayLoopConnection:Disconnect()
            M.xrayLoopConnection = nil
        end
        M.xrayEnabled = false
        M.xrayApply(0)
        StarterGui:SetCore("SendNotification", {Title = "[ LoopXray 꺼짐 ]", Text = "원래 투명도로 복구되었습니다.", Duration = 3})

    elseif lowerMsg == ".invis" or lowerMsg == ".invisible" then
        if not M.invisEnabled then
            M.invisEnabled = true
            local character = lp.Character or lp.CharacterAdded:Wait()
            local hrp = character:WaitForChild("HumanoidRootPart")
            getgenv().__DST(lp.CharacterAdded:Connect(function(newChar)
                hrp = newChar:WaitForChild("HumanoidRootPart")
            end))
            local camera = workspace.CurrentCamera
            local OFFSET = Vector3.new(0, -8, 0)
            M.invisLoopConnection = getgenv().__DST(RunService.Heartbeat:Connect(function()
                if not hrp or not hrp.Parent then return end
                local currentCFrame = hrp.CFrame
                hrp.CFrame = (currentCFrame * CFrame.new(0, -8, 0))
                RunService.RenderStepped:Wait()
                hrp.CFrame = currentCFrame
            end))
            M.invisCamConnection = getgenv().__DST(RunService.RenderStepped:Connect(function()
                camera.CFrame = camera.CFrame - OFFSET
            end))
            StarterGui:SetCore("SendNotification", {Title = "[ Invisible 켜짐 ]", Text = "캐릭터가 발 밑으로 내려갑니다.", Duration = 3})
        else
            StarterGui:SetCore("SendNotification", {Title = "[ Invisible ]", Text = "이미 켜져 있습니다.", Duration = 2})
        end

    elseif lowerMsg == ".uninvis" or lowerMsg == ".uninvisible" then
        if M.invisEnabled then
            M.invisEnabled = false
            if M.invisLoopConnection then
                M.invisLoopConnection:Disconnect()
                M.invisLoopConnection = nil
            end
            if M.invisCamConnection then
                M.invisCamConnection:Disconnect()
                M.invisCamConnection = nil
            end
            StarterGui:SetCore("SendNotification", {Title = "[ Invisible 꺼짐 ]", Text = "원래대로 복구되었습니다.", Duration = 3})
        else
            StarterGui:SetCore("SendNotification", {Title = "[ Invisible ]", Text = "이미 꺼져 있습니다.", Duration = 2})
        end

    elseif lowerMsg == ".nofog" then
        if not S.nofogSaved then
            local saved = {FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor, Atmospheres = {}}
            for _, v in pairs(Lighting:GetChildren()) do
                if v:IsA("Atmosphere") then
                    local ok, copy = pcall(function() return v:Clone() end)
                    if ok and copy then table.insert(saved.Atmospheres, copy) end
                end
            end
            S.nofogSaved = saved
        end
        Lighting.FogEnd = 1000000; Lighting.FogStart = 0
        for _, v in pairs(Lighting:GetChildren()) do if v:IsA("Atmosphere") then v:Destroy() end end
        StarterGui:SetCore("SendNotification", {Title = "[ 안개 제거 완료 ]", Text = "안개와 Atmosphere를 제거했습니다.", Duration = 3})

    elseif lowerMsg == ".unnofog" then
        local saved = S.nofogSaved
        if not saved then
            StarterGui:SetCore("SendNotification", {Title = "[ UnNoFog ]", Text = "복구할 안개 값이 없습니다.", Duration = 2})
        else
            Lighting.FogEnd = saved.FogEnd
            Lighting.FogStart = saved.FogStart
            Lighting.FogColor = saved.FogColor
            if not Lighting:FindFirstChildWhichIsA("Atmosphere") then
                for _, atmo in ipairs(saved.Atmospheres) do
                    atmo.Parent = Lighting
                end
            end
            S.nofogSaved = nil
            StarterGui:SetCore("SendNotification", {Title = "[ 안개 복구 완료 ]", Text = "원래 안개 값으로 복구했습니다.", Duration = 3})
        end

    elseif lowerMsg == ".noblur" then
        if M.noBlurEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ NoBlur ]", Text = "이미 켜져 있습니다.", Duration = 2})
        else
            M.noBlurEnabled = true
            M.noBlurSaved = {}
            M.noBlurConns = {}
            local function nbHandle(obj)
                if obj:IsA("BlurEffect") then
                    if M.noBlurSaved[obj] == nil then M.noBlurSaved[obj] = obj.Enabled end
                    obj.Enabled = false
                    table.insert(M.noBlurConns, getgenv().__DST(obj:GetPropertyChangedSignal("Enabled"):Connect(function()
                        if M.noBlurEnabled and obj.Enabled then obj.Enabled = false end
                    end)))
                end
            end
            local nbRoots = {Lighting, game:GetService("Workspace").CurrentCamera}
            for _, root in ipairs(nbRoots) do
                if root then
                    for _, obj in ipairs(root:GetDescendants()) do nbHandle(obj) end
                    table.insert(M.noBlurConns, getgenv().__DST(root.DescendantAdded:Connect(nbHandle)))
                end
            end
            StarterGui:SetCore("SendNotification", {Title = "[ NoBlur 켜짐 ]", Text = "화면 블러를 제거했습니다.", Duration = 3})
        end

    elseif lowerMsg == ".unnoblur" then
        if M.noBlurEnabled then
            M.noBlurEnabled = false
            for _, c in ipairs(M.noBlurConns or {}) do pcall(function() c:Disconnect() end) end
            M.noBlurConns = nil
            for obj, wasEnabled in pairs(M.noBlurSaved or {}) do
                if obj and obj.Parent then pcall(function() obj.Enabled = wasEnabled end) end
            end
            M.noBlurSaved = nil
            StarterGui:SetCore("SendNotification", {Title = "[ NoBlur 해제 ]", Text = "화면 블러를 원래대로 복구했습니다.", Duration = 3})
        else
            StarterGui:SetCore("SendNotification", {Title = "[ NoBlur ]", Text = "이미 꺼져 있습니다.", Duration = 2})
        end

    elseif lowerMsg == ".infjump" then
        if not M.infJumpConnection then
            if lp.Character and lp.Character:FindFirstChild("Humanoid") then M.previousJumpPower = lp.Character.Humanoid.JumpPower else M.previousJumpPower = nil end
            M.infJumpConnection = getgenv().__DST(UserInputService.JumpRequest:Connect(function()
                if lp.Character and lp.Character:FindFirstChild("Humanoid") then lp.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
            end))
            StarterGui:SetCore("SendNotification", {Title = "[ InfJump 켜짐 ]", Text = "공중 점프가 가능합니다.", Duration = 3})
        else StarterGui:SetCore("SendNotification", {Title = "[ InfJump ]", Text = "이미 켜져 있습니다.", Duration = 2}) end

    elseif lowerMsg == ".uninfjump" then
        if M.infJumpConnection then
            M.infJumpConnection:Disconnect()
            M.infJumpConnection = nil
            if M.previousJumpPower and lp.Character and lp.Character:FindFirstChild("Humanoid") then pcall(function() lp.Character.Humanoid.JumpPower = M.previousJumpPower end) end
            StarterGui:SetCore("SendNotification", {Title = "[ InfJump 해제 ]", Text = "무한 점프가 꺼졌습니다.", Duration = 3})
        else
            StarterGui:SetCore("SendNotification", {Title = "[ InfJump ]", Text = "이미 꺼져 있습니다.", Duration = 2})
        end

    elseif lowerMsg == ".walkfling" or lowerMsg == ".wf" then
        if M.walkflingEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ WalkFling ]", Text = "이미 켜져 있습니다.", Duration = 2})
            return
        end
        M.walkflingEnabled = true
        toggleNoclip(true)
        StarterGui:SetCore("SendNotification", {Title = "[ WalkFling 활성화 ]", Text = "WalkFling 및 Noclip이 켜졌습니다.", Duration = 3})
        getgenv().__DSTH(task.spawn(function()
            local movel = 0.1
            while M.walkflingEnabled do
                RunService.Heartbeat:Wait()
                local character = lp.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if character and character.Parent and root and root.Parent then
                    local vel = root.Velocity
                    root.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
                    RunService.RenderStepped:Wait()
                    if not M.walkflingEnabled then break end
                    if character and character.Parent and root and root.Parent then root.Velocity = vel end
                    RunService.Stepped:Wait()
                    if not M.walkflingEnabled then break end
                    if character and character.Parent and root and root.Parent then
                        root.Velocity = vel + Vector3.new(0, movel, 0)
                        movel = movel * -1
                    end
                else RunService.Heartbeat:Wait() end
            end
        end))

    elseif lowerMsg == ".unwalkfling" or lowerMsg == ".unwf" then
        if not M.walkflingEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ WalkFling ]", Text = "이미 꺼져 있습니다.", Duration = 2})
        else
            M.walkflingEnabled = false
            toggleNoclip(false)
            if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then lp.Character.HumanoidRootPart.Velocity = Vector3.new(0,0,0) end
            StarterGui:SetCore("SendNotification", {Title = "[ WalkFling 해제 ]", Text = "WalkFling 및 Noclip이 꺼졌습니다.", Duration = 3})
        end

    elseif lowerMsg == ".noclip" then
        if M.noclipConnection then
            StarterGui:SetCore("SendNotification", {Title = "[ Noclip ]", Text = "이미 켜져 있습니다.", Duration = 2})
        else
            toggleNoclip(true); StarterGui:SetCore("SendNotification", {Title = "[ Noclip 활성화 ]", Text = "벽을 통과할 수 있습니다.", Duration = 3})
        end
    elseif lowerMsg == ".unnoclip" then
        if not M.noclipConnection then
            StarterGui:SetCore("SendNotification", {Title = "[ Noclip ]", Text = "이미 꺼져 있습니다.", Duration = 2})
        else
            toggleNoclip(false); StarterGui:SetCore("SendNotification", {Title = "[ Noclip 비활성화 ]", Text = "다시 벽에 충돌합니다.", Duration = 3})
        end
    elseif lowerMsg == ".fly" or lowerMsg:match("^%.fly%s+%S+$") then
        local spd = tonumber(lowerMsg:sub(6))
        startFlying("fly", lowerMsg:sub(6))
    elseif lowerMsg:sub(1, 5) == ".vfly" then
        local spd, isMobile =
            tonumber(lowerMsg:sub(7)),
            UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
        if isMobile or game.PlaceId ~= 6961824067 then
            M.vflyToggleEnabled = true
            M.vflyToggleActive = true
            M.vflyToggleSpeed = lowerMsg:sub(7)
            startFlying("vfly", M.vflyToggleSpeed)
            StarterGui:SetCore("SendNotification", {Title = "[ VFly 켜짐 ]", Text = ".unvfly 로 끌 수 있습니다.", Duration = 4})
        else
            if not M.vflyToggleEnabled then
                M.vflyToggleEnabled = true
                M.vflyToggleActive = false
                M.vflyToggleSpeed = lowerMsg:sub(7)
                StarterGui:SetCore("SendNotification", {Title = "[ VFly 준비됨 ]", Text = "숫자 [1] 키로 비행을 켜고 끄세요.", Duration = 4})
            else
                if spd then
                    M.vflyToggleSpeed = lowerMsg:sub(7)
                    if M.vflyToggleActive then
                        startFlying("vfly", M.vflyToggleSpeed)
                    end
                    StarterGui:SetCore("SendNotification", {Title = "[ VFly 속도 변경 ]", Text = "속도: " .. spd, Duration = 2})
                else
                    StarterGui:SetCore("SendNotification", {Title = "[ VFly ]", Text = "이미 켜져 있습니다. [1]키로 토글하세요.", Duration = 2})
                end
            end
        end
    elseif lowerMsg == ".unfly" then
        if not M.flyConnection then
            StarterGui:SetCore("SendNotification", {Title = "[ Fly ]", Text = "이미 꺼져 있습니다.", Duration = 2})
        else
            stopFlying(); StarterGui:SetCore("SendNotification", {Title = "[ Fly 꺼짐 ]", Text = "비행이 중지되었습니다.", Duration = 3})
        end
    elseif lowerMsg == ".unvfly" then
        if not M.flyConnection and not M.vflyToggleEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ VFly ]", Text = "이미 꺼져 있습니다.", Duration = 2})
        else
            M.vflyToggleEnabled = false
            M.vflyToggleActive = false
            M.vflyToggleSpeed = nil
            stopFlying(); StarterGui:SetCore("SendNotification", {Title = "[ VFly 꺼짐 ]", Text = "비행이 중지되었습니다.", Duration = 3})
        end

    elseif lowerMsg:sub(1, 6) == ".spin " then
        local speed = tonumber(msg:sub(7))
        if speed then
            toggleSpin(true, speed)
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 사용법 ]", Text = ".spin [숫자] - 숫자만큼 속도로 회전", Duration = 4})
        end
    elseif lowerMsg == ".unspin" then
        if not M.spinEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ Spin ]", Text = "이미 꺼져 있습니다.", Duration = 2})
        else
            toggleSpin(false)
        end

    elseif lowerMsg == ".sg" or lowerMsg == ".spingrab" or lowerMsg:sub(1, 4) == ".sg " or lowerMsg:sub(1, 10) == ".spingrab " then
        local speedArg
        if lowerMsg:sub(1, 4) == ".sg " then
            speedArg = msg:sub(5)
        elseif lowerMsg:sub(1, 10) == ".spingrab " then
            speedArg = msg:sub(11)
        end
        local parsedSpeed = speedArg and tonumber(speedArg:match("^%s*(.-)%s*$"))
        if M.spinGrabEnabled then
            if parsedSpeed then
                M.spinGrabSpeed = parsedSpeed
                StarterGui:SetCore("SendNotification", {Title = "[ Spin Grab 속도 변경 ]", Text = "회전 속도: " .. parsedSpeed, Duration = 3})
            else
                StarterGui:SetCore("SendNotification", {Title = "[ Spin Grab ]", Text = "이미 켜져 있습니다.", Duration = 2})
            end
        else
            local speed = parsedSpeed or 20
            M.startSpinGrab(speed)
            StarterGui:SetCore("SendNotification", {Title = "[ Spin Grab 켜짐 ]", Text = "회전 속도: " .. speed, Duration = 3})
        end
    elseif lowerMsg == ".unsg" or lowerMsg == ".unspingrab" then
        if not M.spinGrabEnabled then
            StarterGui:SetCore("SendNotification", {Title = "[ Spin Grab ]", Text = "이미 꺼져 있습니다.", Duration = 2})
        else
            M.stopSpinGrab()
            StarterGui:SetCore("SendNotification", {Title = "[ Spin Grab 꺼짐 ]", Text = "회전이 중지되었습니다.", Duration = 3})
        end

    elseif lowerMsg == ".thirdp" then
        if M.thirdpConnection then M.thirdpConnection:Disconnect() M.thirdpConnection = nil end
        if M.zoomWheelConn then M.zoomWheelConn:Disconnect() M.zoomWheelConn = nil end
        if M.zoomPinchConn then M.zoomPinchConn:Disconnect() M.zoomPinchConn = nil end

        lp.CameraMode = Enum.CameraMode.Classic
        lp.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam

        local minZoomLimit, maxZoomLimit = 0.5, 999
        M.zoomCurrent = math.clamp(lp.CameraMaxZoomDistance, minZoomLimit, maxZoomLimit)
        M.zoomTarget = M.zoomCurrent
        lp.CameraMinZoomDistance = minZoomLimit
        lp.CameraMaxZoomDistance = maxZoomLimit

        M.zoomWheelConn = getgenv().__DST(UserInputService.InputChanged:Connect(function(input, gpe)
            if not gpe and input.UserInputType == Enum.UserInputType.MouseWheel then
                local zoomSpeed = M.zoomTarget * 0.3
                M.zoomTarget = math.clamp(M.zoomTarget - (input.Position.Z * zoomSpeed), minZoomLimit, maxZoomLimit)
            end
        end))

        local pinchLastScale = nil
        M.zoomPinchConn = getgenv().__DST(UserInputService.TouchPinch:Connect(function(touchPositions, scale, velocity, state)
            if state == Enum.UserInputState.Begin then
                pinchLastScale = scale
            elseif state == Enum.UserInputState.Change and pinchLastScale then
                local pinchSpeed = M.zoomTarget * 2.5
                M.zoomTarget = math.clamp(M.zoomTarget - ((scale - pinchLastScale) * pinchSpeed), minZoomLimit, maxZoomLimit)
                pinchLastScale = scale
            elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
                pinchLastScale = nil
            end
        end))

        M.thirdpConnection = getgenv().__DST(RunService.Heartbeat:Connect(function(dt)
            if lp.CameraMode ~= Enum.CameraMode.Classic then lp.CameraMode = Enum.CameraMode.Classic end
            if lp.DevCameraOcclusionMode ~= Enum.DevCameraOcclusionMode.Invisicam then lp.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam end
            M.zoomCurrent = M.zoomCurrent + (M.zoomTarget - M.zoomCurrent) * math.clamp(dt * 10, 0, 1)
            lp.CameraMinZoomDistance = M.zoomCurrent
            lp.CameraMaxZoomDistance = M.zoomCurrent
        end))

        if game.PlaceId == 6961824067 then
            StarterGui:SetCore("SendNotification", {Title = "[ 3인칭 활성화 ]", Text = "휠/핀치 줌이 부드럽게 적용됩니다.", Duration = 3})
        else
            StarterGui:SetCore("SendNotification", {Title = "[ 3인칭 강제 활성화 ]", Text = "1인칭 강제 전환을 막고, 휠/핀치 줌이 부드럽게 적용됩니다.", Duration = 3})
        end

    elseif lowerMsg == ".firstp" then
        if M.thirdpConnection then M.thirdpConnection:Disconnect() M.thirdpConnection = nil end
        if M.zoomWheelConn then M.zoomWheelConn:Disconnect() M.zoomWheelConn = nil end
        if M.zoomPinchConn then M.zoomPinchConn:Disconnect() M.zoomPinchConn = nil end
        lp.CameraMode = Enum.CameraMode.LockFirstPerson
        TweenService:Create(lp, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CameraMaxZoomDistance = 0.5, CameraMinZoomDistance = 0.5}):Play()
        StarterGui:SetCore("SendNotification", {Title = "[ 1인칭 활성화 ]", Text = "1인칭 시점으로 고정됩니다.", Duration = 3})

    elseif lowerMsg:sub(1, 4) == ".to " then
        local targetNamePart, targetPlayer = lowerMsg:sub(5), nil
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= lp then
                local pName, pDisplay = p.Name:lower(), p.DisplayName:lower()
                if pName:sub(1, #targetNamePart) == targetNamePart or pDisplay:sub(1, #targetNamePart) == targetNamePart then
                    targetPlayer = p
                    break
                end
            end
        end
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local targetHRP, myHRP =
                targetPlayer.Character.HumanoidRootPart,
                lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            if myHRP then
                local offsetCFrame = CFrame.new(-5, 0, 5)
                myHRP.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                myHRP.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                myHRP.CFrame = targetHRP.CFrame * offsetCFrame
                myHRP.Anchored = true
                StarterGui:SetCore("SendNotification", {Title = "[ 이 이동 완료 ]", Text = targetPlayer.Name .. "님에게 이동", Duration = 2})
                getgenv().__DSTH(task.delay(0.3, function() if myHRP then myHRP.Anchored = false end end))
            end
        end

    elseif lowerMsg:sub(1, 6) == ".view " then
        local targetNamePart, targetP = lowerMsg:sub(7), nil
        for _, p in ipairs(Players:GetPlayers()) do
            local pName, pDisplay = p.Name:lower(), p.DisplayName:lower()
            if pName:sub(1, #targetNamePart) == targetNamePart or pDisplay:sub(1, #targetNamePart) == targetNamePart then
                targetP = p
                break
            end
        end
        if targetP then
            F.viewingPlayer = targetP
            if F.viewConnection then F.viewConnection:Disconnect() F.viewConnection = nil end
            if F.viewLeaveConnection then F.viewLeaveConnection:Disconnect() F.viewLeaveConnection = nil end
            if F.viewUpdateConnection then F.viewUpdateConnection:Disconnect() F.viewUpdateConnection = nil end

            local function setView()
                if not F.viewingPlayer then return end
                local char = F.viewingPlayer.Character
                if char then
                    local hum = char:FindFirstChild("Humanoid")
                    if hum and workspace.CurrentCamera then
                        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                        workspace.CurrentCamera.CameraSubject = hum
                    end
                end
            end

            setView()

            F.viewUpdateConnection = getgenv().__DST(RunService.RenderStepped:Connect(function()
                if F.viewingPlayer and workspace.CurrentCamera then
                    setView()
                end
            end))

            F.viewConnection = getgenv().__DST(targetP.CharacterAdded:Connect(function(char)
                task.wait(0.2)
                if not F.viewingPlayer then return end
                local hum = char:WaitForChild("Humanoid", 5)
                if hum and workspace.CurrentCamera then
                    workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
                    workspace.CurrentCamera.CameraSubject = hum
                end
            end))
            F.viewLeaveConnection = getgenv().__DST(Players.PlayerRemoving:Connect(function(removedPlayer)
                if removedPlayer == F.viewingPlayer then
                    if F.viewConnection then F.viewConnection:Disconnect() F.viewConnection = nil end
                    if F.viewLeaveConnection then F.viewLeaveConnection:Disconnect() F.viewLeaveConnection = nil end
                    if F.viewUpdateConnection then F.viewUpdateConnection:Disconnect() F.viewUpdateConnection = nil end
                    F.viewingPlayer = nil
                    if lp.Character and lp.Character:FindFirstChild("Humanoid") then
                        workspace.CurrentCamera.CameraSubject = lp.Character.Humanoid
                    end
                    StarterGui:SetCore("SendNotification", {Title = "[ 관전 종료 ]", Text = removedPlayer.Name .. "님이 나가서 본인 시점으로 돌아왔습니다.", Duration = 3})
                end
            end))
            StarterGui:SetCore("SendNotification", {Title = "[ 관전 모드 ]", Text = targetP.Name .. "님을 관전합니다 (자동 추적).", Duration = 3})
        end

    elseif lowerMsg == ".unview" then
        if F.viewConnection then F.viewConnection:Disconnect() F.viewConnection = nil end
        if F.viewLeaveConnection then F.viewLeaveConnection:Disconnect() F.viewLeaveConnection = nil end
        if F.viewUpdateConnection then F.viewUpdateConnection:Disconnect() F.viewUpdateConnection = nil end
        F.viewingPlayer = nil
        if lp.Character and lp.Character:FindFirstChild("Humanoid") then
            workspace.CurrentCamera.CameraSubject = lp.Character.Humanoid
            StarterGui:SetCore("SendNotification", {Title = "[ 관전 종료 ]", Text = "본인 시점으로 돌아왔습니다.", Duration = 3})
        end

    elseif lowerMsg == ".freecam" or lowerMsg == ".fc" then
        Z.StartFreecam()

    elseif lowerMsg == ".unfreecam" or lowerMsg == ".unfc" then
        Z.StopFreecam()
    else
        processCommandPart3(msg, lowerMsg)
    end
end

processCommandPart3 = function(msg, lowerMsg)
    if lowerMsg == ".ovenall" or lowerMsg:match("^%.ovenall%s+") then
        local genv = getgenv()
        if genv.Loopovenall then
            StarterGui:SetCore("SendNotification", {Title = "[ Oven All ]", Text = "이미 실행중입니다.", Duration = 3})
            return
        end
        local ovenArg = lowerMsg:match("^%.ovenall%s+(%S+)")
        local ovenFriendWL = true
        if ovenArg == "false" then
            ovenFriendWL = false
        elseif ovenArg ~= nil and ovenArg ~= "true" then
            StarterGui:SetCore("SendNotification", {Title = "[ Oven All ]", Text = "사용법: .ovenall true / .ovenall false", Duration = 3})
            return
        end
        local ovenOk, ovenErr = pcall(function()
            local Players = game:GetService("Players")
            local RS = game:GetService("ReplicatedStorage")
            local RunService = game:GetService("RunService")
            local LocalPlayer = Players.LocalPlayer
            local env = getgenv()
            local friendwhitelist = ovenFriendWL
            local DestroyToy = RS:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
            local SpawnToyRF = RS:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
            local SetNetworkOwner = RS:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
            local WhitelistedPlayers = {}
            local SpawnCooldown = 0.5
            local active = true
            local toyActive = false
            local currentToy = nil
            local lastSpawn = 0
            local visited = {}
            local friendCache = {}
            local connections = {}
            local function getRoot()
                return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            end
            local function isFriend(p)
                local cached = friendCache[p.UserId]
                if cached ~= nil then
                    return cached
                end
                local ok, result = pcall(function()
                    return LocalPlayer:IsFriendsWith(p.UserId)
                end)
                friendCache[p.UserId] = ok and result or false
                return friendCache[p.UserId]
            end
            local function destroyCurrent()
                if currentToy and currentToy.Parent then
                    pcall(function()
                        DestroyToy:FireServer(currentToy)
                    end)
                end
                currentToy = nil
                toyActive = false
                visited = {}
            end
            local function Stop()
                active = false
                destroyCurrent()
                for _, c in ipairs(connections) do
                    c:Disconnect()
                end
                connections = {}
                env.Loopovenall = nil
            end
            local function spawnToy()
                if not active then
                    return
                end
                if tick() - lastSpawn < SpawnCooldown then
                    return
                end
                lastSpawn = tick()
                local root = getRoot()
                if not root then
                    return
                end
                pcall(function()
                    SpawnToyRF:InvokeServer("OvenDarkGray", root.CFrame * CFrame.new(0, 25, 20), Vector3.new(0, -141.6, 0))
                end)
            end
            local function setOwner(toy)
                if toy and toy.Parent then
                    pcall(function()
                        local button = toy:FindFirstChild("ButtonOven")
                        if button then
                            SetNetworkOwner:FireServer(button, button.CFrame)
                        end
                    end)
                end
            end
            local function eligible(p)
                if p == LocalPlayer or WhitelistedPlayers[p.UserId] then
                    return false
                end
                if not (p.Character and p.Character:FindFirstChild("HumanoidRootPart")) then
                    return false
                end
                if friendwhitelist and isFriend(p) then
                    return false
                end
                return true
            end
            local function loop(toy)
                getgenv().__DSTH(task.spawn(function()
                    while active and toyActive and currentToy == toy and toy.Parent do
                        if not toy:FindFirstChild("ButtonOven") then
                            destroyCurrent()
                            spawnToy()
                            task.wait(0.5)
                            return
                        end
                        if not getRoot() then
                            task.wait(0.1)
                        else
                            local list = {}
                            for _, p in pairs(Players:GetPlayers()) do
                                if eligible(p) then
                                    table.insert(list, p)
                                end
                            end
                            for _, p in ipairs(list) do
                                if not (active and toyActive and currentToy == toy and toy.Parent) then
                                    break
                                end
                                if not visited[p.UserId] then
                                    local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                                    if hrp then
                                        pcall(function()
                                            toy:PivotTo(hrp.CFrame)
                                        end)
                                        visited[p.UserId] = true
                                        task.wait(0.2)
                                    end
                                end
                            end
                            local allVisited = true
                            for _, p in ipairs(list) do
                                if not visited[p.UserId] then
                                    allVisited = false
                                    break
                                end
                            end
                            if allVisited and #list > 0 then
                                visited = {}
                            end
                        end
                        task.wait()
                    end
                end))
            end
            local function onToyAdded(child)
                if child.Name == "OvenDarkGray" and active then
                    currentToy = child
                    visited = {}
                    getgenv().__DSTH(task.spawn(function()
                        task.wait(0.5)
                        if not active or currentToy ~= child then
                            return
                        end
                        setOwner(child)
                        toyActive = true
                        loop(child)
                    end))
                end
            end
            local toysFolder = workspace:FindFirstChild(LocalPlayer.Name .. "SpawnedInToys")
                or workspace:WaitForChild(LocalPlayer.Name .. "SpawnedInToys", 5)
            if not toysFolder then
                error("SpawnedInToys 폴더를 찾을 수 없습니다.")
            end
            env.Loopovenall = {Stop = Stop}
            table.insert(connections, getgenv().__DST(toysFolder.ChildAdded:Connect(onToyAdded)))
            table.insert(connections, getgenv().__DST(RunService.Heartbeat:Connect(function()
                if active and (not currentToy or not currentToy.Parent) then
                    currentToy = nil
                    visited = {}
                    spawnToy()
                end
            end)))
            spawnToy()
        end)
        if ovenOk then
            StarterGui:SetCore("SendNotification", {Title = "[ Oven All ]", Text = "시작했습니다. .unovenall로 중지", Duration = 3})
        else
            StarterGui:SetCore("SendNotification", {Title = "[ Oven All 오류 ]", Text = tostring(ovenErr), Duration = 4})
        end
        return
    elseif lowerMsg == ".unovenall" then
        local genv = getgenv()
        if genv.Loopovenall then
            genv.Loopovenall.Stop()
            StarterGui:SetCore("SendNotification", {Title = "[ Oven All 종료 ]", Text = "중지했습니다.", Duration = 3})
        else
            StarterGui:SetCore("SendNotification", {Title = "[ Oven All ]", Text = "실행중이 아닙니다.", Duration = 3})
        end
        return
    elseif lowerMsg == ".shutdown" then
        if game.PlaceId ~= 6961824067 then
            StarterGui:SetCore("SendNotification", {Title = "[ Everyone ]", Text = "이 게임에서는 사용할 수 없습니다.", Duration = 3})
            return
        end
        getgenv().__DSTH(task.spawn(function()
            local everyoneOk, everyoneErr = pcall(function()
                loadstring(game:HttpGet('https://raw.githubusercontent.com/dosi1100-cmyk/scripts/refs/heads/main/shutdown'))()
            end)
            if not everyoneOk then
                StarterGui:SetCore("SendNotification", {Title = "[ Everyone 오류 ]", Text = tostring(everyoneErr), Duration = 4})
            end
        end))
        return
    elseif lowerMsg == ".cleanall" then
        getgenv().__DSTH(task.spawn(function()
            if not game:IsLoaded() then
                game.Loaded:Wait()
            end

            local Players = game:GetService("Players")
            local RunService = game:GetService("RunService")
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local StarterGui = game:GetService("StarterGui")

            local localPlayer = Players.LocalPlayer

            local function notify(title, text, duration)
                pcall(function()
                    StarterGui:SetCore("SendNotification", {
                        Title = title or "DShub",
                        Text = text or "Notification",
                        Duration = duration or 5,
                    })
                end)
            end

            if game.PlaceId ~= 6961824067 then
                notify("DShub", "This game is not supported; couldn't start the script", 3)
                return
            end

            local env = getgenv and getgenv() or _G
            if env.DestroyAllToysRunning then
                return
            end
            env.DestroyAllToysRunning = true

            local grabEvents = ReplicatedStorage:WaitForChild("GrabEvents", 5)
            local setNetworkOwner = grabEvents and grabEvents:WaitForChild("SetNetworkOwner", 5)
            local destroyGrabLine = grabEvents and grabEvents:WaitForChild("DestroyGrabLine", 5)

            if not (setNetworkOwner and destroyGrabLine) then
                env.DestroyAllToysRunning = false
                notify("DShub", "Grab remotes not found", 3)
                return
            end

            local destroyThread = nil
            local owning = false
            local voidHeight = 0 / 0
            local originalHeight = workspace.FallenPartsDestroyHeight
            local partOwnerCache = setmetatable({}, { __mode = "k" })
            local grabbableParts = setmetatable({}, { __mode = "k" })

            local function getChar()
                local