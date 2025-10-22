--[[
	@ Módulo Movement
	@ Autor: Gemini & <Seu Nome>
	@ Data: 12/10/2025
	
	Este módulo gerencia todo o movimento dos monstros, incluindo o novo sistema
	de "Guide Part" para um seguimento mais dinâmico e suave.
--]]

local Movement = {}

local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")

local activeGuides = {} -- Armazena os dados das "Guide Parts" ativas. Chave: Model do Monstro.
local facingLoops = {} -- Armazena os loops de facing ativos
local originalWalkSpeeds = {} -- Armazena WalkSpeeds originais

local ORBIT_RADIUS = 8 -- Distância que o monstro tentará manter do jogador.
local ORBIT_HEIGHT = 2 -- Altura da parte guia em relação à cabeça do jogador.
local SMOOTH_FACTOR = 0.08 -- Quão rápido a órbita se ajusta. Menor = mais suave.
local IDLE_DISTANCE_OFFSET = 5 -- Distância que o monstro mantém do jogador parado.

local COMBAT_ORBIT_RADIUS = 6 -- Distância menor para combate
local COMBAT_ORBIT_HEIGHT = 3
local COMBAT_SMOOTH_FACTOR = 0.1 -- Mais rápido para combate

-- Função auxiliar para criar Guide Part
-- Update createGuidePart to be more persistent:
local function createGuidePart()
	local guidePart = Instance.new("Part")
	guidePart.Name = "MovementGuidePart_" .. tick() -- Unique name
	guidePart.Size = Vector3.new(1, 1, 1)
	guidePart.Transparency = 1
	guidePart.CanCollide = false
	guidePart.Anchored = true
	guidePart.Parent = workspace:FindFirstChild("MovementGuides") or workspace

	-- Add a tag to identify it
	guidePart:SetAttribute("IsMovementGuide", true)

	print("Created guide part: " .. guidePart.Name)
	return guidePart
end

-- Store original walk speed
local function storeOriginalWalkSpeed(monster)
	local humanoid = monster:FindFirstChildOfClass("Humanoid")
	if humanoid and not originalWalkSpeeds[monster] then
		originalWalkSpeeds[monster] = humanoid.WalkSpeed
	end
end

-- Restore original walk speed
local function restoreOriginalWalkSpeed(monster)
	local humanoid = monster:FindFirstChildOfClass("Humanoid")
	if humanoid and originalWalkSpeeds[monster] then
		humanoid.WalkSpeed = originalWalkSpeeds[monster]
		originalWalkSpeeds[monster] = nil
	end
end

-- Função principal para obter ou criar Guide Part
local function getOrCreateGuidePart(monster, target, isCombat)
	-- First, check if we already have a valid guide part
	if activeGuides[monster] and activeGuides[monster].part and activeGuides[monster].part.Parent then
		activeGuides[monster].target = target
		activeGuides[monster].isCombat = isCombat or false
		return activeGuides[monster].part
	end

	-- If guide part exists but was destroyed, clean it up
	if activeGuides[monster] and activeGuides[monster].part and not activeGuides[monster].part.Parent then
		activeGuides[monster].part = nil
	end

	-- Create new guide part
	local guidePart = createGuidePart()

	activeGuides[monster] = {
		part = guidePart,
		target = target,
		monster = monster,
		isCombat = isCombat or false,
		currentAngle = 0,
		orbitRadius = isCombat and COMBAT_ORBIT_RADIUS or ORBIT_RADIUS,
		orbitHeight = isCombat and COMBAT_ORBIT_HEIGHT or ORBIT_HEIGHT,
		smoothFactor = isCombat and COMBAT_SMOOTH_FACTOR or SMOOTH_FACTOR
	}

	-- Store original walk speed
	storeOriginalWalkSpeed(monster)

	print("Created new guide part for " .. monster.Name)
	return guidePart
end

