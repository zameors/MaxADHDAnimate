--!strict
-- yesj
local TextChatService = game:GetService("TextChatService")

local DEFAULT_FADE_TIME: number = 0.1

local character: Model = _G.CharacterAnimated
local humanoid = character:WaitForChild("Humanoid"):: Humanoid
local animator = humanoid

local animationTracks: {[string]: AnimationTrack} = {}

do
	local animation = Instance.new("Animation")

	local animationData: {[string]: {any}} = {
		Cheer = {"rbxassetid://507770677", Enum.AnimationPriority.Idle},
		Climb = {"rbxassetid://507765644", Enum.AnimationPriority.Core},
		Dance = {"rbxassetid://507772104", Enum.AnimationPriority.Core},
		Dance2 = {"rbxassetid://507776879", Enum.AnimationPriority.Core},
		Dance3 = {"rbxassetid://507777623", Enum.AnimationPriority.Core},
		Fall = {"rbxassetid://507767968", Enum.AnimationPriority.Core},
		Idle = {"rbxassetid://507766388", Enum.AnimationPriority.Core},
		Laugh = {"rbxassetid://507770818", Enum.AnimationPriority.Idle},
		Lunge = {"rbxassetid://522638767", Enum.AnimationPriority.Movement},
		Point = {"rbxassetid://507770453", Enum.AnimationPriority.Idle},
		Run = {"rbxassetid://913376220", Enum.AnimationPriority.Core},
		Sit = {"rbxassetid://2506281703", Enum.AnimationPriority.Core},
		Slash = {"rbxassetid://522635514", Enum.AnimationPriority.Movement},
		Swim = {"rbxassetid://913384386", Enum.AnimationPriority.Core},
		SwimIdle = {"rbxassetid://913389285", Enum.AnimationPriority.Core},
		Tool = {"rbxassetid://507768375", Enum.AnimationPriority.Idle},
		Wave = {"rbxassetid://507770239", Enum.AnimationPriority.Idle}}

	for name, data in pairs(animationData) do
		animation.AnimationId = data[1]

		local animationTrack = animator:LoadAnimation(animation)
		animationTrack.Priority = data[2]

		animationTracks[name] = animationTrack
	end

	animation:Destroy()
end

local animationTrack = animationTracks.Idle
animationTrack:Play(0)

local childAddedConnection: RBXScriptConnection?

local round = math.round

local function play(newAnimationTrack: AnimationTrack, fadeTime: number?)
	if newAnimationTrack.IsPlaying then return end

	local fadeTime = fadeTime or DEFAULT_FADE_TIME

	animationTrack:Stop(fadeTime)
	animationTrack = newAnimationTrack
	animationTrack:Play(fadeTime)
end

local function onClimbing(speed: number)
	play(animationTracks.Climb)

	animationTracks.Climb:AdjustSpeed(round(speed) / 11)
end

local function onFreeFalling(active: boolean)
	if active then play(animationTracks.Fall) end
end

local root = character:FindFirstChild("HumanoidRootPart")

local mD = {
 [Vector3.zero] = "Idle",
 [Vector3.new(0,0,-1)] = "Forward",
 [Vector3.new(1,0,0)] = "Right",
 [Vector3.new(0,0,1)] = "Backward",
 [Vector3.new(-1,0,0)] = "Left",
 [Vector3.new(1,0,-1)] = "ForwardRight",
 [Vector3.new(-1,0,-1)] = "ForwardLeft",
 [Vector3.new(1,0,1)] = "BackwardRight",
 [Vector3.new(-1,0,1)] = "BackwardLeft"
}

local CustomAnimTrack = {}
for i, v in pairs(getgenv().Folder:GetChildren()) do
if v:FindFirstChildOfClass("Animation") then
local LoadedTrack = animator:LoadAnimation(v:FindFirstChildOfClass("Animation"))
CustomAnimTrack[v:FindFirstChildOfClass("Animation").Name] = LoadedTrack
end
end

local function roundV3(v3: Vector3, precision: number?): Vector3
	local mul = 10^(precision or 0)
	local function r(x: number): number
		return math.round(x*mul)/mul
	end
	return Vector3.new(r(v3.X), r(v3.Y), r(v3.Z))
end

local Waist = character:FindFirstChild("Waist",true)
local Neck = character:FindFirstChild("Neck",true)
local WaistC0 = Waist.C0
local NeckC0 = Neck.C0

local function onStrafing(DeltaTime)
if root and Neck and Waist then
DeltaTime = math.clamp(DeltaTime * 7.5, 0, 1)
local HumanoidRootPartCFrame = root.CFrame
local AssemblyLinearVelocity = root.AssemblyLinearVelocity

local RightVector = AssemblyLinearVelocity * HumanoidRootPartCFrame.RightVector
local LookVector = AssemblyLinearVelocity * HumanoidRootPartCFrame.LookVector
        
local Forward = math.rad(LookVector.X + LookVector.Z)
local Sideways = math.rad(RightVector.X + RightVector.Z)
        
Waist.C0 = Waist.C0:Lerp(CFrame.Angles(- Forward, - Sideways, - Sideways) * WaistC0, DeltaTime)
Neck.C0 = Neck.C0:Lerp(CFrame.Angles(0, - Sideways, 0) * NeckC0, DeltaTime)
end
end

function StopAllCustomTrackExcept(track)
for i, v in pairs(CustomAnimTrack) do
if v ~= track then
v:Stop(0.2)
end
end
end

