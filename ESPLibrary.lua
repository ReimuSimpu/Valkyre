loadstring([[ function LPH_NO_VIRTUALIZE(f) return f end; ]])();
local DrawingESP = {}
DrawingESP.__index = DrawingESP

DrawingESP.Groups = {}

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
        Text = text,
        Alive = true,
    }
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

            -- LIVE CHECK - respect _disabled flag
            local shouldRender = not obj._disabled
            if group._check then
                local inst = obj.Instance or part
                shouldRender = group._check(inst, part)
                obj._disabled = not shouldRender
            end

            if not shouldRender then
                obj.Box.Visible = false
                obj.Text.Visible = false
                i += 1
                continue
            end

            -- DISTANCE CHECK
            if not part or not part:IsA("BasePart") then
                i += 1
                continue
            end

            if not part or not part:IsA("BasePart") then
                i += 1
                continue
            end
            
            local partPos = part.Position
            if not partPos then
                i += 1
                continue
            end
            
            local dist = (partPos - rootPos).Magnitude
            if dist > group.MaxDistance then
                obj.Box.Visible = false
                obj.Text.Visible = false
                i += 1
                continue
            end

            -- RENDER
            local pos = cam:WorldToViewportPoint(partPos)

            if pos.Z > 0 then
                obj.Box.Position = Vector2.new(pos.X - 25, pos.Y - 25)
                obj.Box.Size = Vector2.new(50, 50)
                obj.Box.Visible = true

                obj.Text.Position = Vector2.new(pos.X, pos.Y - 35)
                local displayDist = math.floor(dist + 0.5) -- Round to nearest integer
                obj.Text.Text = obj.Name .. string.format(" [%dm]", displayDist)
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
    
        -- ❗ HARD GUARD (prevents nil Position crash later)
        if not part or not part:IsA("BasePart") then
            return
        end
    
        local allowed = true
        if group._check then
            local ok, result = pcall(group._check, v, part)
            allowed = ok and result
        end
    
        local existing = group._added[part]
    
        if existing then
            existing._disabled = not allowed
            return
        end
    
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

                -- CREATE ESP OBJECT WITH DRAWINGS
                local esp = DrawingESP:NewESP(hrp, plr.Name)
                esp.Instance = plr
                esp._disabled = false

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
    end
end

--====================================================
-- UPDATE LOOP (HEARTBEAT)
--====================================================

local accum = 0

RunService.Heartbeat:Connect(function(dt)
    accum += dt
    if accum < 0.03 then return end
    accum = 0

    DrawingESP:Update()
end)

return DrawingESP