-- Update the StopFollowing function to not destroy the guide part unnecessarily:
function Movement.StopFollowing(monster)
	if not monster or not activeGuides[monster] then return end

	-- Only destroy the guide part if we're explicitly stopping movement
	-- Don't destroy it during normal state transitions
	--if activeGuides[monster].part then
	--	-- Only destroy if we're truly stopping all movement
	--	activeGuides[monster].part:Destroy()
	--end

	-- Restore walk speed
	restoreOriginalWalkSpeed(monster)

	activeGuides[monster] = nil
	print("Stopped following for " .. monster.Name)
end

-- Função para atualizar posição do Guide Part
function Movement.StartCombatMovement(monster, target, isCombat)
	if not monster or not target then return end

	-- For player monsters, use the guide system
	if monster:GetAttribute("OwnerId") then
		Movement.StartFollowing(monster, target, isCombat)
	else
		-- For enemy monsters, use direct movement
		local humanoid = monster:FindFirstChildOfClass("Humanoid")
		if humanoid then
			-- Simple direct movement towards target
			local targetPosition = target.PrimaryPart.Position
			humanoid:MoveTo(targetPosition)
		end
	end
end

-- NEW: Enhanced guide system with arena awareness
local function updateGuidePosition(guideData, dt)
	if not guideData.target or not guideData.target.Parent then return end
	if not guideData.monster or not guideData.monster.Parent then return end

	local targetHead = guideData.target:FindFirstChild("Head") or guideData.target.PrimaryPart
	if not targetHead then return end

	-- Check if we're in an arena and adjust movement accordingly
	local arenaId = guideData.monster:GetAttribute("InArena")
	local arenaData = arenaId and _G.COMBAT_ARENA and _G.COMBAT_ARENA.GetArena(arenaId)

	if guideData.isCombat then
		local targetToMonsterVec = (guideData.monster.PrimaryPart.Position - targetHead.Position) * Vector3.new(1, 0, 1)
		local targetLookVec = targetHead.CFrame.LookVector * Vector3.new(1, 0, 1)
		local targetAngleRad = math.atan2(targetToMonsterVec.X, targetToMonsterVec.Z) - math.atan2(targetLookVec.X, targetLookVec.Z)

		guideData.currentAngle = guideData.currentAngle + (math.deg(targetAngleRad) - guideData.currentAngle) * guideData.smoothFactor

		local desiredPosition = targetHead.CFrame * CFrame.Angles(0, math.rad(guideData.currentAngle), 0) * CFrame.new(0, guideData.orbitHeight, -guideData.orbitRadius)

		-- Apply arena constraints if in arena
		if arenaData then
			if not _G.COMBAT_ARENA.IsInArenaBounds(desiredPosition.Position, arenaData.center, arenaData.radius, arenaData.height) then
				desiredPosition = CFrame.new(_G.COMBAT_ARENA.GetCorrectedPosition(desiredPosition.Position, arenaData.center, arenaData.radius, arenaData.height))
			end
		end

		guideData.part.CFrame = desiredPosition
	else
		-- Lógica original para seguimento normal
		local targetHumanoid = guideData.target:FindFirstChildOfClass("Humanoid")
		local isTargetIdle = not targetHumanoid or targetHumanoid.MoveDirection.Magnitude < 0.1

		if isTargetIdle then
			guideData.part.CFrame = targetHead.CFrame * CFrame.new(0, 0, IDLE_DISTANCE_OFFSET)
		else
			local targetToMonsterVec = (guideData.monster.PrimaryPart.Position - targetHead.Position) * Vector3.new(1, 0, 1)
			local targetLookVec = targetHead.CFrame.LookVector * Vector3.new(1, 0, 1)
			local targetAngleRad = math.atan2(targetToMonsterVec.X, targetToMonsterVec.Z) - math.atan2(targetLookVec.X, targetLookVec.Z)

			guideData.currentAngle = guideData.currentAngle + (math.deg(targetAngleRad) - guideData.currentAngle) * guideData.smoothFactor

			guideData.part.CFrame = targetHead.CFrame
				* CFrame.Angles(0, math.rad(guideData.currentAngle), 0)
				* CFrame.new(0, guideData.orbitHeight, -guideData.orbitRadius)
		end
	end
