
loadstring([[ function LPH_NO_VIRTUALIZE(f) return f end; ]])();
local DrawingESP = {}
DrawingESP.__index = DrawingESP

DrawingESP.Groups = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

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
        Text = text,
        Alive = true,
    }
end

--====================================================
-- SCREEN-SPACE BOX FROM BOUNDING BOX
--====================================================

local function GetScreenBounds(part, camera)
    local cf = part.CFrame
    local sz = part.Size / 2

    local corners = {
        cf * Vector3.new( sz.X,  sz.Y,  sz.Z),
        cf * Vector3.new(-sz.X,  sz.Y,  sz.Z),
        cf * Vector3.new( sz.X, -sz.Y,  sz.Z),
        cf * Vector3.new(-sz.X, -sz.Y,  sz.Z),
        cf * Vector3.new( sz.X,  sz.Y, -sz.Z),
        cf * Vector3.new(-sz.X,  sz.Y, -sz.Z),
        cf * Vector3.new( sz.X, -sz.Y, -sz.Z),
        cf * Vector3.new(-sz.X, -sz.Y, -sz.Z),
    }

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local allOnScreen = false

    for _, corner in ipairs(corners) do
        local screen, onScreen = camera:WorldToViewportPoint(corner)
        if screen.Z > 0 then
            allOnScreen = true
            if screen.X < minX then minX = screen.X end
            if screen.Y < minY then minY = screen.Y end
            if screen.X > maxX then maxX = screen.X end
            if screen.Y > maxY then maxY = screen.Y end
        end
    end

    if not allOnScreen then return nil end

    return minX, minY, maxX - minX, maxY - minY
end

--====================================================
-- UPDATE LOOP
--====================================================

function DrawingESP:Update()
    local cam = workspace.CurrentCamera
    if not cam then return end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local rootPos = root.Position

    for _, group in pairs(DrawingESP.Groups) do

        -- DISABLED GROUP
        if not group.Enabled then
            for _, obj in ipairs(group.Objects) do
                if obj.Box then obj.Box.Visible = false end
                if obj.Text then obj.Text.Visible = false end
            end
            continue
        end

        local i = 1

        while i <= #group.Objects do
            local obj = group.Objects[i]
            local part = obj.Part

            -- DEAD CHECK
            if not part or not part.Parent or not part:IsDescendantOf(game) then
                if obj.Box then obj.Box:Remove() end
                if obj.Text then obj.Text:Remove() end

                group._added[part] = nil
                table.remove(group.Objects, i)
                continue
            end

            -- LIVE CHECK (IMPORTANT FIX)
            local shouldRender = true
            if group._check then
                local inst = obj.Instance or part
                shouldRender = group._check(inst, part)
            end

            if not shouldRender then
                obj.Box.Visible = false
                obj.Text.Visible = false
                i += 1
                continue
            end

            -- DISTANCE
            local dist = (part.Position - rootPos).Magnitude
            if dist > group.MaxDistance then
                obj.Box.Visible = false
                obj.Text.Visible = false
                i += 1
                continue
            end

            -- RENDER
            local pos = cam:WorldToViewportPoint(part.Position)

            if pos.Z > 0 then
                obj.Box.Position = Vector2.new(pos.X - 25, pos.Y - 25)
                obj.Box.Size = Vector2.new(50, 50)
                obj.Box.Visible = true

                obj.Text.Position = Vector2.new(pos.X, pos.Y - 35)
                obj.Text.Text = obj.Name .. string.format(" [%.0fm]", dist)
                obj.Text.Visible = true
            else
                obj.Box.Visible = false
                obj.Text.Visible = false
            end

            i += 1
        end
    end
end

--====================================================
-- GROUP SYSTEM
--====================================================

function DrawingESP:CreateGroup(name, data)
    if DrawingESP.Groups[name] then
        return DrawingESP.Groups[name]
    end

    local group = {
        Objects = {},
        _added = {},

        _check = data.Check,
        _container = data.Container,
        _desc = data.Descendants,

        Enabled = data.Enabled or false,
        MaxDistance = data.MaxDistance or 200,

        _rescanTimer = 0,
    }

    DrawingESP.Groups[name] = group

    local function TryAdd(v)
        if not v then return end

        local part
        if v:IsA("Model") then
            part = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
        elseif v:IsA("BasePart") then
            part = v
        end

        if not part then return end

        local allowed = true
        if group._check then
            allowed = group._check(v, part)
        end

        local existing = group._added[part]

        -- IF EXISTS → update state instead of duplicating
        if existing then
            existing._disabled = not allowed
            return
        end

        -- IF NOT ALLOWED → ignore
        if not allowed then return end

        local esp = {
            Part = part,
            Name = v.Name,
            Instance = v,
            _disabled = false,
        }

        group._added[part] = esp
        table.insert(group.Objects, esp)
    end

    if data.Container then
        local list = data.Descendants
            and data.Container:GetDescendants()
            or data.Container:GetChildren()

        for _, v in ipairs(list) do
            TryAdd(v)
        end

        if data.Descendants then
            data.Container.DescendantAdded:Connect(TryAdd)
        else
            data.Container.ChildAdded:Connect(TryAdd)
        end
    end

    if data.IsPlayerESP then
        local function AddPlayer(plr)
            if plr == LocalPlayer then return end

            local function AddChar(char)
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                if group._added[hrp] then return end

                local allowed = true
                if group._check then
                    allowed = group._check(plr, hrp)
                end

                if not allowed then return end

                local esp = {
                    Part = hrp,
                    Name = plr.Name,
                    Instance = plr,
                    _disabled = false,
                }

                group._added[hrp] = esp
                table.insert(group.Objects, esp)
            end

            plr.CharacterAdded:Connect(AddChar)
            if plr.Character then
                AddChar(plr.Character)
            end
        end

        for _, p in ipairs(Players:GetPlayers()) do
            AddPlayer(p)
        end

        Players.PlayerAdded:Connect(AddPlayer)
    end

    return group
end

--====================================================
-- UTILITY FUNCTIONS
--====================================================

function DrawingESP:EnableGroup(name)
    local group = self.Groups[name]
    if group then
        group.Enabled = true
    end
end

function DrawingESP:DisableGroup(name)
    local group = self.Groups[name]
    if group then
        group.Enabled = false
    end
end

function DrawingESP:SetGroupDistance(name, distance)
    local group = self.Groups[name]
    if group then
        group.MaxDistance = distance
    end
end

function DrawingESP:UpdateGroupCheck(name, newCheck)
    local group = self.Groups[name]
    if group then
        group._check = newCheck
        -- Force a rescan to re-evaluate all objects
        group._rescanTimer = 30
    end
end

--====================================================
-- UPDATE LOOP (HEARTBEAT FIX)
--====================================================

local accum = 0

RunService.Heartbeat:Connect(function(dt)
    accum += dt
    if accum < 0.03 then return end
    accum = 0

    DrawingESP:Update()
end)

return DrawingESP
