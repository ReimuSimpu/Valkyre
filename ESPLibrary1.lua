-- Script made by ChatGPT
local DrawingESP = {}
DrawingESP.__index = DrawingESP

DrawingESP.Groups = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

--====================================================
-- CREATE ESP OBJECT
--====================================================

function DrawingESP:NewESP(part, name)
    local box = Drawing.new("Square")
    box.Filled = false
    box.Thickness = 1
    box.Visible = false

    local text = Drawing.new("Text")
    text.Size = 14
    text.Center = true
    text.Outline = true
    text.Font = Drawing.Fonts.Monospace
    text.Visible = false

    return {
        Part = part,
        Name = name or part.Name,
        Box = box,
        Text = text
    }
end

--====================================================
-- UPDATE LOOP
--====================================================

function DrawingESP:Update()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    for _, group in pairs(self.Groups) do
        local maxDist = group.MaxDistance or 200
        local color = group.Color or Color3.new(1,1,1)

        for i = #group.Objects, 1, -1 do
            local esp = group.Objects[i]
            local part = esp.Part

            if not part or not part.Parent then
                esp.Box:Remove()
                esp.Text:Remove()
                table.remove(group.Objects, i)
                continue
            end

            -- 🛑 FIX: ALWAYS hide if disabled
            if not group.Enabled then
                esp.Box.Visible = false
                esp.Text.Visible = false
                continue
            end

            local dist = (part.Position - root.Position).Magnitude
            if dist > maxDist then
                esp.Box.Visible = false
                esp.Text.Visible = false
                continue
            end

            local pos, onScreen = Camera:WorldToViewportPoint(part.Position)

            if not onScreen then
                esp.Box.Visible = false
                esp.Text.Visible = false
                continue
            end

            local size = math.clamp(300 / dist * 10, 25, 150)
            local boxPos = Vector2.new(pos.X - size/2, pos.Y - size/2)

            -- 📦 BOX
            if group.Box then
                esp.Box.Position = boxPos
                esp.Box.Size = Vector2.new(size, size)
                esp.Box.Color = color
                esp.Box.Visible = true
            else
                esp.Box.Visible = false
            end

            -- 📝 TEXT (name only)
            if group.Text then
                esp.Text.Text = esp.Name
                esp.Text.Position = Vector2.new(pos.X, boxPos.Y - 15)
                esp.Text.Color = color
                esp.Text.Visible = true
            else
                esp.Text.Visible = false
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    DrawingESP:Update()
end)

--====================================================
-- GROUP SYSTEM
--====================================================

function DrawingESP:CreateGroup(Name, Data)
    if DrawingESP.Groups[Name] then
        return DrawingESP.Groups[Name]
    end

    DrawingESP.Groups[Name] = {
        Objects = {},
        Enabled = Data.Enabled or false,
        Color = Data.Color or Color3.new(1,1,1),
        MaxDistance = Data.MaxDistance or 200,
        Box = true,
        Text = true
    }

    local Group = DrawingESP.Groups[Name]

    local function Add(part, name)
        if not part then return end
        table.insert(Group.Objects, DrawingESP:NewESP(part, name))
    end

    -- OBJECT ESP
    if Data.Container then
        for _,v in pairs(Data.Container:GetDescendants()) do
            if v:IsA("BasePart") then
                Add(v)
            end
        end

        Data.Container.DescendantAdded:Connect(function(v)
            if v:IsA("BasePart") then
                Add(v)
            end
        end)
    end

    -- PLAYER ESP
    if Data.IsPlayerESP then
        local function AddPlayer(plr)
            if plr == LocalPlayer then return end

            local function Setup(char)
                local root = char:WaitForChild("HumanoidRootPart", 5)
                if root then
                    Add(root, plr.Name)
                end
            end

            if plr.Character then
                Setup(plr.Character)
            end

            plr.CharacterAdded:Connect(Setup)
        end

        for _,p in pairs(Players:GetPlayers()) do
            AddPlayer(p)
        end

        Players.PlayerAdded:Connect(AddPlayer)
    end

    return Group
end

return DrawingESP
