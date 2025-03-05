--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Animate
-- maximum_adhd
-- September 21st, 2022
-- Edited By Zameors to support exploits
--------------------------------------------------------------------------------------------------------------------------------------------------------------------
--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer -- NOTE: nil if running on the server!
local character = CharacterAnimated
local humanoid = assert(character:FindFirstChildOfClass("Humanoid"), "No Humanoid found for the Animate script to use!")
local animator = humanoid:FindFirstChildOfClass("Animator")

if not animator then
	if RunService:IsServer() then
		animator = Instance.new("Animator")
		assert(animator).Parent = humanoid
	else
		-- Unsafe, but inherited legacy behavior.
		animator = humanoid :: any
	end
end

local defaultHipHeight = 2
local defaultFadeTime = 0.3
local smallButNotZero = 1e-4

local baseRunSpeed = 16 / 1.25
local baseWalkSpeed = 8 / 1.25

local overlapParams = OverlapParams.new()
overlapParams.FilterDescendantsInstances = { character }
overlapParams.MaxParts = 5

--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Animation Data
--------------------------------------------------------------------------------------------------------------------------------------------------------------------

type AnimDef = {
	Id: string,
	Weight: number,

	Animation: Animation?,
	Track: AnimationTrack?,
}

type AnimSet = {
	TotalWeight: number,
	[number]: AnimDef,
}

type TrackController = {
	Speed: number?,
	Weight: number?,
	FadeTime: number?,
	TimePosition: number?,
	Priority: Enum.AnimationPriority?,

	CustomSet: AnimSet,
	DefaultSet: AnimSet,

	ActiveTrack: AnimationTrack?,
}

type Locomotion = {
	Velocity: Vector2,
	Speed: number,
}

local self = {
	Animations = {} :: {
		[string]: TrackController,
	},

	Defaults = {} :: {
		[string]: { AnimDef },
	},

	Emotes = {} :: {
		[string]: boolean,
	},

	Callbacks = {} :: {
		[Enum.HumanoidStateType]: () -> (),
	},

	DidLoop = {} :: {
		[AnimationTrack]: boolean,
	},

	LocomotionMap = {} :: {
		[string]: Locomotion,
	},
}

self.Emotes = {
	wave = false,
	point = false,

	dance = true,
	dance2 = true,
	dance3 = true,

	laugh = false,
	cheer = false,
}

self.Defaults = {
	idle = {
		{ Id = "rbxassetid://507766666", Weight = 1 },
		{ Id = "rbxassetid://507766951", Weight = 1 },
		{ Id = "rbxassetid://507766388", Weight = 9 },
	},

	walk = {
		{ Id = "rbxassetid://507777826", Weight = 10 },
	},

	run = {
		{ Id = "rbxassetid://507767714", Weight = 10 },
	},

	swim = {
		{ Id = "rbxassetid://507784897", Weight = 10 },
	},

	swimidle = {
		{ Id = "rbxassetid://507785072", Weight = 10 },
	},

	jump = {
		{ Id = "rbxassetid://507765000", Weight = 10 },
	},

	fall = {
		{ Id = "rbxassetid://507767968", Weight = 10 },
	},

	climb = {
		{ Id = "rbxassetid://507765644", Weight = 10 },
	},

	sit = {
		{ Id = "rbxassetid://2506281703", Weight = 10 },
	},

	toolnone = {
		{ Id = "rbxassetid://507768375", Weight = 10 },
	},

	toolslash = {
		{ Id = "rbxassetid://522635514", Weight = 10 },
	},

	toollunge = {
		{ Id = "rbxassetid://522638767", Weight = 10 },
	},

	wave = {
		{ Id = "rbxassetid://507770239", Weight = 10 },
	},

	point = {
		{ Id = "rbxassetid://507770453", Weight = 10 },
	},

	dance = {
		{ Id = "rbxassetid://507771019", Weight = 10 },
		{ Id = "rbxassetid://507771955", Weight = 10 },
		{ Id = "rbxassetid://507772104", Weight = 10 },
	},

	dance2 = {
		{ Id = "rbxassetid://507776043", Weight = 10 },
		{ Id = "rbxassetid://507776720", Weight = 10 },
		{ Id = "rbxassetid://507776879", Weight = 10 },
	},

	dance3 = {
		{ Id = "rbxassetid://507777268", Weight = 10 },
		{ Id = "rbxassetid://507777451", Weight = 10 },
		{ Id = "rbxassetid://507777623", Weight = 10 },
	},

	laugh = {
		{ Id = "rbxassetid://507770818", Weight = 10 },
	},

	cheer = {
		{ Id = "rbxassetid://507770677", Weight = 10 },
	},
}

