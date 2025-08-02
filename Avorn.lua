--[[
    AVORN BETA v0.4
    Desarrollador: yordy alias the strongest
    Changelog v0.3 -> v0.4:
    - Aimbot ahora usa deltaTime (dt) para un suavizado consistente e independiente de los FPS.
    - Añadido filtrado de compañeros de equipo para Aimbot y ESP.
    - El círculo de FOV ahora tiene una animación suave de aparición/desaparición (TweenService).
    - Añadido un indicador de texto "TARGET" sobre el objetivo del Aimbot.
    - Mejorada la robustez contra cambios de resolución y cámara nula.
    - Eliminado el código manual para abrir/cerrar la UI (función nativa de Rayfield).
]]

--//=============================================================================================================\\
--||                                             [ DEPENDENCIAS ]                                                ||
--\\=============================================================================================================//

local Rayfield
local success, result = pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not success then
    game.Players.LocalPlayer:Kick("AVORN: No se pudo cargar la librería Rayfield. Error: " .. tostring(result))
    return
end

--//=============================================================================================================\\
--||                                          [ CONFIGURACIÓN DEL SCRIPT ]                                       ||
--\\=============================================================================================================//

Rayfield:CreateSplash({
    Name = "AVORN BETA", SubName = "v0.4 - Optimizando...", Color = Color3.fromRGB(255, 49, 49),
    SubColor = Color3.fromRGB(255, 184, 0), BG = Color3.fromRGB(13, 13, 13), Font = Enum.Font.SourceSans,
})

local Window = Rayfield:CreateWindow({
    Name = "AVORN BETA v0.4", LoadingTitle = "AVORN BETA", LoadingSubtitle = "por yordy alias the strongest",
    ConfigurationSaving = { Enabled = true, FolderName = "AVORN_BETA", FileName = "Config_v4" },
})

local Console = Window:CreateConsole({ Name = "Consola", MaxLogs = 100 })
Console:Log("Sistema AVORN v0.4 inicializado.")

--//=============================================================================================================\\
--||                                             [ VARIABLES GLOBALES ]                                          ||
--\\=============================================================================================================//

-- Servicios
local Players, RunService, UserInputService, Workspace, TweenService = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService"), game:GetService("Workspace"), game:GetService("TweenService")
local LocalPlayer, Camera = Players.LocalPlayer, Workspace.CurrentCamera

-- Configuración General
local Settings = { IgnoreTeammates = true }
local Aimbot = { Enabled = false, TargetPart = "Head", Key = Enum.KeyCode.E, FOV = 100, ShowFOV = true, Smoothing = 0.2, CurrentTarget = nil }
local ESP = { Enabled = false, BoxEnabled = true, TracerEnabled = false, BoxColor = Color3.fromRGB(255, 49, 49), TracerColor = Color3.fromRGB(255, 184, 0) }

-- Elementos Visuales (Drawing API)
local FOV_Circle = Drawing.new("Circle")
local TargetLabel = Drawing.new("Text")

-- Control de Rendimiento y Estado
local ESP_Elements, lastESP_Update, ESP_Update_Interval = {}, 0, 0.1
local lastViewportSize = Camera and Camera.ViewportSize or Vector2.new(0,0)

-- Inicialización de Elementos Visuales
FOV_Circle.Visible, FOV_Circle.Radius, FOV_Circle.Color, FOV_Circle.Thickness, FOV_Circle.Filled, FOV_Circle.Transparency = false, Aimbot.FOV, Color3.fromRGB(255, 255, 255), 1, false, 1
TargetLabel.Visible, TargetLabel.Text, TargetLabel.Color, TargetLabel.Center, TargetLabel.Outline = false, "TARGET", Color3.fromRGB(255, 0, 0), true, true

Console:Log("Variables y elementos visuales configurados.")

--//=============================================================================================================\\
--||                                             [ LÓGICA PRINCIPAL ]                                            ||
--\\=============================================================================================================//

local function GetClosestPlayerInFOV()
    local closestPlayer, minDistance = nil, Aimbot.FOV
    if not LocalPlayer.Character then return nil end
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            if Settings.IgnoreTeammates and player.Team and player.Team == LocalPlayer.Team then continue end
            local targetPart = player.Character:FindFirstChild(Aimbot.TargetPart)
            if targetPart then
                local screenPos, onScreen = Camera:WorldToScreenPoint(targetPart.Position)
                if onScreen then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if distance < minDistance then closestPlayer, minDistance = player, distance end
                end
            end
        end
    end
    return closestPlayer
end

local function CleanUpPlayerESP(player)
    if ESP_Elements[player] then
        for _, element in pairs(ESP_Elements[player]) do if typeof(element) == "Instance" then element:Destroy() end end
        ESP_Elements[player] = nil
    end
end

-- [NUEVO v0.4] Animación para el círculo de FOV
local function AnimateFOVCircle(visible)
    local targetTransparency = visible and 0 or 1
    local tween = TweenService:Create(FOV_Circle, TweenInfo.new(0.25), { Transparency = targetTransparency })
    if visible then FOV_Circle.Visible = true end
    tween:Play()
    tween.Completed:Connect(function()
        if not visible then FOV_Circle.Visible = false end
    end)