end

-- Loop principal de atualização
local function isTargetInArena(monster, targetPosition)
	if not _G.COMBAT_ARENA then return true end

	local arenaId = monster:GetAttribute("InArena")
	if not arenaId then return true end

	local arenaData = _G.COMBAT_ARENA.GetArena(arenaId)
	if not arenaData then return true end

	local horizontalDistance = (Vector3.new(targetPosition.X, 0, targetPosition.Z) - Vector3.new(arenaData.center.X, 0, arenaData.center.Z)).Magnitude
	local verticalDistance = math.abs(targetPosition.Y - arenaData.center.Y)

	return horizontalDistance <= arenaData.radius and verticalDistance <= arenaData.height/2
end

-- FIXED: Improved state checking
local function isInCombatState(monster)
	if not _G.STATES then return false end
	-- Only the explicit InCombat state should block Following
	return _G.STATES:IsInState(monster, "InCombat")
end

-- Modify the updateGuideMovement function to respect arena bounds:
local function updateGuideMovement(dt)
	for monster, guideData in pairs(activeGuides) do
		if not monster or not monster.Parent then
			Movement.StopFollowing(monster)
			continue
		end

		-- CRITICAL FIX: Recreate guide part if it was destroyed
		if not guideData.part or not guideData.part.Parent then
			print("Guide part missing for " .. monster.Name .. ", recreating...")
			guideData.part = createGuidePart()

			-- Re-initialize guide data
			if guideData.target and guideData.target.Parent then
				guideData.currentAngle = 0
			else
				-- Target is gone, stop following
				Movement.StopFollowing(monster)
				continue
			end
		end

		-- Update reference
		guideData.monster = monster

		-- Rest of the update logic remains the same...
		local isInCombat = isInCombatState(monster)

		-- Update combat parameters if state changed
		if isInCombat and not guideData.isCombat then
			guideData.isCombat = true
			guideData.orbitRadius = COMBAT_ORBIT_RADIUS
			guideData.orbitHeight = COMBAT_ORBIT_HEIGHT
			guideData.smoothFactor = COMBAT_SMOOTH_FACTOR
		elseif not isInCombat and guideData.isCombat then
			guideData.isCombat = false
			guideData.orbitRadius = ORBIT_RADIUS
			guideData.orbitHeight = ORBIT_HEIGHT
			guideData.smoothFactor = SMOOTH_FACTOR
		end

		updateGuidePosition(guideData, dt)

		-- Movement logic...
		local humanoid = monster:FindFirstChildOfClass("Humanoid")

		-- CRITICAL FIX: Only move to the guide part if the monster is
		-- explicitly in the "Following" state and not stunned.
		if humanoid and _G.STATES:IsInState(monster, "Following") and not _G.STATES:IsStunned(monster) then
			humanoid:MoveTo(guideData.part.Position)
		end
	end
end

-- FIXED: Simple and reliable facing function
function Movement.FaceTargetDuring(monster, target, duration)
	if not monster or not target then return end

	-- Stop any existing facing
	Movement.StopFacing(monster)

	local hrp = monster:FindFirstChild("HumanoidRootPart")
	local targetHrp = target:FindFirstChild("HumanoidRootPart")

	if not hrp or not targetHrp then return end

	local connection
	local startTime = tick()

	connection = RunService.Heartbeat:Connect(function()
		if not monster.Parent or not target.Parent then
			connection:Disconnect()
			return
		end

		if tick() - startTime >= duration then
			connection:Disconnect()
			return
		end

		-- Simple and direct facing
		local monsterPos = hrp.Position
		local targetPos = targetHrp.Position

		-- Only rotate on Y axis
		local lookAt = CFrame.lookAt(
			monsterPos,
			Vector3.new(targetPos.X, monsterPos.Y, targetPos.Z)
		)

		hrp.CFrame = lookAt
	end)

	-- Store the connection for cleanup
	facingLoops[monster] = connection

	-- Auto cleanup after duration
	task.delay(duration, function()
		if connection.Connected then
			connection:Disconnect()
		end
		facingLoops[monster] = nil
	end)
