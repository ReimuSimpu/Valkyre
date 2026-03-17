-- DrawingESP Library v1.0
-- External library for creating performant ESP (Players/Objects) in Roblox
-- Credits https://github.com/Exunys/Exunys-ESP/blob/main/src/ESP.lua & ChatGPT for quick with slight modifactions by myself
local DrawingESP = {}
DrawingESP.__index = DrawingESP

DrawingESP.Groups = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

--====================================================
-- HELPERS
--====================================================

local function WorldToScreen(pos)
    local v, vis = Camera:WorldToViewportPoint(pos)
    return Vector2.new(v.X, v.Y), vis
end

local function IsVisible(origin, target, ignore)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = ignore
    params.FilterType = Enum.RaycastFilterType.Blacklist

    local result = workspace:Raycast(origin, (target - origin), params)
    return not result
end

local function GetCorners(pos, size)
    local x,y = pos.X, pos.Y
    local w,h = size.X, size.Y
    local s = 0.25

    return {
        {Vector2.new(x,y), Vector2.new(x+w*s,y)},
        {Vector2.new(x,y), Vector2.new(x,y+h*s)},

        {Vector2.new(x+w,y), Vector2.new(x+w-w*s,y)},
        {Vector2.new(x+w,y), Vector2.new(x+w,y+h*s)},

        {Vector2.new(x,y+h), Vector2.new(x+w*s,y+h)},
        {Vector2.new(x,y+h), Vector2.new(x,y+h-h*s)},

        {Vector2.new(x+w,y+h), Vector2.new(x+w-w*s,y+h)},
        {Vector2.new(x+w,y+h), Vector2.new(x+w,y+h-h*s)},
    }
end

--====================================================
-- NEW ESP OBJECT
--====================================================

function DrawingESP:NewESP(part, settings)
    settings = settings or {}

    local text = Drawing.new("Text")
    text.Size = 14
    text.Center = true
    text.Outline = true
    text.Font = Drawing.Fonts.Monospace

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1

    local healthBar = Drawing.new("Square")
    healthBar.Filled = true
    healthBar.Thickness = 0

    local healthOutline = Drawing.new("Square")
    healthOutline.Filled = false
    healthOutline.Thickness = 1
    healthOutline.Color = Color3.new(0,0,0)

    local humanoid = part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")

    return {
        Part = part,
        Text = text,
        Tracer = tracer,
        HealthBar = healthBar,
        HealthOutline = healthOutline,
        Humanoid = humanoid,
        Settings = settings,
        Cache = {}
    }
end

--====================================================
-- UPDATE LOOP
--====================================================

