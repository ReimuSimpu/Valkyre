local ESP = {}
ESP.Groups = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer

local RootPart, LastRootUpdate = nil, 0

local function GetRoot()
	if os.clock() - LastRootUpdate > 0.1 then
		local char = LocalPlayer.Character
		RootPart = char and char:FindFirstChild("HumanoidRootPart")
		LastRootUpdate = os.clock()
	end
	return RootPart
end

local function NewDrawing(Type)
	local obj = Drawing.new(Type)
	obj.Visible = false
	return obj
end

local function CreateObject(Part, Name, Color)
	return {
		Part = Part,
		Name = Name,
		Color = Color,

		Box = NewDrawing("Square"),
		Outline = NewDrawing("Square"),
		Text = NewDrawing("Text"),
		Tracer = NewDrawing("Line"),

		Skeleton = {}
	}
end

local SkeletonMap = {
	{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
	{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},
	{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},
	{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},
	{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"}
}

local function RemoveObject(Object)
	Object.Box:Remove()
	Object.Outline:Remove()
	Object.Text:Remove()
	Object.Tracer:Remove()
	for _,Line in pairs(Object.Skeleton) do
		Line:Remove()
	end
end

local function UpdateObject(Group, Object)
	local Part = Object.Part
	if not Part or not Part.Parent then
		return false
	end

	local Root = GetRoot()
	if not Root then return true end

	local Distance = (Part.Position - Root.Position).Magnitude
	if Distance > Group.MaxDistance then
		Object.Box.Visible = false
		Object.Outline.Visible = false
		Object.Text.Visible = false
		Object.Tracer.Visible = false
		for _,Line in pairs(Object.Skeleton) do Line.Visible = false end
		return true
	end

	local ScreenPos, OnScreen = Camera:WorldToViewportPoint(Part.Position)
	if not OnScreen then
		Object.Box.Visible = false
		Object.Outline.Visible = false
		Object.Text.Visible = false
		Object.Tracer.Visible = false
		for _,Line in pairs(Object.Skeleton) do Line.Visible = false end
		return true
	end

	local Scale = math.clamp(300 / Distance * 10, 20, 150)
	local BoxPos = Vector2.new(ScreenPos.X - Scale/2, ScreenPos.Y - Scale/2)

	if Group.Box then
		Object.Box.Position = BoxPos
		Object.Box.Size = Vector2.new(Scale, Scale)
		Object.Box.Color = Group.Color
		Object.Box.Thickness = 1
		Object.Box.Visible = true

		Object.Outline.Position = BoxPos
		Object.Outline.Size = Vector2.new(Scale, Scale)
		Object.Outline.Color = Color3.new(0,0,0)
		Object.Outline.Thickness = 3
		Object.Outline.Visible = true
	else
		Object.Box.Visible = false
		Object.Outline.Visible = false
	end

	if Group.Text then
		local Text = Object.Name
		if Group.ShowDistance then
			Text = Text .. " [" .. math.floor(Distance) .. "]"
		end

		Object.Text.Position = Vector2.new(ScreenPos.X, BoxPos.Y - 14)
		Object.Text.Text = Text
		Object.Text.Color = Group.Color
		Object.Text.Size = Group.TextSize
		Object.Text.Center = true
		Object.Text.Outline = true
		Object.Text.Visible = true
	else
		Object.Text.Visible = false
	end

	if Group.Tracer then
		local Viewport = Camera.ViewportSize
		Object.Tracer.From = Vector2.new(Viewport.X/2, Viewport.Y)
		Object.Tracer.To = Vector2.new(ScreenPos.X, ScreenPos.Y)
		Object.Tracer.Color = Group.Color
		Object.Tracer.Thickness = 1
		Object.Tracer.Visible = true
	else
		Object.Tracer.Visible = false
	end

	if Group.Skeleton and Part.Parent:FindFirstChild("Humanoid") then
		for Index,Pair in ipairs(SkeletonMap) do
			local A = Part.Parent:FindFirstChild(Pair[1])
			local B = Part.Parent:FindFirstChild(Pair[2])

			if A and B then
				local Line = Object.Skeleton[Index] or NewDrawing("Line")
				Object.Skeleton[Index] = Line

				local APos, AVis = Camera:WorldToViewportPoint(A.Position)
				local BPos, BVis = Camera:WorldToViewportPoint(B.Position)

				if AVis and BVis then
					Line.From = Vector2.new(APos.X, APos.Y)
					Line.To = Vector2.new(BPos.X, BPos.Y)
					Line.Color = Group.Color
					Line.Thickness = 1
					Line.Visible = true
				else
					Line.Visible = false
				end
			end
		end
	else
		for _,Line in pairs(Object.Skeleton) do
			Line.Visible = false
		end
	end

	return true
end

if not getgenv().__ADV_ESP__ then
	getgenv().__ADV_ESP__ = true

	RunService.RenderStepped:Connect(function()
		for _,Group in pairs(ESP.Groups) do
			if not Group.Enabled then continue end

			for i = #Group.Objects, 1, -1 do
				local Obj = Group.Objects[i]
				local Alive = UpdateObject(Group, Obj)

				if not Alive then
					RemoveObject(Obj)
					table.remove(Group.Objects, i)
				end
			end
		end
	end)
end

function ESP:CreateGroup(Name, Config)
	local Group = {
		Name = Name,
		Objects = {},

		Enabled = Config.Enabled or false,
		Color = Config.Color or Color3.new(1,1,1),
		MaxDistance = Config.MaxDistance or 200,

		Box = true,
		Text = true,
		Tracer = false,
		Skeleton = Config.IsPlayerESP or false,

		ShowDistance = true,
		TextSize = 13
	}

	self.Groups[Name] = Group

	local function Add(Part, DisplayName)
		table.insert(Group.Objects, CreateObject(Part, DisplayName or Name, Group.Color))
	end

	if Config.Container then
		for _,Obj in pairs(Config.Container:GetDescendants()) do
			if Obj:IsA("BasePart") then
				Add(Obj)
			end
		end

		Config.Container.DescendantAdded:Connect(function(Obj)
			if Obj:IsA("BasePart") then
				Add(Obj)
			end
		end)
	end

	if Config.IsPlayerESP then
		local function HandlePlayer(Player)
			if Player == Players.LocalPlayer then return end

			Player.CharacterAdded:Connect(function(Char)
				local Root = Char:WaitForChild("HumanoidRootPart", 5)
				if Root then Add(Root, Player.Name) end
			end)

			if Player.Character then
				local Root = Player.Character:FindFirstChild("HumanoidRootPart")
				if Root then Add(Root, Player.Name) end
			end
		end

		for _,Player in pairs(Players:GetPlayers()) do
			HandlePlayer(Player)
		end

		Players.PlayerAdded:Connect(HandlePlayer)
	end

	return Group
end

return ESP
