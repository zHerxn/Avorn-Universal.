--[[
    AVORN v3.0 - El Manifiesto
    Desarrollador: yordy alias the strongest

    Reescrito desde cero basándose en la guía de la API de Rayfield proporcionada.
    Esta versión garantiza compatibilidad y estabilidad, eliminando todos los métodos "missing".
]]

--//=============================================================================================================\\
--||                                        [ 0. CONTROL DE EJECUCIÓN ]                                          ||
--\\=============================================================================================================//

if getgenv and typeof(getgenv) == "function" then
    local env = getgenv()
    if env.AVORN_RUNNING then
        warn("AVORN v3.0 ya se está ejecutando.")
        return
    end
    env.AVORN_RUNNING = true
    game:BindToClose(function() env.AVORN_RUNNING = false end)
end

--//=============================================================================================================\\
--||                                             [ 1. DEPENDENCIAS ]                                             ||
--\\=============================================================================================================//

local Rayfield
local success, libError = pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not success then
    game.Players.LocalPlayer:Kick("AVORN: Error crítico al cargar Rayfield: " .. tostring(libError))
    return
end

--//=============================================================================================================\\
--||                                          [ 2. VARIABLES Y ESTADO ]                                          ||
--\\=============================================================================================================//

local Players, RunService, UserInputService, Workspace, TweenService = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService"), game:GetService("Workspace"), game:GetService("TweenService")
local LocalPlayer, Camera = Players.LocalPlayer, Workspace.CurrentCamera

local Settings = { IgnoreTeammates = true, TargetVisibleOnly = true }
local Aimbot = { Enabled = false, Key = Enum.KeyCode.E, FOV = 100, ShowFOV = true, Smoothing = 0.2, Prediction = 0.1 }
local SilentAim = { Enabled = false, HitChance = 100 }
local Targeting = { TargetPart = "Head", CurrentTarget = nil }
local ESP = { Enabled = false, BoxEnabled = true, TracerEnabled = false, BoxColor = Color3.fromRGB(255, 49, 49), TracerColor = Color3.fromRGB(255, 184, 0), TargetLabelColor = Color3.fromRGB(255, 0, 0) }

local FOV_Circle, TargetLabel = Drawing.new("Circle"), Drawing.new("Text")
local ESP_Elements, oldNamecall = {}, nil
FOV_Circle.Visible, FOV_Circle.Radius, FOV_Circle.Color, FOV_Circle.Transparency = false, Aimbot.FOV, Color3.fromRGB(255, 255, 255), 1
TargetLabel.Visible, TargetLabel.Text, TargetLabel.Center, TargetLabel.Outline, TargetLabel.Color = false, "TARGET", true, true, ESP.TargetLabelColor

--//=============================================================================================================\\
--||                                       [ 3. CONSTRUCCIÓN DE LA UI ]                                          ||
--\\=============================================================================================================//

local Window = Rayfield:CreateWindow({
    Name = "AVORN v3.0", LoadingTitle = "AVORN - EL MANIFIESTO", LoadingSubtitle = "por yordy alias the strongest",
    ConfigurationSaving = { Enabled = true, FolderName = "AVORN", FileName = "Config_v3" },
})

-- Pestañas
local CombatTab = Window:CreateTab("Combate", 4483345998)
local SilentAimTab = Window:CreateTab("Silent Aim", 6002424087)
local TargetingTab = Window:CreateTab("Apuntado", 6002452342)
local VisualsTab = Window:CreateTab("Visuales", 4483346342)
local SettingsTab = Window:CreateTab("Ajustes", 4483345545)

-- Contenido de Pestaña Combate
CombatTab:CreateSection("Aimbot Legit (Mueve la cámara)")
CombatTab:CreateToggle({ Name = "Activar Aimbot Legit", CurrentValue = Aimbot.Enabled, Flag = "LegitAimbotEnabled", Callback = function(v) Aimbot.Enabled = v end })
CombatTab:CreateKeybind({ Name = "Tecla de Aimbot", CurrentKeybind = "E", Flag = "LegitAimbotKey", Callback = function(k) Aimbot.Key = k end })
CombatTab:CreateSlider({ Name = "Suavizado", Range = {0, 0.95}, CurrentValue = Aimbot.Smoothing, Increment = 0.01, Flag = "LegitAimbotSmoothing", Callback = function(v) Aimbot.Smoothing = v end })

