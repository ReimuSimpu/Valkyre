local DrawingESP = {}
DrawingESP.__index = DrawingESP

DrawingESP.Groups = {}
DrawingESP._globalParts = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
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
    local Camera = workspace.CurrentCamera
    if not Camera then return end

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
                pcall(function() esp.Box:Remove() end)
                pcall(function() esp.Text:Remove() end)

                group._addedParts[part] = nil
                DrawingESP._globalParts[part] = nil

                table.remove(group.Objects, i)
                continue
            end

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

            local size = math.clamp(300 / math.max(dist, 5) * 10, 25, 150)
            local boxPos = Vector2.new(pos.X - size/2, pos.Y - size/2)

            -- BOX
            if group.Box then
                esp.Box.Position = boxPos
                esp.Box.Size = Vector2.new(size, size)
                esp.Box.Color = color
                esp.Box.Visible = true
            else
                esp.Box.Visible = false
            end

            -- TEXT
            if group.Text then
                local distText = string.format("%.1f", dist)
                esp.Text.Text = esp.Name .. " [" .. distText .. "m]"
                esp.Text.Position = Vector2.new(pos.X, boxPos.Y - 15)
                esp.Text.Color = color
                esp.Text.Visible = true
            else
                esp.Text.Visible = false
            end
        end
    end
end

-- Throttle for performance
do
    local Accum = 0
    RunService.RenderStepped:Connect(function(dt)
        Accum += dt
        if Accum < 0.03 then return end
        Accum = 0

        DrawingESP:Update()
    end)
end

--====================================================
-- GROUP SYSTEM
--====================================================

function DrawingESP:CreateGroup(Name, Data)
    if DrawingESP.Groups[Name] then
        return DrawingESP.Groups[Name]
    end

    local Group = {
        Objects = {},
        Enabled = Data.Enabled or false,
        Color = Data.Color or Color3.new(1,1,1),
        MaxDistance = Data.MaxDistance or 200,
        Box = true,
        Text = true,
        _addedParts = {}
    }

    DrawingESP.Groups[Name] = Group

    local function Add(part, name)
        if not part then return end
        if DrawingESP._globalParts[part] then return end

        table.insert(Group.Objects, DrawingESP:NewESP(part, name))
        Group._addedParts[part] = true
        DrawingESP._globalParts[part] = true
    end

    --====================================================
    -- OBJECT ESP (FIXED)
    --====================================================

    if Data.Container then
        local function Handle(v)
            if not v:IsA("BasePart") then return end

            local model = v:FindFirstAncestorOfClass("Model")

            -- ❌ Ignore player characters / humanoids
            if model and model:FindFirstChildOfClass("Humanoid") then
                return
            end

            -- ✅ If model has PrimaryPart, only track that
            if model and model.PrimaryPart then
                Add(model.PrimaryPart, model.Name)
            else
                Add(v, v.Name)
            end
        end

        for _,v in pairs(Data.Container:GetDescendants()) do
            Handle(v)
        end

        Data.Container.DescendantAdded:Connect(Handle)
    end

    --====================================================
    -- PLAYER ESP
    --====================================================

    if Data.IsPlayerESP then
        local function AddPlayer(plr)
            if plr == LocalPlayer then return end

            local function Setup(char)
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    Add(root, plr.Name)
                end
            end

            if plr.Character then
                Setup(plr.Character)
            end

            plr.CharacterAdded:Connect(function(char)
                task.defer(Setup, char)
            end)
        end

        for _,p in pairs(Players:GetPlayers()) do
            AddPlayer(p)
        end

        Players.PlayerAdded:Connect(AddPlayer)
    end

    return Group
end

return DrawingESP