end

-- Bucle principal de RenderStepped
RunService.RenderStepped:Connect(function(dt)
    -- [MEJORADO v0.4] Verificación de cámara robusta
    if not Camera or not Camera.Parent then Camera = Workspace.CurrentCamera; if not Camera then return end end

    -- Lógica de Aimbot
    local targetPlayer = (Aimbot.Enabled and UserInputService:IsKeyDown(Aimbot.Key)) and GetClosestPlayerInFOV() or nil
    if targetPlayer and targetPlayer.Character then
        Aimbot.CurrentTarget = targetPlayer
        local targetPart = targetPlayer.Character:FindFirstChild(Aimbot.TargetPart)
        if targetPart then
            -- [MEJORADO v0.4] Interpolación basada en deltaTime
            local targetCFrame = CFrame.new(Camera.CFrame.Position, targetPart.Position)
            local smoothFactor = 1 - math.clamp(Aimbot.Smoothing, 0, 0.95)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothFactor * dt * 60)
        end
    else
        Aimbot.CurrentTarget = nil
    end
    
    -- [NUEVO v0.4] Lógica del indicador de objetivo
    if Aimbot.CurrentTarget and Aimbot.CurrentTarget.Character then
        local targetHead = Aimbot.CurrentTarget.Character:FindFirstChild("Head")
        if targetHead then
            local screenPos, onScreen = Camera:WorldToScreenPoint(targetHead.Position)
            if onScreen then
                TargetLabel.Position = Vector2.new(screenPos.X, screenPos.Y - 30)
                TargetLabel.Visible = true
            else
                TargetLabel.Visible = false
            end
        end
    else
        TargetLabel.Visible = false
    end

    -- Lógica de ESP (Throttled)
    if os.clock() - lastESP_Update > ESP_Update_Interval then
        lastESP_Update = os.clock()
        -- Lógica interna de ESP (con filtrado de equipo)
        for player, _ in pairs(ESP_Elements) do if not player.Parent or not player.Character or player.Character:FindFirstChildOfClass("Humanoid").Health <= 0 then CleanUpPlayerESP(player) end end
        if not ESP.Enabled then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                if Settings.IgnoreTeammates and player.Team and player.Team == LocalPlayer.Team then CleanUpPlayerESP(player); continue end
                if not ESP_Elements[player] then ESP_Elements[player] = {} end
                -- Lógica de creación/destrucción de cajas y trazadores (sin cambios funcionales)
                if ESP.BoxEnabled and not ESP_Elements[player].Box then ESP_Elements[player].Box = Instance.new("BoxHandleAdornment", Workspace) end; if ESP_Elements[player].Box then ESP_Elements[player].Box.Visible, ESP_Elements[player].Box.Adornee, ESP_Elements[player].Box.Size, ESP_Elements[player].Box.Color3, ESP_Elements[player].Box.AlwaysOnTop = true, player.Character.HumanoidRootPart, player.Character.HumanoidRootPart.Size + Vector3.new(1, 2, 1), ESP.BoxColor, true end; if not ESP.BoxEnabled and ESP_Elements[player].Box then ESP_Elements[player].Box:Destroy(); ESP_Elements[player].Box = nil end
                if ESP.TracerEnabled and not ESP_Elements[player].Tracer then ESP_Elements[player].Tracer = Instance.new("LineHandleAdornment", Workspace) end; if ESP_Elements[player].Tracer then ESP_Elements[player].Tracer.Visible, ESP_Elements[player].Tracer.Adornee, ESP_Elements[player].Tracer.From, ESP_Elements[player].Tracer.To, ESP_Elements[player].Tracer.Color3, ESP_Elements[player].Tracer.AlwaysOnTop = true, player.Character.HumanoidRootPart, Camera.CFrame.Position, player.Character.HumanoidRootPart.Position, ESP.TracerColor, true end; if not ESP.TracerEnabled and ESP_Elements[player].Tracer then ESP_Elements[player].Tracer:Destroy(); ESP_Elements[player].Tracer = nil end
            else
                CleanUpPlayerESP(player)
            end
        end
    end
end)

-- [NUEVO v0.4] Bucle para detectar cambios de resolución
RunService.Heartbeat:Connect(function()
    if not Camera then return end
    if Camera.ViewportSize ~= lastViewportSize then
        lastViewportSize = Camera.ViewportSize
        FOV_Circle.Position = Vector2.new(lastViewportSize.X / 2, lastViewportSize.Y / 2)
        Console:Log("Resolución de pantalla actualizada. FOV recentrado.")
    end
end)

--//=============================================================================================================\\
--||                                           [ MANEJADORES DE EVENTOS ]                                        ||
--\\=============================================================================================================//

Players.PlayerRemoving:Connect(CleanUpPlayerESP)
game:BindToClose(function()
    if FOV_Circle and typeof(FOV_Circle.Remove) == "function" then FOV_Circle:Remove() end
    if TargetLabel and typeof(TargetLabel.Remove) == "function" then TargetLabel:Remove() end
    for player, _ in pairs(ESP_Elements) do CleanUpPlayerESP(player) end
end)

