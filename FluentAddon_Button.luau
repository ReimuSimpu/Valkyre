local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local FluentButton = {}
FluentButton.__index = FluentButton

function FluentButton.New(options)
    options = options or {}
    local self = setmetatable({}, FluentButton)

    local ScreenGui = CoreGui:FindFirstChild("Valkyra")
    if not ScreenGui then
        ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "Valkyra"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.Parent = CoreGui
    end
    self.ScreenGui = ScreenGui

    local ImageButton = Instance.new("ImageButton")
    ImageButton.Name = options.Name or "ValkyraToggle"
    ImageButton.Parent = ScreenGui
    ImageButton.Image = options.Image or "rbxassetid://99432005503954"
    ImageButton.Size = options.Size or UDim2.new(0, 45, 0, 45)
    ImageButton.Position = options.Position or UDim2.new(0, 10, 0, 10)
    ImageButton.BackgroundColor3 = options.Color or Color3.fromRGB(255, 150, 220)
    ImageButton.ScaleType = Enum.ScaleType.Fit
    ImageButton.Active = true
    self.Button = ImageButton
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = options.CornerRadius or UDim.new(0.2, 0)
    UICorner.Parent = ImageButton

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = options.StrokeColor or Color3.fromRGB(255, 200, 240)
    UIStroke.Thickness = options.StrokeThickness or 2
    UIStroke.Transparency = options.StrokeTransparency or 0.3
    UIStroke.Parent = ImageButton

    local UIScale = Instance.new("UIScale")
    UIScale.Parent = ImageButton
    UIScale.Scale = 1
    self.UIScale = UIScale

    local Activated = Instance.new("BindableEvent")
    self.Activated = Activated
    
    local function TweenButtonScale(targetScale, duration, easing)
        TweenService:Create(UIScale, TweenInfo.new(duration or 0.1, easing or Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
            Scale = targetScale
        }):Play()
    end

    local Active = false
    local Hover = false
    local ScaleOnHover = options.ScaleOnHover or 1.05

    -- Hover effects
    local function OnHover()
        if not Active then
            Hover = true
            TweenButtonScale(ScaleOnHover, 0.05, Enum.EasingStyle.Circular)
        end
    end

    local function OnLeave()
        Hover = false
        if not Active then
            TweenButtonScale(1, 0.05, Enum.EasingStyle.Circular)
        end
    end

    ImageButton.MouseEnter:Connect(OnHover)
    ImageButton.MouseLeave:Connect(OnLeave)

    for _, InputType in ipairs({Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch}) do
        ImageButton.InputBegan:Connect(function(input)
            if input.UserInputType == InputType and not Active then
                Active = true
                TweenButtonScale(0.9, 0.065, Enum.EasingStyle.Circular)
            end
        end)
        ImageButton.InputEnded:Connect(function(input)
            if input.UserInputType == InputType and Active then
                Active = false
                TweenButtonScale(Hover and ScaleOnHover or 1, 0.25, Enum.EasingStyle.Circular)
                Activated:Fire()
            end
        end)
    end

    local dragging = false
    local dragStartPos
    local mouseStartPos

    ImageButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStartPos = ImageButton.Position
            mouseStartPos = input.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - mouseStartPos
            ImageButton.Position = UDim2.new(
                dragStartPos.X.Scale,
                dragStartPos.X.Offset + delta.X,
                dragStartPos.Y.Scale,
                dragStartPos.Y.Offset + delta.Y
            )
        end
    end)

    ImageButton.Destroying:Connect(function()
        Activated:Destroy()
    end)

    return self
end

return FluentButton
