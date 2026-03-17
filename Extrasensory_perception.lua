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

--[[ 
    Creates a new ESP object for a part
    @param part BasePart - The target part to ESP
    @param settings table - Optional configuration
        Name string - Name to display
        Color Color3 - Box color
        OutlineColor Color3 - Outline color
        TextColor Color3 - Text color
        MaxDistance number - Visibility distance
        ShowDistance boolean - Display distance
]]

function DrawingESP:NewESP(part, settings)
    settings = settings or {}

    local outline = Drawing.new("Square")
    outline.Thickness = 3
    outline.Filled = false
    outline.Transparency = 1
    outline.Color = settings.OutlineColor or Color3.new(0,0,0)

    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Transparency = 1
    box.Color = settings.Color or Color3.new(1,1,1)

    local text = Drawing.new("Text")
    text.Size = 14
    text.Center = true
    text.Outline = true
    text.Font = Drawing.Fonts.Monospace
    text.Color = settings.TextColor or Color3.new(1,1,1)
    text.Text = settings.Name or part.Name

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Transparency = 1
    tracer.Color = settings.Color or Color3.new(1,1,1)

    local humanoid = part.Parent and part.Parent:FindFirstChildOfClass("Humanoid")

    return {
        Part = part,
        Box = box,
        Outline = outline,
        Text = text,
        Tracer = tracer,
        Humanoid = humanoid,
        Settings = settings
    }
end

-- Updates all ESP objects
function DrawingESP:Update()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local viewport = Camera.ViewportSize

    for _, group in pairs(self.Groups) do
        if not group.Enabled then continue end

        local maxDist = group.MaxDistance or group.Settings.MaxDistance

        for i = #group.Objects, 1, -1 do
            local esp = group.Objects[i]
            local part = esp.Part

            if not part or not part.Parent then
                esp.Box:Remove()
                esp.Outline:Remove()
                esp.Text:Remove()
                esp.Tracer:Remove()
                table.remove(group.Objects, i)
                continue
            end

            local dist = (part.Position - root.Position).Magnitude

            if dist > maxDist then
                esp.Box.Visible = false
                esp.Outline.Visible = false
                esp.Text.Visible = false
                esp.Tracer.Visible = false
                continue
            end

            local pos, onScreen = Camera:WorldToViewportPoint(part.Position)

            -- clamp for offscreen
            local clamped = Vector2.new(
                math.clamp(pos.X, 0, viewport.X),
                math.clamp(pos.Y, 0, viewport.Y)
            )

            --================
            -- BOX + TEXT
            --================
            if onScreen then
                local size = math.clamp(300 / dist * 10, 30, 200)
                local boxPos = Vector2.new(pos.X - size/2, pos.Y - size/2)

                if group.Box ~= false then
                    esp.Box.Position = boxPos
                    esp.Box.Size = Vector2.new(size, size)
                    esp.Box.Color = group.Color or group.Settings.Color
                    esp.Box.Visible = true

                    esp.Outline.Position = boxPos
                    esp.Outline.Size = Vector2.new(size, size)
                    esp.Outline.Visible = true
                else
                    esp.Box.Visible = false
                    esp.Outline.Visible = false
                end

                if group.Text ~= false then
                    local textStr = esp.Settings.Name or part.Name

                    if group.ShowDistance or group.Settings.ShowDistance then
                        textStr = textStr .. (" [%d]"):format(dist)
                    end

                    -- health (players)
                    if group.ShowHealth and esp.Humanoid then
                        textStr = textStr .. (" | %d"):format(esp.Humanoid.Health)
                    end

                    esp.Text.Position = Vector2.new(pos.X, boxPos.Y - 15)
                    esp.Text.Text = textStr
                    esp.Text.Color = group.Color or group.Settings.Color
                    esp.Text.Visible = true
                else
                    esp.Text.Visible = false
                end
            else
                esp.Box.Visible = false
                esp.Outline.Visible = false
                esp.Text.Visible = false
            end

            --================
            -- TRACER (ALWAYS)
            --================
            if group.Tracer then
                esp.Tracer.From = Vector2.new(viewport.X/2, viewport.Y)
                esp.Tracer.To = clamped
                esp.Tracer.Color = group.Color or group.Settings.Color
                esp.Tracer.Visible = true
            else
                esp.Tracer.Visible = false
            end
        end
    end
end

RunService.RenderStepped:Connect(function() DrawingESP:Update() end)

--[[ 
    Creates a visual group
    @param Tab Fluent tab section
    @param Title string - Name of the ESP group
    @param Data table - Configuration
        Container Instance - Folder/Model for parts
        Color Color3 - Box color
        MaxDistance number - Distance
        IsPlayerESP boolean - ESP for players
        Enabled boolean - Default enabled state
]]

function DrawingESP:CreateGroup(Name, Data)
    DrawingESP.Groups[Name] = {
        Objects = {},
        Enabled = Data.Enabled or false,
        Box = true,
        Text = true,
        Settings = {
            Color = Data.Color or Color3.new(1,1,1),
            MaxDistance = Data.MaxDistance or 200,
            ShowDistance = true
        }
    }

    local Group = DrawingESP.Groups[Name]

    local function Add(part, name)
        if not part then return end
        table.insert(Group.Objects, DrawingESP:NewESP(part,{
            Name = name or Name,
            Color = Group.Settings.Color
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

--[[
Example Usage:

local ESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/yourname/DrawingESP/main/ESP.lua"))()
ESP:CreateVisual(Tabs.Visuals, "Players", {
    IsPlayerESP = true,
    Color = Color3.fromRGB(255,100,100),
    MaxDistance = 300,
    Enabled = true
})
ESP:CreateVisual(Tabs.Visuals, "Diamonds", {
    Container = workspace:FindFirstChild("CollectibleDiamonds"),
    Color = Color3.fromRGB(0,255,255),
    MaxDistance = 250,
    Enabled = true
})
]]
