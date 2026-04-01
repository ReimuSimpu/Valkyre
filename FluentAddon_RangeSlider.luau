local RangeSlider = {}
RangeSlider.__index = RangeSlider

local UserInputService = game:GetService("UserInputService")

local GlobalDragging = nil

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
    local Flag = Options.Flag or Title

    local Library = self.Fluent
    local Accent = Color3.fromRGB(96, 205, 255)

    local LowVal = DefaultLow
    local HighVal = DefaultHigh

    local Container = Tab.Container or Tab.ScrollFrame

    local Wrapper = Instance.new("Frame")
    Wrapper.Size = UDim2.new(1, 0, 0, 62)
    Wrapper.BackgroundTransparency = 0.87
    Wrapper.BorderSizePixel = 0
    Wrapper.LayoutOrder = #Container:GetChildren() + 1
    Wrapper.Parent = Container
    
    Instance.new("UICorner", Wrapper).CornerRadius = UDim.new(0, 4)

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

    local ValueLabel = TitleLabel:Clone()
    ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
    ValueLabel.Font = Enum.Font.Gotham
    ValueLabel.TextSize = 12
    ValueLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
    ValueLabel.Parent = Wrapper

    local Rail = Instance.new("Frame")
    Rail.Size = UDim2.new(1, -28, 0, 4)
    Rail.Position = UDim2.new(0, 14, 0, 46)
    Rail.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    Rail.BorderSizePixel = 0
    Rail.Parent = Wrapper
    Instance.new("UICorner", Rail).CornerRadius = UDim.new(1, 0)

    local Fill = Instance.new("Frame")
    Fill.BackgroundColor3 = Accent
    Fill.BorderSizePixel = 0
    Fill.ZIndex = 2
    Fill.Parent = Rail
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

    local function MakeHandle(Z)
        local H = Instance.new("Frame")
        H.Size = UDim2.fromOffset(14, 14)
        H.AnchorPoint = Vector2.new(0.5, 0.5)
        H.Position = UDim2.new(0, 0, 0.5, 0)
        H.BackgroundColor3 = Accent
        H.ZIndex = Z
        H.Parent = Rail
        Instance.new("UICorner", H).CornerRadius = UDim.new(1, 0)
        return H
    end

    local HandleLow = MakeHandle(4)
    local HandleHigh = MakeHandle(5)

    local function Snap(V)
        return math.floor(V / Step + 0.5) * Step
    end

    local function UpdateUI()
        local LT = (LowVal - Min) / (Max - Min)
        local HT = (HighVal - Min) / (Max - Min)

        HandleLow.Position = UDim2.new(LT, 0, 0.5, 0)
        HandleHigh.Position = UDim2.new(HT, 0, 0.5, 0)

        Fill.Position = UDim2.new(LT, 0, 0, 0)
        Fill.Size = UDim2.new(HT - LT, 0, 1, 0)

        ValueLabel.Text = LowVal .. " – " .. HighVal
    end

    local function SetValue(Low, High, FromLoad)
        if typeof(Low) == "table" then
            Low, High = Low[1], Low[2]
        end

        Low = Low ~= nil and Low or LowVal
        High = High ~= nil and High or HighVal

        Low = math.clamp(Snap(Low), Min, Max)
        High = math.clamp(Snap(High), Min, Max)

        if Low > High then
            Low, High = High, Low
        end

        LowVal = Low
        HighVal = High

        UpdateUI()

        if Library and Library.Options and Library.Options[Flag] then
            Library.Options[Flag].Value = {LowVal, HighVal}
        end

        if not FromLoad then
            Callback(LowVal, HighVal)
        end
    end

    UserInputService.InputChanged:Connect(function(Input)
        if not GlobalDragging then return end
        if Input ~= GlobalDragging.Input then return end

        if Input.UserInputType ~= Enum.UserInputType.MouseMovement 
        and Input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local RX = Rail.AbsolutePosition.X
        local RW = Rail.AbsoluteSize.X
        local T = math.clamp((Input.Position.X - RX) / RW, 0, 1)
        local V = Snap(Min + (Max - Min) * T)

        if GlobalDragging.IsLow then
            SetValue(V, HighVal)
        else
            SetValue(LowVal, V)
        end
    end)

    local function SetupDrag(Handle, IsLow)
        Handle.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 
            or Input.UserInputType == Enum.UserInputType.Touch then
                GlobalDragging = {
                    Input = Input,
                    IsLow = IsLow
                }
            end
        end)

        Handle.InputEnded:Connect(function(Input)
            if GlobalDragging and Input == GlobalDragging.Input then
                GlobalDragging = nil
            end
        end)
    end

    SetupDrag(HandleLow, true)
    SetupDrag(HandleHigh, false)

    Rail.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseButton1 
        and Input.UserInputType ~= Enum.UserInputType.Touch then return end

        local RX = Rail.AbsolutePosition.X
        local RW = Rail.AbsoluteSize.X
        local T = math.clamp((Input.Position.X - RX) / RW, 0, 1)
        local V = Snap(Min + (Max - Min) * T)

        if math.abs(V - LowVal) < math.abs(V - HighVal) then
            SetValue(V, HighVal)
        else
            SetValue(LowVal, V)
        end
    end)

    if Library then
        Library.Options = Library.Options or {}

        Library.Options[Flag] = {
            Type = "RangeSlider",
            Value = {LowVal, HighVal},
            SetValue = function(_, Val)
                SetValue(Val, nil, true)
            end
        }
    end

    SetValue(DefaultLow, DefaultHigh, true)

    return {
        SetValue = function(_, L, H)
            SetValue(L, H)
        end,
        GetValue = function()
            return LowVal, HighVal
        end
    }
end

return RangeSlider
