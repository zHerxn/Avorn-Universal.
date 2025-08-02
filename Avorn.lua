--[[
    AVORN v1.0 - Lanzamiento Oficial
    Desarrollador: yordy alias the strongest

    Bienvenido a la re-entrada. La fase beta ha terminado.
    Esta versión introduce un Silent Aim funcional, predicción de movimiento, y un núcleo más robusto.
]]

--//=============================================================================================================\\
--||                                        [ 0. CONTROL DE EJECUCIÓN ]                                          ||
--\\=============================================================================================================//

if getgenv and typeof(getgenv) == "function" then
    local env = getgenv()
    if env.AVORN_RUNNING then
        warn("AVORN v1.0 ya se está ejecutando. Se detendrá esta instancia.")
        return
    else
        env.AVORN_RUNNING = true
        game:BindToClose(function()
            env.AVORN_RUNNING = false -- Limpiar al salir
        end)
    end
end

--//=============================================================================================================\\
--||                                             [ 1. DEPENDENCIAS ]                                             ||
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
--||                                          [ 2. VARIABLES Y ESTADO ]                                          ||
--\\=============================================================================================================//

local Players, RunService, UserInputService, Workspace, TweenService = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService"), game:GetService("Workspace"), game:GetService("TweenService")
local LocalPlayer, Camera = Players.LocalPlayer, Workspace.CurrentCamera

-- Configuración General
local Settings = { IgnoreTeammates = true, TargetVisibleOnly = true }

-- Aimbot (Legit)
local Aimbot = { Enabled = false, Key = Enum.KeyCode.E, FOV = 100, ShowFOV = true, Smoothing = 0.2, Prediction = 0.1 }

-- Silent Aim
local SilentAim = { Enabled = false, HitChance = 100 }

-- Universal Targeting
local Targeting = { TargetPart = "Head", CurrentTarget = nil }

-- ESP
local ESP = { Enabled = false, BoxEnabled = true, TracerEnabled = false, BoxColor = Color3.fromRGB(255, 49, 49), TracerColor = Color3.fromRGB(255, 184, 0), TargetLabelColor = Color3.fromRGB(255, 0, 0) }

-- Elementos Visuales
local FOV_Circle, TargetLabel = Drawing.new("Circle"), Drawing.new("Text")
FOV_Circle.Visible, FOV_Circle.Radius, FOV_Circle.Color, FOV_Circle.Transparency = false, Aimbot.FOV, Color3.fromRGB(255, 255, 255), 1
TargetLabel.Visible, TargetLabel.Text, TargetLabel.Center, TargetLabel.Outline = false, "TARGET", true, true

-- Estado Interno
local ESP_Elements, lastESP_Update, ESP_Update_Interval = {}, 0, 0.1
local oldNamecall

--//=============================================================================================================\\
--||                                       [ 3. CONSTRUCCIÓN DE LA UI ]                                          ||
--\\=============================================================================================================//

local Window = Rayfield:CreateWindow({
    Name = "AVORN v1.0", LoadingTitle = "AVORN - REENTRADA", LoadingSubtitle = "por yordy alias the strongest",
    ConfigurationSaving = { Enabled = true, FolderName = "AVORN", FileName = "Config_v1" },
})

-- Intento seguro de crear Splash
local splashSuccess, splashErr = pcall(function()
    Window:CreateSplash({
        Name = "AVORN 1.0", SubName = "Re-entrada completa.", Color = Color3.fromRGB(255, 49, 49),
        SubColor = Color3.fromRGB(255, 184, 0), BG = Color3.fromRGB(13, 13, 13), Font = Enum.Font.SourceSans,
    })
end)

local Console = Window:CreateConsole({ Name = "Consola" })
if not splashSuccess then Console:Log("WARN: No se pudo crear el splash: " .. tostring(splashErr)) end

Console:Log("AVORN v1.0 Inicializado.")

-- Pestaña Combate (Aimbot Legit)
local CombatTab = Window:CreateTab("Combate", "rbxassetid://4483345998")
CombatTab:CreateLabel("Aimbot Legit (Mueve la cámara)")
CombatTab:CreateToggle({ Name = "Activar Aimbot Legit", Flag = "LegitAimbotEnabled", Callback = function(v) Aimbot.Enabled = v end })
CombatTab:CreateKeybind({ Name = "Tecla de Aimbot", Flag = "LegitAimbotKey", Callback = function(k) Aimbot.Key = k end })
CombatTab:CreateSlider({ Name = "Suavizado", Min = 0, Max = 0.95, Precision = 2, Flag = "LegitAimbotSmoothing", Callback = function(v) Aimbot.Smoothing = v end })

-- Pestaña Silent Aim
local SilentAimTab = Window:CreateTab("Silent Aim", "rbxassetid://6002424087")
SilentAimTab:CreateLabel("Silent Aim (No mueve la cámara)")
SilentAimTab:CreateToggle({ Name = "Activar Silent Aim", Flag = "SilentAimEnabled", Callback = function(v) SilentAim.Enabled = v end })
SilentAimTab:CreateSlider({ Name = "Probabilidad de Acierto (%)", Min = 1, Max = 100, Precision = 0, Flag = "SilentAimHitChance", Callback = function(v) SilentAim.HitChance = v end })