end

-- Stop facing for a monster
function Movement.StopFacing(monster)
	local connection = facingLoops[monster]
	if connection then
		connection:Disconnect()
		facingLoops[monster] = nil
	end
end

function Movement.StartFollowing(monster, target, isCombat)
	if not monster or not target then return end

	-- Use improved state checking
	if isInCombatState(monster) and not isCombat then
		return
	end

	getOrCreateGuidePart(monster, target, isCombat)
end


function Movement.ChangeTarget(monster, newTarget, isCombat)
	if not monster or not activeGuides[monster] then return end

	activeGuides[monster].target = newTarget
	activeGuides[monster].isCombat = isCombat or false
end

function Movement.GetGuideData(monster)
	return activeGuides[monster]
end

-- Aproxima até entrar no "desiredRange" (>= minRange do golpe)
function Movement.StartCombatChase(attacker, target, desiredRange)
	if not attacker or not target or not attacker.Parent or not target.Parent then return end
	local hrpA = attacker:FindFirstChild("HumanoidRootPart")
	local hrpT = target:FindFirstChild("HumanoidRootPart")
	local humA = attacker:FindFirstChildOfClass("Humanoid")
	if not (hrpA and hrpT and humA) then return end

	desiredRange = desiredRange or 6
	local dir = (hrpT.Position - hrpA.Position)
	local dist = dir.Magnitude
	local goal = hrpT.Position

	-- Para fora do "ponto alvo": para na borda do desiredRange
	if dist > desiredRange + 0.5 then
		local unit = dir.Unit
		goal = hrpT.Position - unit * (desiredRange * 0.8)
	end

	humA:MoveTo(goal)
end

-- Recuo direto do alvo por "distance"
function Movement.RetreatFrom(attacker, target, distance)
	if not attacker or not target then return end
	distance = distance or 12
	local hrpA = attacker:FindFirstChild("HumanoidRootPart")
	local hrpT = target:FindFirstChild("HumanoidRootPart")
	local humA = attacker:FindFirstChildOfClass("Humanoid")
	if not (hrpA and hrpT and humA) then return end

	local away = (hrpA.Position - hrpT.Position).Unit
	humA:MoveTo(hrpA.Position + away * distance)
end

-- Strafe/Reposicionar — orbita lateralmente mantendo raio aproximado
function Movement.StrafeAround(attacker, target, radius)
	if not attacker or not target then return end
	radius = radius or 10
	local hrpA = attacker:FindFirstChild("HumanoidRootPart")
	local hrpT = target:FindFirstChild("HumanoidRootPart")
	local humA = attacker:FindFirstChildOfClass("Humanoid")
	if not (hrpA and hrpT and humA) then return end

	local toTarget = (hrpT.Position - hrpA.Position)
	local side = toTarget:Cross(Vector3.new(0,1,0)).Unit
	if math.random() > 0.5 then side = -side end

	local goal = hrpT.Position + side * radius
	humA:MoveTo(goal)
end

-- Parar movimentação de combate
function Movement.StopCombatMovement(attacker)
	if not attacker then return end
	local humA = attacker:FindFirstChildOfClass("Humanoid")
	if humA then
		humA:MoveTo(attacker.PrimaryPart and attacker.PrimaryPart.Position or attacker:GetPivot().Position)
	end
end

-- NEW: Force restore walk speed (for CombatManager to call)
function Movement.ForceRestoreWalkSpeed(monster)
	restoreOriginalWalkSpeed(monster)
end

-- Conecta o loop de atualização
RunService.Heartbeat:Connect(updateGuideMovement)

return Movement