self.LocomotionMap = {
	run = {
		Speed = baseRunSpeed,
		Velocity = Vector2.yAxis * baseRunSpeed,
	},

	walk = {
		Speed = baseWalkSpeed,
		Velocity = Vector2.yAxis * baseWalkSpeed,
	},
}

--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function newAnimSet(): AnimSet
	return { TotalWeight = 0 }
end

local function signedAngle(a: Vector2, b: Vector2)
	return -math.atan2(a.X * b.Y - a.Y * b.X, a.X * b.X + a.Y * b.Y)
end

local function registerCallback(stateType: Enum.HumanoidStateType, callback: () -> ())
	self.Callbacks[stateType] = callback
end

local function getTrackController(name: string): TrackController
	local controller = self.Animations[name]
	return assert(controller, "Unknown animation name: " .. tostring(name))
end

local function getNumber(object: Instance, key: string): number?
	local valueObject = object:FindFirstChild(key)

	if valueObject and valueObject:IsA("NumberValue") then
		return valueObject.Value
	end

	local attribute = object:GetAttribute(key)

	if typeof(attribute) == "number" then
		return attribute
	end

	return nil
end

local function getHeightScale(): number
	if not humanoid.AutomaticScalingEnabled then
		return 1
	end

	local dampening = getNumber(script, "ScaleDampeningPercent")

	if dampening then
		return 1 + (humanoid.HipHeight - defaultHipHeight) * dampening / defaultHipHeight
	else
		return humanoid.HipHeight / defaultHipHeight
	end
end

local function getTimePosition(controller: TrackController): number?
	local track = controller.ActiveTrack

	if track and track.IsPlaying and track.WeightTarget > smallButNotZero then
		return track.TimePosition
	end

	return
end

local function loadAnimation(animDef: AnimDef): AnimationTrack
	if not animDef.Track then
		local anim = animDef.Animation

		if anim == nil then
			anim = Instance.new("Animation")
			assert(anim)

			anim.AnimationId = assert(animDef.Id)
			animDef.Animation = anim
		end

		-- Debug flag to use the Humanoid for loading animations
		-- so NetworkSettings.ShowActiveAnimationAsset works.
		-- TODO: That should just work with Animator...?

		local animator: Animator = if script:GetAttribute("DebugHumanoidLoadAnimation")
			then humanoid :: any
			else animator

		local track = animator:LoadAnimation(assert(anim))
		track.Priority = Enum.AnimationPriority.Core

		track.DidLoop:Connect(function()
			self.DidLoop[track] = true
		end)

		animDef.Track = track
	end

	return assert(animDef.Track)
end

local function getAnimSetForAnimation(customAnim: Animation): (AnimSet?, string?)
	local set = customAnim.Parent

	if set and set:IsA("StringValue") then
		if set.Parent ~= script then
			return
		end

		local id = set.Name
		local controller = self.Animations[id]

		if not controller then
			controller = {
				DefaultSet = newAnimSet(),
				CustomSet = newAnimSet(),
			}

			self.Animations[id] = controller
		end

		return controller.CustomSet, id
	end

	return
end

local function rollAnimation(controller: TrackController): (AnimationTrack?, boolean?)
	local animSet = if #controller.CustomSet == 0
		then controller.DefaultSet
		else controller.CustomSet

	if #animSet == 1 then
		local first = animSet[1]
		return loadAnimation(first), false
	elseif #animSet == 0 then
		return nil, nil
	end

	local totalWeight = assert(animSet.TotalWeight)
	local roll = math.random() * totalWeight

	local currWeight = 0
	local currAnim = 1

	while currWeight < totalWeight do
		local animDef = assert(animSet[currAnim])
		local nextWeight = currWeight + animDef.Weight

		if roll >= currWeight and roll < nextWeight then
			return loadAnimation(animDef), true
		end

		currAnim += 1
		currWeight = nextWeight
	end

	return nil, nil
end

