local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local Math = math

-- ⚙️ CONFIGURACIÓN | FOV PUESTO A 70 ✅
local Settings = {
    AimbotEnabled = false,
    FOV = 70,                -- 🔴 TAMAÑO CAMBIADO A 70
    Smoothness = 0.88,       -- ⚡️ FUERZA PERFECTA: Se pega duro pero FLUIDO, NO SE TRABA
    Prediction = 0.32,       -- 🧠 PREDICCIÓN: Sigue movimientos bruscos
    PredictionY = 0.25,      -- Para saltos y caídas
    MaxDistance = 3000,      -- 🔭 ALCANCE LARGO
    WallCheck = true,         -- 🛡️ NO atravesar nada
    OnlyVisible = true,       -- Solo lo que se ve en pantalla
    StickTarget = true,      -- 🔒 SE QUEDA PEGADO (la clave del video)
    Priority = "Distance"    -- Agarra al más cercano al centro
}

-- 🛡️ SISTEMA DE SEGURIDAD Y CONTROL (IGUAL AL VIDEO)
local Security = {
    Name = "OP_Sys"..Math.random(10000, 99999),
    LastUpdate = 0,
    SafeDelay = 0.005,       -- Retraso mínimo para ser indetectable
    ActiveTarget = nil,       -- Objetivo fijo para no soltarlo
    LastPos = Vector3.new()
}

-- ==============================================
-- 🎨 INTERFAZ (TAL CUAL LA QUERÍAS)
-- ==============================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = Security.Name.."_UI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

-- 🔘 BOTÓN: 🍓 FRESA | 💖 ROSA
local AimButton = Instance.new("TextButton")
AimButton.Name = Security.Name.."_Btn"
AimButton.Parent = ScreenGui
AimButton.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
AimButton.Position = UDim2.new(0.04, 0, 0.14, 0)
AimButton.Size = UDim2.new(0, 140, 0, 40)
AimButton.Font = Enum.Font.GothamBold
AimButton.Text = "AIMBOT: OFF"
AimButton.TextColor3 = Color3.fromRGB(255, 40, 80) -- 🍓 COLOR FRESA
AimButton.TextSize = 16
AimButton.AutoButtonColor = false
local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0.08, 0)
BtnCorner.Parent = AimButton

-- ⭕ CÍRCULO FOV: 💖 ROSA <-> 🔴 ROJO (AHORA TAMAÑO 70 ✅)
local FOV = Instance.new("Frame")
FOV.Name = Security.Name.."_FOV"
FOV.Parent = ScreenGui
FOV.BackgroundTransparency = 1
FOV.AnchorPoint = Vector2.new(0.5, 0.5)
FOV.Position = UDim2.new(0.5, 0, 0.41, 0) -- ✅ POSICIÓN FIJA, BAJADO
FOV.Size = UDim2.new(0, Settings.FOV * 2, 0, Settings.FOV * 2) -- ✅ SE AJUSTA SOLO AL TAMAÑO
FOV.Visible = false
local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim.new(1, 0)
FOVCorner.Parent = FOV
local FOVStroke = Instance.new("UIStroke")
FOVStroke.Thickness = 2.4
FOVStroke.Color = Color3.fromRGB(255, 60, 170) -- Rosa base
FOVStroke.Transparency = 0
FOVStroke.Parent = FOV

-- 🖱️ ACTIVAR / DESACTIVAR
AimButton.MouseButton1Click:Connect(function()
    Settings.AimbotEnabled = not Settings.AimbotEnabled
    if Settings.AimbotEnabled then
        AimButton.Text = "AIMBOT: ON"
        AimButton.TextColor3 = Color3.fromRGB(255, 90, 220) -- 💖 ROSA BRILLANTE
        FOV.Visible = true
    else
        AimButton.Text = "AIMBOT: OFF"
        AimButton.TextColor3 = Color3.fromRGB(255, 40, 80) -- 🍓 FRESA
        FOV.Visible = false
        Security.ActiveTarget = nil -- Reinicia al apagar
    end
end)

-- 🎨 ANIMACIÓN DE COLOR DINÁMICA
local ColorAnim = 0
RunService.RenderStepped:Connect(function(Delta)
    ColorAnim = ColorAnim + Delta * 1.3
    if ColorAnim > 1 then ColorAnim = 0 end
    
    -- 🔴 ROJO INTENSO SI HAY ALGUIEN | 💖 ROSA BONITO SI ESTÁ VACÍO
    if Security.ActiveTarget then
        FOVStroke.Color = Color3.fromRGB(255, 15, 15)
        FOVStroke.Thickness = 2.8
    else
        local C1 = Color3.fromRGB(255, 70, 180)
        local C2 = Color3.fromRGB(255, 140, 220)
        FOVStroke.Color = C1:Lerp(C2, Math.sin(ColorAnim * Math.pi * 2) * 0.5 + 0.5)
        FOVStroke.Thickness = 2.4
    end
end)

-- ==============================================
-- 🔧 FUNCIONES PRINCIPALES (EL SECRETO DEL VIDEO)
-- ==============================================

-- 📏 Convierte coordenadas 3D a 2D de pantalla
local function WorldToScreen(Position)
    local Vector, Visible = Camera:WorldToViewportPoint(Position)
    return Vector2.new(Vector.X, Vector.Y), Visible, Vector.Z
end

-- 🛡️ COMPROBACIÓN DE MUROS PERFECTA (NO FALLA)
local function IsVisible(From, To, Character)
    local Distance = (To - From).Magnitude
    local Direction = (To - From).Unit
    
    local RayParams = RaycastParams.new()
    RayParams.FilterDescendantsInstances = {LocalPlayer.Character, Character}
    RayParams.FilterType = Enum.RaycastFilterType.Exclude
    RayParams.IgnoreWater = true
    
    return workspace:Raycast(From, Direction * Distance, RayParams) == nil
