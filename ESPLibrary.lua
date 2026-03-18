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
    -- Sample the 8 corners of the part's bounding box in world space,
    -- project each to screen, then return a tight 2D rect around them.
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
        if screen.Z > 0 then  -- in front of camera
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
    -- Re-grab camera each frame in case it changes
    local cam = workspace.CurrentCamera
    if not cam then return end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local rootPos = root.Position

    for _, group in pairs(self.Groups) do
        if not group.Enabled then
            -- Hide everything in the group and skip heavy work
            for _, esp in ipairs(group.Objects) do
                esp.Box.Visible = false
                esp.Text.Visible = false
            end
            continue
        end

        local maxDist = group.MaxDistance or 200
        local color = group.Color or Color3.new(1, 1, 1)
        local i = 1

        while i <= #group.Objects do
            local esp = group.Objects[i]
            local part = esp.Part

            -- Stale check: part removed or model destroyed
            local isStale = not part
                or not part.Parent
                or (not part:IsDescendantOf(game))

            if isStale then
                -- Clean up drawings without pcall overhead
                esp.Box:Remove()
                esp.Text:Remove()
                group._addedParts[part] = nil
                table.remove(group.Objects, i)
                -- Don't increment i — the next element slides into position i
                continue
            end

            local dist = (part.Position - rootPos).Magnitude

            if dist > maxDist then
                esp.Box.Visible = false
                esp.Text.Visible = false
                i += 1
                continue
            end

            -- Use the bounding-box projection for an accurate screen box
            if group.Box or group.Text then
                local x, y, w, h = GetScreenBounds(part, cam)

                if not x then
                    -- Part is fully behind the camera
                    esp.Box.Visible = false
                    esp.Text.Visible = false
                    i += 1
                    continue
                end

                if group.Box then
                    esp.Box.Position = Vector2.new(x, y)
                    esp.Box.Size = Vector2.new(w, h)
                    esp.Box.Color = color
                    esp.Box.Visible = true
                else
                    esp.Box.Visible = false
                end

                if group.Text then
                    local distText = string.format("[%.0fm]", dist)
                    esp.Text.Text = esp.Name .. " " .. distText
                    -- Place text just above the top of the box
                    esp.Text.Position = Vector2.new(x + w / 2, y - 16)
                    esp.Text.Color = color
                    esp.Text.Visible = true
                else
                    esp.Text.Visible = false
                end
            end

            i += 1
        end
    end
end

-- Throttle: ~33 fps is plenty for ESP; RenderStepped keeps it in sync with frames
do
    local accum = 0
    RunService.RenderStepped:Connect(function(dt)
        accum += dt
        if accum < 0.03 then return end
        accum = 0
        DrawingESP:Update()
    end)
end

--====================================================
-- GROUP SYSTEM
--====================================================

function DrawingESP:CreateGroup(name, data)
    if DrawingESP.Groups[name] then
        return DrawingESP.Groups[name]
    end

    local group = {
        Objects    = {},
        _addedParts = {},
        Enabled    = data.Enabled    or false,
        Color      = data.Color      or Color3.new(1, 1, 1),
        MaxDistance = data.MaxDistance or 200,
        Box        = true,
        Text       = true,
    }
    DrawingESP.Groups[name] = group

    local addedParts = group._addedParts

    local function TryAdd(v)
        if not v then return end

        local targetPart, displayName

        if v:IsA("Model") then
            targetPart  = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
            displayName = v.Name
        elseif v:IsA("BasePart") and not v.Parent:IsA("Model") then
            targetPart  = v
            displayName = v.Name
        end

        if targetPart and not addedParts[targetPart] then
            addedParts[targetPart] = true
            table.insert(group.Objects, DrawingESP:NewESP(targetPart, displayName))
        end
    end

    -- OBJECT / CONTAINER ESP
    if data.Container then
        for _, v in ipairs(data.Container:GetChildren()) do
            TryAdd(v)
        end
        data.Container.ChildAdded:Connect(TryAdd)
    end

    -- PLAYER ESP
    if data.IsPlayerESP then
        local function AddPlayer(plr)
            if plr == LocalPlayer then return end

            local function AddChar(char)
                local hrp = char:WaitForChild("HumanoidRootPart", 5)
                if hrp and not addedParts[hrp] then
                    addedParts[hrp] = true
                    table.insert(group.Objects, DrawingESP:NewESP(hrp, plr.Name))
                end
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

return DrawingESP
