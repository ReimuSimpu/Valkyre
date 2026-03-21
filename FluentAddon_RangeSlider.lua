local RangeSlider = {}
RangeSlider.__index = RangeSlider

function RangeSlider:SetLibrary(Fluent)
    self.Fluent = Fluent
    return self
end

function RangeSlider:AddToTab(Tab, Options)
    Options = Options or {}
    local Min = Options.Min or 0
    local Max = Options.Max or 100
    local DefaultLow = Options.DefaultLow or Min
    local DefaultHigh = Options.DefaultHigh or Max
    local Title = Options.Title or "Range"
    local Step = Options.Step or 1
    local Callback = Options.Callback or function() end

    local Accent = Color3.fromRGB(96, 205, 255)
    if self.Fluent then
        pcall(function()
            Accent = require(game:GetService("CoreGui"):FindFirstChild("Fluent", true))
                and Color3.fromRGB(96, 205, 255)
        end)
    end

    local LowVal = DefaultLow
    local HighVal = DefaultHigh

    local Container = Tab.Container or Tab.ScrollFrame

    local Wrapper = Instance.new("Frame")
    Wrapper.Name = "RangeSlider_" .. Title
    Wrapper.Size = UDim2.new(1, 0, 0, 62)
    Wrapper.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    Wrapper.BackgroundTransparency = 0.87
    Wrapper.BorderSizePixel = 0
    Wrapper.Parent = Container

    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 4)
    UICorner.Parent = Wrapper

    local UIStroke = Instance.new("UIStroke")
    UIStroke.Transparency = 0.5
    UIStroke.Color = Color3.fromRGB(35, 35, 35)
    UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    UIStroke.Parent = Wrapper

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -16, 0, 14)
    TitleLabel.Position = UDim2.fromOffset(10, 12)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.GothamMedium
    TitleLabel.TextSize = 13
    TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Text = Title
    TitleLabel.Parent = Wrapper

    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Size = UDim2.new(1, -16, 0, 14)
    ValueLabel.Position = UDim2.fromOffset(10, 12)
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.Font = Enum.Font.Gotham
    ValueLabel.TextSize = 12
    ValueLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
    ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    ValueLabel.Text = tostring(LowVal) .. " – " .. tostring(HighVal)
    ValueLabel.Parent = Wrapper

    local Rail = Instance.new("Frame")
    Rail.Name = "Rail"
    Rail.Size = UDim2.new(1, -28, 0, 4)
    Rail.Position = UDim2.new(0, 14, 0, 46)
    Rail.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    Rail.BorderSizePixel = 0
    Rail.ClipsDescendants = false
    Rail.Parent = Wrapper
    Instance.new("UICorner", Rail).CornerRadius = UDim.new(1, 0)

    local Fill = Instance.new("Frame")
    Fill.Name = "Fill"
    Fill.BackgroundColor3 = Accent
    Fill.BorderSizePixel = 0
    Fill.ZIndex = 2
    Fill.Parent = Rail
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

    local function MakeHandle(ZIndex)
        local H = Instance.new("Frame")
        H.Size = UDim2.fromOffset(14, 14)
        H.AnchorPoint = Vector2.new(0.5, 0.5)
        H.Position = UDim2.new(0, 0, 0.5, 0)
        H.BackgroundColor3 = Accent
        H.BorderSizePixel = 0
        H.ZIndex = ZIndex or 4
        H.Parent = Rail
        Instance.new("UICorner", H).CornerRadius = UDim.new(1, 0)

        local Stroke = Instance.new("UIStroke")
        Stroke.Color = Color3.fromRGB(255, 255, 255)
        Stroke.Transparency = 0.85
        Stroke.Thickness = 1.5
        Stroke.Parent = H

        return H
    end

    local HandleLow = MakeHandle(4)
    local HandleHigh = MakeHandle(5)

    local function Snap(V)
        return math.floor(V / Step + 0.5) * Step
    end

    local function Refresh()
        local LowT = (LowVal - Min) / (Max - Min)
        local HighT = (HighVal - Min) / (Max - Min)

        HandleLow.Position = UDim2.new(LowT, 0, 0.5, 0)
        HandleHigh.Position = UDim2.new(HighT, 0, 0.5, 0)

        Fill.Position = UDim2.new(LowT, 0, 0, 0)
        Fill.Size = UDim2.new(HighT - LowT, 0, 1, 0)

        ValueLabel.Text = tostring(LowVal) .. " – " .. tostring(HighVal)
    end

    local UIS = game:GetService("UserInputService")

    local function WireDrag(Handle, IsLow)
        Handle.InputBegan:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then return end
            local Conn
            Conn = UIS.InputChanged:Connect(function(Moved)
                if Moved.UserInputType ~= Enum.UserInputType.MouseMovement and Moved.UserInputType ~= Enum.UserInputType.Touch then return end
                local Rx = Rail.AbsolutePosition.X
                local Rw = Rail.AbsoluteSize.X
                local T = math.clamp((Moved.Position.X - Rx) / Rw, 0, 1)
                local V = Snap(math.clamp(Min + (Max - Min) * T, Min, Max))
                if IsLow then
                    LowVal = math.min(V, HighVal)
                else
                    HighVal = math.max(V, LowVal)
                end
                Refresh()
                Callback(LowVal, HighVal)
            end)
            Input.Changed:Connect(function()
                if Input.UserInputState == Enum.UserInputState.End then
                    Conn:Disconnect()
                end
            end)
        end)
    end

    WireDrag(HandleLow, true)
    WireDrag(HandleHigh, false)
    Refresh()

    local Element = {}

    function Element:SetValue(Low, High)
        LowVal = math.clamp(Snap(Low), Min, Max)
        HighVal = math.clamp(Snap(High), Min, Max)
        if LowVal > HighVal then LowVal, HighVal = HighVal, LowVal end
        Refresh()
        Callback(LowVal, HighVal)
    end

    function Element:GetValue()
        return LowVal, HighVal
    end

    function Element:SetTitle(Text)
        TitleLabel.Text = Text
    end

    function Element:Destroy()
        Wrapper:Destroy()
    end

    if self.Fluent then
        task.defer(function()
            while Wrapper.Parent do
                task.wait(1)
                pcall(function()
                    local Theme = self.Fluent.Theme
                    local Accents = {
                        Dark = Color3.fromRGB(96, 205, 255),
                        Darker = Color3.fromRGB(72, 138, 182),
                        Light = Color3.fromRGB(0, 103, 192),
                        Aqua = Color3.fromRGB(60, 165, 165),
                        Amethyst = Color3.fromRGB(97, 62, 167),
                        Rose = Color3.fromRGB(180, 55, 90),
                    }
                    local Color = Accents[Theme] or Color3.fromRGB(96, 205, 255)
                    Fill.BackgroundColor3 = Color
                    HandleLow.BackgroundColor3 = Color
                    HandleHigh.BackgroundColor3 = Color
                end)
            end
        end)
    end

    return Element
end

return RangeSlider