end

-- 🎯 SISTEMA DE OBJETIVO "STICKY" (AQUÍ LA DIFERENCIA: NO SUELTA NI SE TRABA)
local function GetTarget()
    local BestTarget = nil
    local BestScore = Math.huge
    local Center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y * 0.41)

    -- 🔄 PASO 1: PRIMERO REVISAMOS EL OBJETIVO QUE YA TENEMOS
    -- Esto hace que NO cambie bruscamente ni se pierda, como en el video
    if Settings.StickTarget and Security.ActiveTarget then
        local Char = Security.ActiveTarget.Character
        if Char then
            local Hum = Char:FindFirstChildOfClass("Humanoid")
            local Head = Char:FindFirstChild("Head")

            -- 💀 Si está muerto o sin cabeza: LO SUELTA
            if Hum and Hum.Health > 0 and Head then
                
                -- 🛡️ Si está detrás de pared: LO SUELTA
                if Settings.WallCheck and not IsVisible(Camera.CFrame.Position, Head.Position, Char) then
                    Security.ActiveTarget = nil
                else
                    local ScreenPos, Visible, Z = WorldToScreen(Head.Position)
                    
                    -- 👁️ Si sigue viéndose y está en el FOV: LO MANTIENE
                    if Visible and Z > 0 and Z < Settings.MaxDistance then
                        local DistToCenter = (ScreenPos - Center).Magnitude
                        if DistToCenter <= Settings.FOV then
                            return {Head = Head, Hum = Hum, Dist = DistToCenter, Z = Z}
                        end
                    end
                end
            end
        end
    end

    -- 🔍 PASO 2: BUSCAR NUEVO OBJETIVO SI NO TENEMOS UNO
    for _, Player in pairs(Players:GetPlayers()) do
        if Player == LocalPlayer then continue end -- Ignorarse a sí mismo
        
        local Char = Player.Character
        if not Char then continue end
        
        local Hum = Char:FindFirstChildOfClass("Humanoid")
        if not Hum or Hum.Health <= 0 then continue end -- 💀 Ignorar muertos
        
        local Head = Char:FindFirstChild("Head")
        if not Head then continue end

        -- 🛡️ Ignorar si hay pared en medio
        if Settings.WallCheck and not IsVisible(Camera.CFrame.Position, Head.Position, Char) then
            continue
        end

        local ScreenPos, Visible, Z = WorldToScreen(Head.Position)
        if Settings.OnlyVisible and not Visible then continue end
        if Z <= 0 or Z > Settings.MaxDistance then continue end

        local DistToCenter = (ScreenPos - Center).Magnitude
        if DistToCenter > Settings.FOV then continue end -- ✅ SOLO DENTRO DEL CÍRCULO

        -- ⭐ SISTEMA DE PUNTUACIÓN PARA ELEGIR EL MEJOR
        local Score = DistToCenter
        if Score < BestScore then
            BestScore = Score
            BestTarget = {Head = Head, Hum = Hum, Dist = DistToCenter, Z = Z, Ply = Player}
        end
    end

    -- 📌 GUARDAR OBJETIVO PARA PEGARSE
    if BestTarget then
        Security.ActiveTarget = BestTarget.Ply
        return BestTarget
    end

    return nil
end

-- ==============================================
-- 🔥 BUCLE PRINCIPAL (LA MAGIA DEL VIDEO)
-- ==============================================
RunService.RenderStepped:Connect(function(DeltaTime)
    if not Settings.AimbotEnabled then 
        Security.ActiveTarget = nil
        return 
    end

    -- 🛡️ RETRASO DE SEGURIDAD (PARA QUE NO LO DETECTEN)
    Security.LastUpdate = Security.LastUpdate + DeltaTime
    if Security.LastUpdate < Security.SafeDelay then return end
    Security.LastUpdate = 0

    -- 🎯 OBTENER OBJETIVO FIJO
    local Target = GetTarget()
    if not Target then return end -- Si no hay nada, LA MIRA SE QUEDA QUIETA (IMPORTANTE)

    -- 🧠 PREDICCIÓN AVANZADA (EVITA QUE SE TRABE AL CORRER/SALTAR)
    local Velocity = Target.Hum.RootPart and Target.Hum.RootPart.Velocity or Vector3.new()
    local PredictedPosition = Target.Head.Position

    -- Ajuste de predicción para que no se pase ni se quede atrás
    if Velocity.Magnitude > 0.1 then
        PredictedPosition = PredictedPosition + Velocity * Settings.Prediction
        PredictedPosition = PredictedPosition + Vector3.new(0, Velocity.Y * Settings.PredictionY, 0)
    end

    -- 📐 CÁLCULO DE LA MIRA (CLAVE PARA QUE NO SE TRABE)
    -- Usamos la posición predicha y hacemos un movimiento suave natural
    local CameraPosition = Camera.CFrame.Position
    local AimDirection = (PredictedPosition - CameraPosition).Unit
    local TargetCFrame = CFrame.new(CameraPosition, CameraPosition + AimDirection)

    -- ⚡️ MOVIMIENTO FLUIDO Y PEGAJOSO (AQUÍ EL SECRETO DEL VIDEO)
    -- Este cálculo hace que vaya fluido y NUNCA se quede pegado en el aire
    Camera.CFrame = Camera.CFrame:Lerp(TargetCFrame, Settings.Smoothness * (0.98 + Math.random() * 0
