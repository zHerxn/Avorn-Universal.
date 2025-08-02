--[[
    AVORN v2.0 - Lanzamiento de Estabilidad
    Desarrollador: yordy alias the strongest

    Esta versión representa un cambio de filosofía. Se han eliminado todas las funciones de API dudosas.
    AVORN 2.0 está construido para ser compatible y robusto, utilizando una consola simulada para los logs.
]]

--//=============================================================================================================\\
--||                                        [ 0. CONTROL DE EJECUCIÓN ]                                          ||
--\\=============================================================================================================//

if getgenv and typeof(getgenv) == "function" then
    local env = getgenv()
    if env.AVORN_RUNNING then
        warn("AVORN v2.0 ya se está ejecutando.")
        return
    end
    env.AVORN_RUNNING = true
    game:BindToClose(function() env.AVORN_RUNNING = false end)
end

--//=============================================================================================================\\
--||                                             [ 1. DEPENDENCIAS ]                                             ||
--\\=============================================================================================================//

local Rayfield
local success, result = pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not success then
    game.Players.LocalPlayer:Kick("AVORN: No se pudo cargar Rayfield: " .. tostring(result))
    return
end

--//=============================================================================================================\\
--||                                          [ 2. VARIABLES Y ESTADO ]                                          ||
--\\=============================================================================================================//

local Players, RunService, UserInputService, Workspace, TweenService = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService"), game:GetService("Workspace"), game:GetService("TweenService")
local LocalPlayer, Camera = Players.LocalPlayer, Workspace.CurrentCamera

-- Configuración
local Settings = { IgnoreTeammates = true, TargetVisibleOnly = true }
local Aimbot = { Enabled = false, Key = Enum.KeyCode.E, FOV = 100, ShowFOV = true, Smoothing = 0.2, Prediction = 0.1 }
local SilentAim = { Enabled = false, HitChance = 100 }
local Targeting = { TargetPart = "Head", CurrentTarget = nil }
local ESP = { Enabled = false, BoxEnabled = true, TracerEnabled = false, BoxColor = Color3.fromRGB(255, 49, 49), TracerColor = Color3.fromRGB(255, 184, 0), TargetLabelColor = Color3.fromRGB(255, 0, 0) }

-- Elementos Visuales y Estado
local FOV_Circle, TargetLabel = Drawing.new("Circle"), Drawing.new("Text")
local ESP_Elements, lastESP_Update, oldNamecall = {}, 0, nil
FOV_Circle.Visible, FOV_Circle.Radius, FOV_Circle.Color, FOV_Circle.Transparency = false, Aimbot.FOV, Color3.fromRGB(255, 255, 255), 1
TargetLabel.Visible, TargetLabel.Text, TargetLabel.Center, TargetLabel.Outline = false, "TARGET", true, true

--//=============================================================================================================\\
--||                                       [ 3. CONSTRUCCIÓN DE LA UI ]                                          ||
--\\=============================================================================================================//

local Window = Rayfield:CreateWindow({
    Name = "AVORN v2.0", LoadingTitle = "AVORN - ESTABLE", LoadingSubtitle = "por yordy alias the strongest",
    ConfigurationSaving = { Enabled = true, FolderName = "AVORN", FileName = "Config_v2" },
})

-- Pestaña de Ajustes (creada primero para alojar la consola)
local SettingsTab = Window:CreateTab("Ajustes", "rbxassetid://4483345545")

-- [CORREGIDO v2.0] Implementación de la consola simulada
local logText = "AVORN v2.0 inicializado."
local LogParagraph = SettingsTab:CreateParagraph({
    Title = "Consola de Logs",
    Content = logText
})

local function Log(message)
    print("[AVORN] " .. message) -- Imprime también a la consola F9 de Roblox para depuración
    logText = logText .. "\n" .. tostring(message)
    -- Limitar el número de líneas para no sobrecargar la UI
    local lines = {}
    for line in logText:gmatch("[^\r\n]+") do table.insert(lines, line) end
    while #lines > 20 do table.remove(lines, 1) end
    logText = table.concat(lines, "\n")
    LogParagraph:Set({ Content = logText })
end

-- El resto de la UI
Log("Construyendo UI...")