local function canEmote()
	local moveDir = humanoid.MoveDirection
	local state = humanoid:GetState()

	if moveDir ~= Vector3.zero then
		return false
	end

	if state ~= Enum.HumanoidStateType.Running then
		return false
	end

	return true
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Animation Set Registration
--------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function checkAnimationAdded(anim: Instance)
	if anim:IsA("Animation") then
		local animSet, setId = getAnimSetForAnimation(anim)

		if animSet then
			local linearVelocity = anim:GetAttribute("LinearVelocity")
			local weight = getNumber(anim, "Weight") or 1

			local animDef: AnimDef = {
				Id = anim.AnimationId,
				Animation = anim,
				Weight = weight,
			}

			animSet.TotalWeight += weight
			loadAnimation(animDef)

			if setId and typeof(linearVelocity) == "Vector2" then
				self.LocomotionMap[setId] = {
					Velocity = linearVelocity,
					Speed = linearVelocity.Magnitude,
				}
			end

			table.insert(animSet, animDef)
		end
	end
end

local function checkAnimationRemoving(anim: Instance)
	if anim:IsA("Animation") then
		local animSet = getAnimSetForAnimation(anim)

		if animSet then
			local dropIndex: number?

			for i, animDef in ipairs(animSet) do
				if animDef.Animation == anim then
					animSet.TotalWeight -= animDef.Weight
					dropIndex = i
					break
				end
			end

			if dropIndex then
				table.remove(animSet, dropIndex)
			end
		end
	end
end

-- Register default animations
for id, animDefs in self.Defaults do
	local default = newAnimSet()

	for i, animDef in animDefs do
		default.TotalWeight += animDef.Weight
		table.insert(default, animDef)
		loadAnimation(animDef)
	end

	self.Animations[id] = {
		DefaultSet = default,
		CustomSet = newAnimSet(),
	}
end

-- Register custom animations
for i, desc: Instance in script:GetDescendants() do
	checkAnimationAdded(desc)
end

script.DescendantAdded:Connect(checkAnimationAdded)
script.DescendantRemoving:Connect(checkAnimationRemoving)

--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Humanoid State Callbacks
--------------------------------------------------------------------------------------------------------------------------------------------------------------------

local normalizedWalkSpeed = 0.5
local normalizedRunSpeed = 1

local toolAnimEvent: string?
local currentEmote: string?

local jumpAnimTime = 0
local toolAnimTime = 0

local function onJumping()
	jumpAnimTime = os.clock() + 0.4
end

local function onFreefall()
	local now = os.clock()

	local target = if now < jumpAnimTime
		then getTrackController("jump")
		else getTrackController("fall")

	target.Weight = 1
	target.FadeTime = 0.1
end

local function onSeated()
	local sit = getTrackController("sit")
	sit.FadeTime = 0.4
	sit.Weight = 1
	sit.Speed = 0
end

local function onClimbing()
	local rootPart = humanoid.RootPart
	local speed = 0

	if rootPart then
		local velocity = rootPart.AssemblyLinearVelocity
		speed = velocity.Y / 5
	end

	local climb = getTrackController("climb")
	climb.Speed = speed
	climb.Weight = 1
end

local function onSwimming()
	local rootPart = humanoid.RootPart
	local speed: number = 0

	if rootPart then
		local velocity = rootPart.AssemblyLinearVelocity
		speed = velocity.Magnitude
	end

	local swim = getTrackController("swim")
	swim.FadeTime = 0.4

	local swimIdle = getTrackController("swimidle")
	swimIdle.FadeTime = 0.4

	if speed > 1 then
		swim.Speed = speed / 10
		swim.Weight = 1
	else
		swimIdle.Weight = 1
	end
end