Console:Log("Manejadores de eventos (Heartbeat, PlayerRemoving, BindToClose) conectados.")

--//=============================================================================================================\\
--||                                           [ CONFIGURACIÓN DE LA UI ]                                        ||
--\\=============================================================================================================//

-- Pestaña de Combate
local CombatTab = Window:CreateTab("Combate", "rbxassetid://4483345998")
CombatTab:CreateToggle({ Name = "Activar Aimbot", CurrentValue = Aimbot.Enabled, Flag = "AimbotEnabled", Callback = function(v) Aimbot.Enabled = v end })
CombatTab:CreateKeybind({ Name = "Tecla de Aimbot", CurrentKeybind = Aimbot.Key, Flag = "AimbotKey", Callback = function(k) Aimbot.Key = k end })
CombatTab:CreateDropdown({ Name = "Objetivo del Aimbot", Options = {"Head", "UpperTorso", "HumanoidRootPart"}, CurrentOption = Aimbot.TargetPart, Flag = "AimbotTarget", Callback = function(o) Aimbot.TargetPart = o end })
CombatTab:CreateSlider({ Name = "Suavizado de Aimbot", Min = 0, Max = 0.95, CurrentValue = Aimbot.Smoothing, Precision = 2, Flag = "AimbotSmoothing", Callback = function(v) Aimbot.Smoothing = v end })
CombatTab:CreateSection("Campo de Visión (FOV)")
CombatTab:CreateToggle({ Name = "Mostrar Círculo de FOV", CurrentValue = Aimbot.ShowFOV, Flag = "ShowFOV", Callback = function(v) Aimbot.ShowFOV = v; AnimateFOVCircle(v) end })
CombatTab:CreateSlider({ Name = "Tamaño de FOV", Min = 10, Max = 500, CurrentValue = Aimbot.FOV, Precision = 0, Flag = "FOVSize", Callback = function(v) Aimbot.FOV = v; FOV_Circle.Radius = v end })

-- Pestaña de Visuales
local VisualsTab = Window:CreateTab("Visuales", "rbxassetid://4483346342")
VisualsTab:CreateToggle({ Name = "Activar ESP", CurrentValue = ESP.Enabled, Flag = "ESPEnabled", Callback = function(v) ESP.Enabled = v; if not v then for p,_ in pairs(ESP_Elements) do CleanUpPlayerESP(p) end end end })
VisualsTab:CreateSection("Componentes ESP")
VisualsTab:CreateToggle({ Name = "ESP de Caja", CurrentValue = ESP.BoxEnabled, Flag = "BoxESPEnabled", Callback = function(v) ESP.BoxEnabled = v end })
VisualsTab:CreateToggle({ Name = "Trazadores", CurrentValue = ESP.TracerEnabled, Flag = "TracerESPEnabled", Callback = function(v) ESP.TracerEnabled = v end })
VisualsTab:CreateSection("Personalización y Filtros")
VisualsTab:CreateColorpicker({ Name = "Color de Caja", Default = ESP.BoxColor, Flag = "BoxColor", Callback = function(c) ESP.BoxColor = c end })
VisualsTab:CreateColorpicker({ Name = "Color de Trazador", Default = ESP.TracerColor, Flag = "TracerColor", Callback = function(c) ESP.TracerColor = c end })

-- Pestaña de Configuración General
local SettingsTab = Window:CreateTab("Ajustes", "rbxassetid://4483345545")
SettingsTab:CreateLabel({ Name = "Configuración General de AVORN" })
SettingsTab:CreateToggle({ Name = "Ignorar Compañeros de Equipo", CurrentValue = Settings.IgnoreTeammates, Flag = "IgnoreTeammates", Callback = function(v) Settings.IgnoreTeammates = v; Console:Log("Ignorar equipo: " .. tostring(v)) end })
SettingsTab:CreateSection("Utilidades de la UI")
SettingsTab:CreateButton({ Name = "Limpiar todos los elementos visuales", Callback = function() for p,_ in pairs(ESP_Elements) do CleanUpPlayerESP(p) end; Console:Log("Elementos ESP limpiados manualmente.") end })
SettingsTab:CreateButton({ Name = "Recargar Configuración", Callback = function() Rayfield:LoadConfiguration(); Console:Log("Configuración recargada manualmente.") end })
SettingsTab:CreateButton({ Name = "Mostrar Estado Actual en Consola", Callback = function() Console:Log("--- ESTADO ACTUAL DE AVORN v0.4 ---"); Console:Log("Ignorar Equipo: " .. tostring(Settings.IgnoreTeammates)); Console:Log("Aimbot Activado: " .. tostring(Aimbot.Enabled)); Console:Log("Suavizado: " .. tostring(Aimbot.Smoothing)); Console:Log("FOV: " .. tostring(Aimbot.FOV)); Console:Log("ESP Activado: " .. tostring(ESP.Enabled)); Console:Log("-----------------------------") end })

Console:Log("UI creada y configurada.")
Rayfield:LoadConfiguration()
Console:Log("Configuración de usuario cargada. AVORN está listo.")