-- Pestaña Ajustes de Apuntado (Universal)
local TargetingTab = Window:CreateTab("Apuntado", "rbxassetid://6002452342")
TargetingTab:CreateLabel("Ajustes para Aimbot y Silent Aim")
TargetingTab:CreateDropdown({ Name = "Parte del Cuerpo Objetivo", Options = {"Head", "UpperTorso", "HumanoidRootPart"}, Flag = "TargetingPart", Callback = function(o) Targeting.TargetPart = o end })
TargetingTab:CreateSlider({ Name = "Predicción de Movimiento", Min = 0, Max = 0.2, Precision = 3, Flag = "TargetingPrediction", Callback = function(v) Aimbot.Prediction = v end })
TargetingTab:CreateSection("Campo de Visión (FOV)")
TargetingTab:CreateToggle({ Name = "Mostrar Círculo de FOV", Flag = "ShowFOV", Callback = function(v) Aimbot.ShowFOV = v; FOV_Circle.Visible = v end })
TargetingTab:CreateSlider({ Name = "Tamaño de FOV", Min = 10, Max = 500, Precision = 0, Flag = "FOVSize", Callback = function(v) Aimbot.FOV = v; FOV_Circle.Radius = v end })

-- Pestaña de Visuales
local VisualsTab = Window:CreateTab("Visuales", "rbxassetid://4483346342")
VisualsTab:CreateToggle({ Name = "Activar ESP", Flag = "ESPEnabled", Callback = function(v) ESP.Enabled = v end })
VisualsTab:CreateSection("Componentes")
VisualsTab:CreateToggle({ Name = "Caja", Flag = "ESPBox", Callback = function(v) ESP.BoxEnabled = v end })
VisualsTab:CreateToggle({ Name = "Trazadores", Flag = "ESPTracer", Callback = function(v) ESP.TracerEnabled = v end })
VisualsTab:CreateColorpicker({ Name = "Color Indicador 'TARGET'", Flag = "TargetLabelColor", Callback = function(c) ESP.TargetLabelColor = c; TargetLabel.Color = c end })


-- Pestaña de Configuración
local SettingsTab = Window:CreateTab("Ajustes", "rbxassetid://4483345545")
SettingsTab:CreateToggle({ Name = "Ignorar Compañeros de Equipo", Flag = "IgnoreTeammates", Callback = function(v) Settings.IgnoreTeammates = v end })
SettingsTab:CreateToggle({ Name = "Solo Objetivos Visibles", Flag = "VisibleOnly", Callback = function(v) Settings.TargetVisibleOnly = v end })
SettingsTab:CreateButton({ Name = "Recargar Configuración", Callback = function() Rayfield:LoadConfiguration(); Console:Log("Configuración recargada.") end })

Console:Log("UI construida.")

--//=============================================================================================================\\
--||                                           [ 4. LÓGICA Y FUNCIONES ]                                         ||
--\\=============================================================================================================//

local function isPlayerVisible(player)
    if not player.Character or not player.Character:FindFirstChild(Targeting.TargetPart) then return false end
    
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character, player.Character}
    
    local origin = Camera.CFrame.Position
    local targetPos = player.Character[Targeting.TargetPart].Position
    local result = Workspace:Raycast(origin, targetPos - origin, params)
    
    return not result
end

local function getClosestPlayer()
    local closestPlayer, minDistance = nil, Aimbot.FOV
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(Targeting.TargetPart) and player.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            if Settings.IgnoreTeammates and player.Team and player.Team == LocalPlayer.Team then continue end
            if Settings.TargetVisibleOnly and not isPlayerVisible(player) then continue end

            local targetPart = player.Character:FindFirstChild(Targeting.TargetPart)
            if targetPart then
                local screenPos, onScreen = Camera:WorldToScreenPoint(targetPart.Position)
                if onScreen then
                    local distance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if distance < minDistance then
                        closestPlayer, minDistance = player, distance
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

-- Bucle de renderizado para Aimbot Legit y Visuales
RunService.RenderStepped:Connect(function(dt)
    if not Camera or not Camera.Parent then Camera = Workspace.CurrentCamera; return end

    Targeting.CurrentTarget = getClosestPlayer()

    -- Aimbot Legit
    if Aimbot.Enabled and UserInputService:IsKeyDown(Aimbot.Key) and Targeting.CurrentTarget then
        local targetPart = Targeting.CurrentTarget.Character[Targeting.TargetPart]
        local predictedPos = targetPart.Position + (targetPart.AssemblyLinearVelocity * Aimbot.Prediction)
        local targetCFrame = CFrame.new(Camera.CFrame.Position, predictedPos)
        local smoothFactor = 1 - math.clamp(Aimbot.Smoothing, 0.01, 0.99)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothFactor * dt * 60)
    end
    
    -- Visuales
    TargetLabel.Visible = Targeting.CurrentTarget ~= nil
    if Targeting.CurrentTarget then
        local targetPos = Targeting.CurrentTarget.Character[Targeting.TargetPart].Position
        local screenPos, onScreen = Camera:WorldToScreenPoint(targetPos)
        if onScreen then
            TargetLabel.Position = Vector2.new(screenPos.X, screenPos.Y - 30)
        else
            TargetLabel.Visible = false
        end
    end

    if Aimbot.ShowFOV then FOV_Circle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2) end
end)

-- Hook para Silent Aim
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if self == Workspace and method == "FindPartOnRayWithWhitelist" and SilentAim.Enabled then
        if math.random(1, 100) <= SilentAim.HitChance and Targeting.CurrentTarget then
            local ray = args[1]
            local targetPart = Targeting.CurrentTarget.Character[Targeting.TargetPart]
            local predictedPos = targetPart.Position + (targetPart.AssemblyLinearVelocity * Aimbot.Prediction)
            local direction = (predictedPos - ray.Origin).Unit
            
            args[1] = Ray.new(ray.Origin, direction * 1000)
            return oldNamecall(self, unpack(args))
        end
    end
    return oldNamecall(self, unpack(args))
end)

--//=============================================================================================================\\
--||                                           [ 6. FINALIZACIÓN ]                                               ||
--\\=============================================================================================================//

Rayfield:LoadConfiguration()
Console:Log("Configuración cargada. AVORN 1.0 está listo.")