local function onRunning()
	local rootPart = humanoid.RootPart
	local strafe = Vector2.zero
	local speed = 0

	if rootPart then
		local rootHeight = rootPart.Size.Y / 2
		local hipHeight = humanoid.HipHeight

		local floorOffset = Vector3.yAxis * (hipHeight + rootHeight)
		local floor = rootPart.Position - floorOffset

		local parts = workspace:GetPartBoundsInRadius(floor, 1, overlapParams)
		local velocity = rootPart.AssemblyLinearVelocity
		local compensated = {}

		for i, part in parts do
			local root = assert(if part:IsA("BasePart")
				then part.AssemblyRootPart
				else nil)

			if not compensated[root] then
				velocity -= root:GetVelocityAtPosition(floor)
				compensated[root] = true
			end
		end

		local cf = rootPart.CFrame
		local strafeX = cf.RightVector:Dot(velocity)
		local strafeY = cf.LookVector:Dot(velocity)

		strafe = Vector2.new(strafeX, strafeY)
		speed = strafe.Magnitude
	end

	local heightScale = getHeightScale()
	local runSpeed = (speed / baseRunSpeed) / heightScale

	if speed > heightScale / 2 then
		local fadeInRun = (runSpeed - normalizedWalkSpeed) / (normalizedRunSpeed - normalizedWalkSpeed)

		local runAnimSpeed = math.max(1, math.log(fadeInRun + 1))
		local runAnimWeight = math.clamp(fadeInRun, smallButNotZero, 1)

		local walkAnimWeight = math.clamp(if runAnimWeight == smallButNotZero
			then runSpeed / normalizedWalkSpeed 
			else 1 - fadeInRun,
			smallButNotZero,
			1
		)

		local activeMotion = {}
		local lower, upper = false, false

		local loX, loY = false, false
		local upX, upY = false, false

		for id, locomotion in self.LocomotionMap do
			local vel = locomotion.Velocity

			if strafe:Dot(vel) > 0 then
				activeMotion[id] = locomotion
			end

			if not lower then
				loX = loX or vel.X < 0
				loY = loY or vel.Y < 0
				lower = loX and loY
			end

			if not upper then
				upX = upX or vel.X > 0
				upY = upY or vel.Y > 0
				upper = upX and upY
			end
		end

		if lower and upper then
			local timePos = 0

			local runWeights = {}
			local runTotalWeight = 0

			local walkWeights = {}
			local walkTotalWeight = 0

			for id, motion in activeMotion do
				local vel = motion.Velocity
				local angle = signedAngle(strafe, vel)

				local weight = math.clamp(1 - math.abs(angle), 0, 1)
				local motionSpeed = motion.Speed

				local runDist = math.abs(motionSpeed - baseRunSpeed)
				local walkDist = math.abs(motionSpeed - baseWalkSpeed)

				if runDist < walkDist then
					runWeights[id] = weight
					runTotalWeight += weight
				else
					walkWeights[id] = weight
					walkTotalWeight += weight
				end

				local controller = getTrackController(id)
				local trackTimePos = getTimePosition(controller)

				if trackTimePos then
					timePos = math.max(timePos, trackTimePos)
				end
			end

			for runId, runWeight in runWeights do
				local run = getTrackController(runId)
				local weight = (runWeight / runTotalWeight) * runAnimWeight

				run.Weight = math.clamp(weight, smallButNotZero, 1)
				run.TimePosition = timePos
				run.Speed = runAnimSpeed
			end

			for walkId, walkWeight in walkWeights do
				local walk = getTrackController(walkId)
				local weight = (walkWeight / walkTotalWeight) * walkAnimWeight

				walk.Weight = math.clamp(weight, smallButNotZero, 1)
				walk.TimePosition = timePos
			end
		else
			-- Not all quadrants of motion represented!
			-- Fallback to legacy run/walk behavior.

			local run = getTrackController("run")
			run.Weight = runAnimWeight
			run.Speed = runAnimSpeed

			local walk = getTrackController("walk")
			walk.Weight = walkAnimWeight
		end
	else
		local idle = getTrackController("idle")
		idle.Weight = 1
	end
end

local function onPlayEmote(anim: Animation)
	if typeof(anim) ~= "Instance" then
		return false
	end

	if not anim:IsA("Animation") then
		return false
	end

	if not canEmote() then
		return false
	end

	local assetId: string? = anim.AnimationId:match("%d+$")

	if not assetId then
		return false
	end

	local emoteId = "emote_" .. assert(assetId)
	local emote = self.Animations[emoteId]

	if emote == nil then
		emote = {
			DefaultSet = newAnimSet(),
			CustomSet = newAnimSet(),
		}

		table.insert(emote.DefaultSet, {
			Id = "rbxassetid://" .. assetId,
			Animation = anim,
			Weight = 1,
		})

		self.Animations[emoteId] = emote
	end

	currentEmote = emoteId
	return true
end

local function onChatted(msg: string)
	local emote

	if msg:sub(1, 3) == "/e " then
		emote = msg:sub(4)
	elseif msg:sub(1, 7) == "/emote " then
		emote = msg:sub(8)
	end

	if self.Emotes[emote] ~= nil and canEmote() then
		currentEmote = emote
	end
end

-- Jumping is fast, listen directly!
humanoid.Jumping:Connect(onJumping)

if player then
	-- Listen for emote chat messages.
	player.Chatted:Connect(onChatted)