-- Contenido de Pestaña Silent Aim
SilentAimTab:CreateSection("Silent Aim (No mueve la cámara)")
SilentAimTab:CreateToggle({ Name = "Activar Silent Aim", CurrentValue = SilentAim.Enabled, Flag = "SilentAimEnabled", Callback = function(v) SilentAim.Enabled = v end })
SilentAimTab:CreateSlider({ Name = "Probabilidad de Acierto", Range = {1, 100}, CurrentValue = SilentAim.HitChance, Suffix = "%", Increment = 1, Flag = "SilentAimHitChance", Callback = function(v) SilentAim.HitChance = v end })

-- Contenido de Pestaña Apuntado
TargetingTab:CreateSection("Ajustes Universales de Apuntado")
TargetingTab:CreateDropdown({ Name = "Parte Objetivo", Options = {"Head", "UpperTorso", "HumanoidRootPart"}, CurrentOption = {Targeting.TargetPart}, Flag = "TargetingPart", Callback = function(o) Targeting.TargetPart = o[1] end })
TargetingTab:CreateSlider({ Name = "Predicción", Range = {0, 0.2}, CurrentValue = Aimbot.Prediction, Increment = 0.001, Flag = "TargetingPrediction", Callback = function(v) Aimbot.Prediction = v end })
TargetingTab:CreateSection("Campo de Visión (FOV)")
TargetingTab:CreateToggle({ Name = "Mostrar Círculo FOV", CurrentValue = Aimbot.ShowFOV, Flag = "ShowFOV", Callback = function(v) Aimbot.ShowFOV = v; FOV_Circle.Visible = v end })
TargetingTab:CreateSlider({ Name = "Tamaño FOV", Range = {10, 500}, CurrentValue = Aimbot.FOV, Increment = 1, Flag = "FOVSize", Callback = function(v) Aimbot.FOV = v; FOV_Circle.Radius = v end })

-- Contenido de Pestaña Visuales
VisualsTab:CreateSection("Configuración de ESP")
VisualsTab:CreateToggle({ Name = "Activar ESP", CurrentValue = ESP.Enabled, Flag = "ESPEnabled", Callback = function(v) ESP.Enabled = v end })
VisualsTab:CreateToggle({ Name = "Caja", CurrentValue = ESP.BoxEnabled, Flag = "ESPBox", Callback = function(v) ESP.BoxEnabled = v end })
VisualsTab:CreateToggle({ Name = "Trazadores", CurrentValue = ESP.TracerEnabled, Flag = "ESPTracer", Callback = function(v) ESP.TracerEnabled = v end })
VisualsTab:CreateSection("Colores")
VisualsTab:CreateColorPicker({ Name = "Color 'TARGET'", Color = ESP.TargetLabelColor, Flag = "TargetLabelColor", Callback = function(c) ESP.TargetLabelColor = c; TargetLabel.Color = c end })
VisualsTab:CreateColorPicker({ Name = "Color de Caja", Color = ESP.BoxColor, Flag = "BoxColorESP", Callback = function(c) ESP.BoxColor = c end })
VisualsTab:CreateColorPicker({ Name = "Color de Trazador", Color = ESP.TracerColor, Flag = "TracerColorESP", Callback = function(c) ESP.TracerColor = c end })