local CombatTab = Window:CreateTab("Combate", "rbxassetid://4483345998")
CombatTab:CreateLabel("Aimbot Legit (Mueve la cámara)")
CombatTab:CreateToggle({ Name = "Activar Aimbot Legit", Flag = "LegitAimbotEnabled", Callback = function(v) Aimbot.Enabled = v end })
CombatTab:CreateKeybind({ Name = "Tecla de Aimbot", Flag = "LegitAimbotKey", Callback = function(k) Aimbot.Key = k end })
CombatTab:CreateSlider({ Name = "Suavizado", Min = 0, Max = 0.95, Precision = 2, Flag = "LegitAimbotSmoothing", Callback = function(v) Aimbot.Smoothing = v end })

local SilentAimTab = Window:CreateTab("Silent Aim", "rbxassetid://6002424087")
SilentAimTab:CreateLabel("Silent Aim (No mueve la cámara)")
SilentAimTab:CreateToggle({ Name = "Activar Silent Aim", Flag = "SilentAimEnabled", Callback = function(v) SilentAim.Enabled = v end })
SilentAimTab:CreateSlider({ Name = "Probabilidad de Acierto (%)", Min = 1, Max = 100, Precision = 0, Flag = "SilentAimHitChance", Callback = function(v) SilentAim.HitChance = v end })

local TargetingTab = Window:CreateTab("Apuntado", "rbxassetid://6002452342")
TargetingTab:CreateLabel("Ajustes Universales de Apuntado")
TargetingTab:CreateDropdown({ Name = "Parte Objetivo", Options = {"Head", "UpperTorso", "HumanoidRootPart"}, Flag = "TargetingPart", Callback = function(o) Targeting.TargetPart = o end })
TargetingTab:CreateSlider({ Name = "Predicción", Min = 0, Max = 0.2, Precision = 3, Flag = "TargetingPrediction", Callback = function(v) Aimbot.Prediction = v end })
TargetingTab:CreateSection("Campo de Visión (FOV)")
TargetingTab:CreateToggle({ Name = "Mostrar Círculo FOV", Flag = "ShowFOV", Callback = function(v) Aimbot.ShowFOV = v; FOV_Circle.Visible = v end })
TargetingTab:CreateSlider({ Name = "Tamaño FOV", Min = 10, Max = 500, Precision = 0, Flag = "FOVSize", Callback = function(v) Aimbot.FOV = v; FOV_Circle.Radius = v end })

local VisualsTab = Window:CreateTab("Visuales", "rbxassetid://4483346342")
VisualsTab:CreateToggle({ Name = "Activar ESP", Flag = "ESPEnabled", Callback = function(v) ESP.Enabled = v end })
VisualsTab:CreateToggle({ Name = "Caja", Flag = "ESPBox", Callback = function(v) ESP.BoxEnabled = v end })
VisualsTab:CreateToggle({ Name = "Trazadores", Flag = "ESPTracer", Callback = function(v) ESP.TracerEnabled = v end })
VisualsTab:CreateColorpicker({ Name = "Color 'TARGET'", Flag = "TargetLabelColor", Callback = function(c) ESP.TargetLabelColor = c; TargetLabel.Color = c end })

-- Re-poblar la pestaña de Ajustes
SettingsTab:CreateToggle({ Name = "Ignorar Compañeros de Equipo", Flag = "IgnoreTeammates", Callback = function(v) Settings.IgnoreTeammates = v end })
SettingsTab:CreateToggle({ Name = "Solo Objetivos Visibles (Raycast)", Flag = "VisibleOnly", Callback = function(v) Settings.TargetVisibleOnly = v end })
SettingsTab:CreateButton({ Name = "Recargar Configuración", Callback = function() Rayfield:LoadConfiguration(); Log("Configuración recargada.") end })
SettingsTab:CreateButton({ Name = "Limpiar Log de Consola", Callback = function() logText = "Consola limpiada."; LogParagraph:Set({Content = logText}) end})

Log("UI construida correctamente.")

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

Log("Conectando eventos y hooks...")

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

--//=============================================================================================================\\
--||                                           [ 6. FINALIZACIÓN ]                                               ||
--\\=============================================================================================================//

Rayfield:LoadConfiguration()
Log("Configuración de usuario cargada. AVORN 2.0 está listo.")
