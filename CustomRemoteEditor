local HaloUI = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local DecorateModeGui = PlayerGui:WaitForChild("DecorateModeGui", 10)
local BaseUI = DecorateModeGui and DecorateModeGui:WaitForChild("FurnitureEditRemote", 10)

local UI
local connections = {} -- Store connections to clean them up properly

local Active = {
    Model = nil,
    Base = nil,
    Weld = nil,
    Pos = Vector3.new(0, 1.5, 0),
    Rot = CFrame.new(),
    Undo = {},
    Redo = {}
}

local TiltStep = math.rad(15)
local MoveStep = 0.1
local MaxHistory = 15

--// CLEANUP OLD CONNECTIONS
local function ClearConnections()
    for _, c in ipairs(connections) do
        if c then c:Disconnect() end
    end
    connections = {}
end

--// APPLY WELD
local function Apply()
    if Active.Weld and Active.Weld.Parent then
        Active.Weld.C0 = CFrame.new(Active.Pos) * Active.Rot
    end
end

--// HISTORY
local function Push()
    table.insert(Active.Undo, {
        Pos = Active.Pos,
        Rot = Active.Rot
    })
    if #Active.Undo > MaxHistory then table.remove(Active.Undo, 1) end
    Active.Redo = {}
end

--// MOVE LOGIC
function HaloUI.Move(axis, dir)
    local cam = workspace.CurrentCamera
    if not cam then return end

    local cf = cam.CFrame
    local flat = CFrame.lookAt(cf.Position * Vector3.new(1, 0, 1), (cf.Position + cf.LookVector) * Vector3.new(1, 0, 1))
    local rot = flat - flat.Position
    
    local vec = (axis == "X" and rot.RightVector) or (axis == "Z" and rot.LookVector) or Vector3.new(0, 1, 0)

    Active.Pos += vec * dir * MoveStep
    Apply()
end

--// TILT LOGIC
function HaloUI.Tilt(axis, dir)
    local angles = {
        X = {TiltStep * dir, 0, 0},
        Y = {0, TiltStep * dir, 0},
        Z = {0, 0, TiltStep * dir}
    }
    local a = angles[axis]
    Active.Rot *= CFrame.Angles(unpack(a))
    Apply()
end

--// SET TARGET
function HaloUI.Set(model, base, head)
    Active.Model = model
    Active.Base = base

    if Active.Weld then Active.Weld:Destroy() end

    local weld = Instance.new("Weld")
    weld.Part0 = head
    weld.Part1 = base
    weld.C0 = CFrame.new(Active.Pos) * Active.Rot
    weld.Parent = base

    Active.Weld = weld
    Push()
end

--// SAFE BUTTON FINDER
local function FindButton(name)
    if not UI then return nil end
    for _, v in ipairs(UI:GetDescendants()) do
        if v:IsA("GuiButton") and v.Name == name then
            return v
        end
    end
    return nil
end

--// INITIALIZE
function HaloUI.Init()
    if not BaseUI then warn("BaseUI (FurnitureEditRemote) not found!") return end
    
    ClearConnections()
    if UI then UI:Destroy() end

    UI = BaseUI:Clone()
    UI.Name = "HaloEditorUI"
    UI.Parent = PlayerGui
    UI.Visible = true

    local Sounds = UI:FindFirstChild("Sounds")

    -- Helper to setup hold-to-repeat buttons
    local function SetupRepeatButton(btnName, func, axis, dir, soundName)
        local btn = FindButton(btnName)
        if not btn then return end

        local btnDown = btn.MouseButton1Down:Connect(function()
            if Sounds and Sounds:FindFirstChild(soundName or btnName) then
                Sounds[soundName or btnName]:Play()
            end

            local holding = true
            task.spawn(function()
                task.wait(0.2) -- Delay before rapid fire
                while holding do
                    func(axis, dir)
                    task.wait(0.05)
                end
            end)

            func(axis, dir)
            Push() -- Save history after the click

            local release
            release = UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    holding = false
                    release:Disconnect()
                end
            end)
        end)
        table.insert(connections, btnDown)
    end

    -- Setup Tilt Buttons
    local tilts = {
        TiltUp = {"X", 1}, TiltDown = {"X", -1},
        TiltLeft = {"Z", -1}, TiltRight = {"Z", 1},
        RotateLeft = {"Y", -1}, RotateRight = {"Y", 1}
    }
    for name, data in pairs(tilts) do SetupRepeatButton(name, HaloUI.Tilt, data[1], data[2]) end

    -- Setup Move Buttons
    local moves = {
        MoveRight = {"X", 1}, MoveLeft = {"X", -1},
        MoveForward = {"Z", 1}, MoveBackward = {"Z", -1},
        MoveUp = {"Y", 1}, MoveDown = {"Y", -1}
    }
    for name, data in pairs(moves) do SetupRepeatButton(name, HaloUI.Move, data[1], data[2], "Move") end

    -- History & UI Utility
    local undo = FindButton("Undo")
    if undo then table.insert(connections, undo.MouseButton1Click:Connect(function() 
        local last = table.remove(Active.Undo)
        if last then
            table.insert(Active.Redo, {Pos = Active.Pos, Rot = Active.Rot})
            Active.Pos, Active.Rot = last.Pos, last.Rot
            Apply()
        end
    end)) end

    local close = FindButton("Close")
    if close then table.insert(connections, close.MouseButton1Click:Connect(function() UI.Visible = false end)) end
end

return HaloUI