end

task.spawn(function()
	-- PlayEmote is dispatched via BindableFunction.
	local playEmote = script:WaitForChild("PlayEmote", math.huge)

	if playEmote and playEmote:IsA("BindableFunction") then
		playEmote.OnInvoke = onPlayEmote
	end
end)

-- Register everything else as a state update callback.
registerCallback(Enum.HumanoidStateType.Seated, onSeated)
registerCallback(Enum.HumanoidStateType.Running, onRunning)
registerCallback(Enum.HumanoidStateType.Climbing, onClimbing)
registerCallback(Enum.HumanoidStateType.Freefall, onFreefall)
registerCallback(Enum.HumanoidStateType.Swimming, onSwimming)

--------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Runtime Logic
--------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Clear any existing animation tracks
-- Fixes issue with characters that are moved in and out of the Workspace accumulating tracks

assert(animator)

for i, track: AnimationTrack in animator:GetPlayingAnimationTracks() do
	track:Stop(0)
	track:Destroy()
end

local function updateToolAnimation(tool: Tool)
	local now = os.clock()
	local targetAnim = "toolnone"
	local toolanim = tool:FindFirstChild("toolanim")

	if toolanim and toolanim:IsA("StringValue") then
		toolAnimEvent = toolanim.Value
		toolAnimTime = now + 0.3
		toolanim.Parent = nil
	end

	if now < toolAnimTime then
		if toolAnimEvent == "Slash" then
			targetAnim = "toolslash"
		elseif toolAnimEvent == "Lunge" and not humanoid.Sit then
			targetAnim = "toollunge"
		end
	elseif toolAnimEvent then
		toolAnimEvent = nil
	end

	local toolControl = getTrackController(targetAnim)
	toolControl.Priority = Enum.AnimationPriority.Action
	toolControl.FadeTime = 0.1
	toolControl.Weight = 1
end

local function updateAnimations()
	local tool = character:FindFirstChildWhichIsA("Tool")

	if tool and tool.RequiresHandle then
		updateToolAnimation(tool)
	end

	if currentEmote and canEmote() then
		local emote = getTrackController(currentEmote)
		emote.Weight = 1
	else
		local state = humanoid:GetState()
		local callback = self.Callbacks[state]

		if callback then
			callback()
		end

		currentEmote = nil
	end

	for id, controller in self.Animations do
		local speed = controller.Speed
		local weight = controller.Weight
		local fadeTime = controller.FadeTime
		local track = controller.ActiveTrack

		if speed or weight then
			local validTrack = if track
				then track.IsPlaying
				else false

			local newTrack: AnimationTrack?
			local rollable: boolean?

			if validTrack and track and self.DidLoop[track] then
				newTrack, rollable = rollAnimation(controller)

				if rollable then
					validTrack = false
				end

				self.DidLoop[track] = nil
			end

			if not validTrack then
				if track and track ~= newTrack then
					track:Stop(fadeTime or defaultFadeTime)
				end

				track = newTrack or rollAnimation(controller)
				controller.ActiveTrack = track
			end

			if not track then
				continue
			end

			local timePos = controller.TimePosition
			assert(track)

			if track.IsPlaying then
				local priority = controller.Priority

				if weight then
					controller.Weight = nil

					if weight == smallButNotZero and track.WeightTarget ~= smallButNotZero then
						track:AdjustWeight(smallButNotZero, fadeTime or defaultFadeTime)
					elseif math.abs(weight - track.WeightTarget) > 0.01 then
						track:AdjustWeight(weight, fadeTime or defaultFadeTime)
					end
				end

				if speed then
					controller.Speed = nil

					if math.abs(speed - track.Speed) > 0.01 and track.WeightTarget > smallButNotZero then
						track:AdjustSpeed(speed)
					end
				end

				if priority then
					track.Priority = priority
					controller.Priority = nil
				end

				if timePos then
					track.TimePosition = timePos
				end
			else
				track:Play(fadeTime or defaultFadeTime, weight or 1, speed or 1)
				track.TimePosition = timePos or 0
			end

			if timePos then
				controller.TimePosition = nil
			end
		elseif track and track.IsPlaying then
			track:Stop(fadeTime or defaultFadeTime)
		end

		if fadeTime then
			controller.FadeTime = nil
		end
	end
end

RunService.Heartbeat:Connect(updateAnimations)

--------------------------------------------------------------------------------------------------------------------------------------------------------------------