-- Contenido de Pestaña Ajustes
SettingsTab:CreateSection("Filtros Globales")
SettingsTab:CreateToggle({ Name = "Ignorar Compañeros de Equipo", CurrentValue = Settings.IgnoreTeammates, Flag = "IgnoreTeammates", Callback = function(v) Settings.IgnoreTeammates = v end })
SettingsTab:CreateToggle({ Name = "Solo Objetivos Visibles (Raycast)", CurrentValue = Settings.TargetVisibleOnly, Flag = "VisibleOnly", Callback = function(v) Settings.TargetVisibleOnly = v end })
SettingsTab:CreateSection("Utilidades")
SettingsTab:CreateButton({ Name = "Recargar Configuración", Callback = function() Rayfield:LoadConfiguration(); Rayfield:Notify({Title="AVORN", Content="Configuración recargada."}) end })

--//=============================================================================================================\\
--||                                           [ 4. LÓGICA Y FUNCIONES ]                                         ||
--\\=============================================================================================================//

function isPlayerVisible(player)
    if not player or not player.Character or not player.Character:FindFirstChild(Targeting.TargetPart) then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character, player.Character}
    local origin = Camera.CFrame.Position
    local result = Workspace:Raycast(origin, player.Character[Targeting.TargetPart].Position - origin, params)
    return not result
end

function getClosestPlayer()
    local closestPlayer, minDistance = nil, Aimbot.FOV
    if not Camera then return nil end
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(Targeting.TargetPart) and player.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            if not Settings.IgnoreTeammates or not player.Team or player.Team ~= LocalPlayer.Team then
                if not Settings.TargetVisibleOnly or isPlayerVisible(player) then
                    local screenPos, onScreen = Camera:WorldToScreenPoint(player.Character[Targeting.TargetPart].Position)
                    if onScreen then
                        local distance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        if distance < minDistance then closestPlayer, minDistance = player, distance end
                    end
                end
            end
        end
    end
    return closestPlayer
end

--//=============================================================================================================\\
--||                                        [ 5. HOOKS Y EVENTOS ]                                               ||
--\\=============================================================================================================//

RunService.RenderStepped:Connect(function(dt)
    if not Camera or not Camera.Parent then Camera = Workspace.CurrentCamera; return end
    Targeting.CurrentTarget = getClosestPlayer()
    if Aimbot.Enabled and UserInputService:IsKeyDown(Aimbot.Key) and Targeting.CurrentTarget then
        local targetPart = Targeting.CurrentTarget.Character[Targeting.TargetPart]
        local predictedPos = targetPart.Position + (targetPart.AssemblyLinearVelocity * Aimbot.Prediction)
        Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, predictedPos), (1 - Aimbot.Smoothing) * dt * 60)
    end
    TargetLabel.Visible = Targeting.CurrentTarget and true or false
    if TargetLabel.Visible then
        local screenPos, onScreen = Camera:WorldToScreenPoint(Targeting.CurrentTarget.Character[Targeting.TargetPart].Position)
        TargetLabel.Position, TargetLabel.Visible = Vector2.new(screenPos.X, screenPos.Y - 30), onScreen
    end
    if Aimbot.ShowFOV then FOV_Circle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2) end
end)

if hookmetamethod then
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        if self == Workspace and method == "FindPartOnRayWithWhitelist" and SilentAim.Enabled and Targeting.CurrentTarget then
            if math.random(1, 100) <= SilentAim.HitChance then
                local ray = args[1]
                local targetPart = Targeting.CurrentTarget.Character[Targeting.TargetPart]
                local predictedPos = targetPart.Position + (targetPart.AssemblyLinearVelocity * Aimbot.Prediction)
                args[1] = Ray.new(ray.Origin, (predictedPos - ray.Origin).Unit * 1000)
                return oldNamecall(self, unpack(args))
            end
        end
        return oldNamecall(self, unpack(args))
    end)
else
    Rayfield:Notify({Title="AVORN Error", Content="Tu exploit no soporta hookmetamethod. Silent Aim desactivado.", Duration = 10})
end

--//=============================================================================================================\\
--||                                           [ 6. FINALIZACIÓN ]                                               ||
--\\=============================================================================================================//

Rayfield:LoadConfiguration()
Rayfield:Notify({Title="AVORN 3.0", Content="Script cargado y listo. Creado por yordy alias the strongest.", Duration = 7})