function DrawingESP:Update()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local viewport = Camera.ViewportSize
    local center = Vector2.new(viewport.X/2, viewport.Y/2)

    for _, group in pairs(self.Groups) do
        if not group.Enabled then continue end

        local maxDist = group.MaxDistance or group.Settings.MaxDistance
        local fov = group.FOV or 9999

        for i = #group.Objects, 1, -1 do
            local esp = group.Objects[i]
            local part = esp.Part

            if not part or not part.Parent then
                for _,v in pairs(esp) do
                    if typeof(v) == "userdata" and v.Remove then
                        v:Remove()
                    end
                end
                table.remove(group.Objects, i)
                continue
            end

            local dist = (part.Position - root.Position).Magnitude
            if dist > maxDist then goto hide end

            local pos, onScreen = WorldToScreen(part.Position)

            -- 🎯 FOV
            if (pos - center).Magnitude > fov then goto hide end

            -- 👁 visibility
            if group.VisibleCheck and not IsVisible(root.Position, part.Position, {char}) then
                goto hide
            end

            local size = math.clamp(300 / dist * 10, 30, 200)
            local boxPos = Vector2.new(pos.X - size/2, pos.Y - size/2)
            local color = group.Color or group.Settings.Color

            -- 📦 CORNER BOX
            if group.Box then
                local corners = GetCorners(boxPos, Vector2.new(size,size))
                for _,line in pairs(corners) do
                    local l = Drawing.new("Line")
                    l.From = line[1]
                    l.To = line[2]
                    l.Color = color
                    l.Thickness = 1
                    l.Visible = true
                    task.delay(0, function() l:Remove() end)
                end
            end

            -- 🦴 SKELETON (basic)
            if group.Skeleton and esp.Humanoid and part.Parent then
                local char = part.Parent
                local function draw(a,b)
                    local p1, v1 = WorldToScreen(a.Position)
                    local p2, v2 = WorldToScreen(b.Position)
                    if v1 and v2 then
                        local l = Drawing.new("Line")
                        l.From = p1
                        l.To = p2
                        l.Color = color
                        l.Thickness = 1
                        l.Visible = true
                        task.delay(0, function() l:Remove() end)
                    end
                end

                local head = char:FindFirstChild("Head")
                local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
                local hrp = char:FindFirstChild("HumanoidRootPart")

                if head and torso then draw(head, torso) end
                if torso and hrp then draw(torso, hrp) end
            end

            -- ❤️ HEALTH BAR
            if group.HealthBar and esp.Humanoid then
                local hp = esp.Humanoid.Health / esp.Humanoid.MaxHealth
                local barH = size * hp

                esp.HealthBar.Position = Vector2.new(boxPos.X - 6, boxPos.Y + (size - barH))
                esp.HealthBar.Size = Vector2.new(3, barH)
                esp.HealthBar.Color = Color3.fromRGB(255*(1-hp),255*hp,0)
                esp.HealthBar.Visible = true

                esp.HealthOutline.Position = Vector2.new(boxPos.X - 6, boxPos.Y)
                esp.HealthOutline.Size = Vector2.new(3, size)
                esp.HealthOutline.Visible = true
            else
                esp.HealthBar.Visible = false
                esp.HealthOutline.Visible = false
            end

            -- 📝 TEXT
            if group.Text then
                local t = esp.Settings.Name or part.Name

                if group.ShowDistance then
                    t = t .. (" [%d]"):format(dist)
                end

                esp.Text.Text = t
                esp.Text.Position = Vector2.new(pos.X, boxPos.Y - 15)
                esp.Text.Color = color
                esp.Text.Visible = true
            else
                esp.Text.Visible = false
            end

            -- 🔫 TRACER
            if group.Tracer then
                esp.Tracer.From = Vector2.new(center.X, viewport.Y)
                esp.Tracer.To = pos
                esp.Tracer.Color = color
                esp.Tracer.Visible = true
            else
                esp.Tracer.Visible = false
            end

            continue

            ::hide::
            esp.Text.Visible = false
            esp.Tracer.Visible = false
            esp.HealthBar.Visible = false
            esp.HealthOutline.Visible = false
        end
    end
end

RunService.RenderStepped:Connect(function()
    DrawingESP:Update()
end)

--====================================================
-- GROUP CREATION
--====================================================

function DrawingESP:CreateGroup(Name, Data)
    DrawingESP.Groups[Name] = {
        Objects = {},
        Enabled = Data.Enabled or false,

        Color = Data.Color,
        MaxDistance = Data.MaxDistance or 200,

        Box = true,
        Text = true,
        Tracer = false,
        Skeleton = false,
        HealthBar = false,

        ShowDistance = true,
        VisibleCheck = false,
        FOV = 9999,

        Settings = {
            Color = Data.Color or Color3.new(1,1,1),
            MaxDistance = Data.MaxDistance or 200
        }
    }

    local Group = DrawingESP.Groups[Name]

    local function Add(part, name)
        if not part then return end
        table.insert(Group.Objects, DrawingESP:NewESP(part,{
            Name = name or Name
        }))
    end

    if Data.Container then
        for _,v in pairs(Data.Container:GetDescendants()) do
            if v:IsA("BasePart") then Add(v) end
        end

        Data.Container.DescendantAdded:Connect(function(v)
            if v:IsA("BasePart") then Add(v) end
        end)
    end

    if Data.IsPlayerESP then
        local function AddPlayer(plr)
            if plr == LocalPlayer then return end

            plr.CharacterAdded:Connect(function(char)
                local root = char:WaitForChild("HumanoidRootPart",5)
                if root then Add(root, plr.Name) end
            end)

            if plr.Character then
                local root = plr.Character:FindFirstChild("HumanoidRootPart")
                if root then Add(root, plr.Name) end
            end
        end

        for _,p in pairs(Players:GetPlayers()) do
            AddPlayer(p)
        end

        Players.PlayerAdded:Connect(AddPlayer)
    end

    return Group
end

return DrawingESP
