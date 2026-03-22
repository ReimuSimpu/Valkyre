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
    Fill.Parent = Rail
    Fill.ZIndex = 2
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

    local function MakeHandle(z)
        local h = Instance.new("Frame")
        h.Size = UDim2.fromOffset(14, 14)
        h.AnchorPoint = Vector2.new(0.5, 0.5)
        h.Position = UDim2.new(0, 0, 0.5, 0)
        h.BackgroundColor3 = Accent
        h.ZIndex = z
        h.Parent = Rail
        Instance.new("UICorner", h).CornerRadius = UDim.new(1, 0)
        return h
    end

    local HandleLow = MakeHandle(4)
    local HandleHigh = MakeHandle(5)

    local function Snap(v)
        return math.floor(v / Step + 0.5) * Step
    end

    local function UpdateUI()
        local lt = (LowVal - Min) / (Max - Min)
        local ht = (HighVal - Min) / (Max - Min)

        HandleLow.Position = UDim2.new(lt, 0, 0.5, 0)
        HandleHigh.Position = UDim2.new(ht, 0, 0.5, 0)

        Fill.Position = UDim2.new(lt, 0, 0, 0)
        Fill.Size = UDim2.new(ht - lt, 0, 1, 0)

        ValueLabel.Text = LowVal .. " – " .. HighVal
    end

    local function SetValue(low, high, fromLoad)
        low = math.clamp(Snap(low), Min, Max)
        high = math.clamp(Snap(high), Min, Max)

        if low > high then
            low, high = high, low
        end

        LowVal = low
        HighVal = high

        UpdateUI()

        if Library and Library.Options and Library.Options[Flag] then
            Library.Options[Flag].Value = {LowVal, HighVal}
        end

        if not fromLoad then
            Callback(LowVal, HighVal)
        end
    end

    local UIS = game:GetService("UserInputService")

    local function Drag(handle, isLow)
        handle.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

            local conn
            conn = UIS.InputChanged:Connect(function(m)
                if m.UserInputType ~= Enum.UserInputType.MouseMovement then return end

                local rx = Rail.AbsolutePosition.X
                local rw = Rail.AbsoluteSize.X
                local t = math.clamp((m.Position.X - rx) / rw, 0, 1)
                local v = Snap(Min + (Max - Min) * t)

                if isLow then
                    SetValue(v, HighVal)
                else
                    SetValue(LowVal, v)
                end
            end)

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    conn:Disconnect()
                end
            end)
        end)
    end

    Drag(HandleLow, true)
    Drag(HandleHigh, false)

    -- Register with Fluent
    if Library then
        Library.Options = Library.Options or {}

        Library.Options[Flag] = {
            Value = {LowVal, HighVal},
            SetValue = function(_, val)
                SetValue(val[1], val[2], true)
            end
        }
    end

    -- Initial render
    SetValue(DefaultLow, DefaultHigh, true)

    return {
        SetValue = function(_, l, h)
            SetValue(l, h)
        end,
        GetValue = function()
            return LowVal, HighVal
        end
    }
end

return RangeSlider