local function onRunning(speed: number)
	local speed = round(speed)

	if speed > 0 then
	if root then
	local movedir = roundV3(root.CFrame:VectorToObjectSpace(humanoid.MoveDirection))
	if mD[movedir] == "ForwardRight" then
	    StopAllCustomTrackExcept(CustomAnimTrack.RunRightAnim)
	    play(CustomAnimTrack.RunRightAnim,0.2)
	    CustomAnimTrack.RunRightAnim:AdjustSpeed(speed / 16)
	elseif mD[movedir] == "ForwardLeft" then
	    StopAllCustomTrackExcept(CustomAnimTrack.RunLeftAnim)
	    play(CustomAnimTrack.RunLeftAnim,0.2)
	    CustomAnimTrack.RunLeftAnim:AdjustSpeed(speed / 16)
	elseif mD[movedir] == "BackwardRight" then
	    StopAllCustomTrackExcept(CustomAnimTrack.RunRight2Anim)
	    play(CustomAnimTrack.RunRight2Anim,0.2)
	    CustomAnimTrack.RunRight2Anim:AdjustSpeed(speed / 16)
	elseif mD[movedir] == "BackwardLeft" then
	    StopAllCustomTrackExcept(CustomAnimTrack.RunLeft2Anim)
	    play(CustomAnimTrack.RunLeft2Anim,0.2)
	    CustomAnimTrack.RunLeft2Anim:AdjustSpeed(speed / 16)
	elseif mD[movedir] == "Backward" then
	    StopAllCustomTrackExcept(CustomAnimTrack.RunBackAnim)
	    play(CustomAnimTrack.RunBackAnim,0.2)
	    CustomAnimTrack.RunBackAnim:AdjustSpeed(speed / 16)
	else
	    play(CustomAnimTrack.RunAnim)
	    StopAllCustomTrackExcept(CustomAnimTrack.RunAnim)
	    play(CustomAnimTrack.RunAnim,0.2)
	    CustomAnimTrack.RunAnim:AdjustSpeed(speed / 16)
	end
	end

	else
		play(animationTracks.Idle,0.2)
	end
end

local function onSeated(active: boolean)
	if active then play(animationTracks.Sit) end
end

local function onSwimming(speed: number)
	local speed = round(speed)

	if speed > 2 then
		play(animationTracks.Swim)

		animationTracks.Swim:AdjustSpeed(speed / 12)
	else
		play(animationTracks.SwimIdle)
	end
end

local function onChildAdded(child: Instance)
	if child:IsA("Tool") and child:FindFirstChild("Handle") then
		animationTracks.Tool:Play(DEFAULT_FADE_TIME)

		childAddedConnection = child.ChildAdded:Connect(function(child: Instance)
			if child:IsA("StringValue") and child.Name == "toolanim" then
				if child.Value == "Slash" then
					animationTracks.Slash:Play(0)
				elseif child.Value == "Lunge" then
					animationTracks.Lunge:Play(0, 1, 6)
				end

				child:Destroy()
			end
		end)
	end
end

local function onChildRemoved(child: Instance)
	if child:IsA("Tool") and child:FindFirstChild("Handle") then
		if childAddedConnection then
			childAddedConnection:Disconnect()
			childAddedConnection = nil
		end

		animationTracks.Tool:Stop(DEFAULT_FADE_TIME)
	end
end

humanoid.Climbing:Connect(onClimbing)
humanoid.FreeFalling:Connect(onFreeFalling)
humanoid.Running:Connect(onRunning)
humanoid.Seated:Connect(onSeated)
humanoid.Swimming:Connect(onSwimming)
character.ChildAdded:Connect(onChildAdded)
character.ChildRemoved:Connect(onChildRemoved)
game:GetService("RunService").PostSimulation:Connect(onStrafing)

if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService
and TextChatService.CreateDefaultCommands
and TextChatService.CreateDefaultTextChannels
then
	local rbxEmoteCommand = Instance.new("TextChatCommand")
	rbxEmoteCommand.Name = "RBXEmoteCommand"
	rbxEmoteCommand.PrimaryAlias = "/emote"
	rbxEmoteCommand.SecondaryAlias = "/e"

	local textChatCommands = TextChatService:WaitForChild("TextChatCommands")
	textChatCommands:WaitForChild("RBXEmoteCommand"):Destroy()
	rbxEmoteCommand.Parent = textChatCommands

	local rbxSystem: TextChannel = TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXSystem")

	rbxEmoteCommand.Triggered:Connect(function(_, unfilteredText: string)
		local emote = string.split(unfilteredText, " ")[2]

		if emote == "cheer" then
			animationTracks.Cheer:Play(DEFAULT_FADE_TIME)
		elseif emote == "dance" then
			play(animationTracks.Dance)
		elseif emote == "dance2" then
			play(animationTracks.Dance2)
		elseif emote == "dance3" then
			play(animationTracks.Dance3)
		elseif emote == "laugh" then
			animationTracks.Laugh.Looped = false
			animationTracks.Laugh:Play(DEFAULT_FADE_TIME)
		elseif emote == "point" then
			animationTracks.Point.Looped = false
			animationTracks.Point:Play(DEFAULT_FADE_TIME)
		elseif emote == "wave" then
			animationTracks.Wave.Looped = false
			animationTracks.Wave:Play(DEFAULT_FADE_TIME)
		else
			rbxSystem:DisplaySystemMessage("<font color='#FF4040'>You do not own that emote.</font>")
		end
	end)
end
