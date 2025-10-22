--BoulderCarry.lua

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Utils = require(script.Parent.Parent.Utils)
local AnimationHandler = require(SSS.Main:WaitForChild("AnimationHandler"))

local Training = {}
Training.Name = "BoulderCarry"
Training.Duration = 20
Training.BaseBonus = { Defense = 2 }

-- util: garantir Animator + parar quaisquer animações tocando
local function stopAllAnimations(model: Model)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		pcall(function() track:Stop(0.05) end)
	end
end

-- pega a anima "[RaceName] Death"
local function getDeathAnimationId(monster: Model)
	local race = monster:GetAttribute("Race")
	if not race then return nil end
	local assets = RS:FindFirstChild("Assets")
	local animRoot = assets and assets:FindFirstChild("Animations")
	if not animRoot then return nil end
	local raceFolder = animRoot:FindFirstChild(race)
	if not raceFolder then
		for _, f in ipairs(animRoot:GetChildren()) do
			if f:IsA("Folder") and f.Name:lower() == tostring(race):lower() then
				raceFolder = f; break
			end
		end
	end
	if not raceFolder then return nil end
	for _, a in ipairs(raceFolder:GetChildren()) do
		if a:IsA("Animation") and a.Name:lower():find("death") then
			return a.AnimationId
		end
	end
	return nil
end

-- util para extrair índice numérico de "Node1", "Node2", "Node10", etc.
local function nodeIndex(part: BasePart)
	local n = tonumber(string.match(part.Name or "", "(%d+)$"))
	return n or math.huge
end

-- calcula fração [0..1] percorrida do startPos até targetPos
local function travelFraction(current: Vector3, startPos: Vector3, targetPos: Vector3)
	local total = (targetPos - startPos).Magnitude
	if total <= 0.001 then return 1 end
	local done = (current - startPos).Magnitude
	return math.clamp(done / total, 0, 1)
end

-- falha no meio: para tudo, anima, teleporta, reseta boulder
local function handleFailure(monster: Model, ctx, rope: RopeConstraint?, boulderModel: Model, boulderBase: BasePart?, originalPivot: CFrame, originalAnchored: table)
	-- 1) parar movemento imediatamente
	local hum = monster:FindFirstChildOfClass("Humanoid")
	local root = monster.HumanoidRootPart
	_G.EFFECTS.PlaySound("Fail", {Where = root})

	local prevWalkSpeed
	if hum then
		prevWalkSpeed = hum.WalkSpeed
		hum:MoveTo(root and root.Position or monster:GetPivot().Position)
		hum.WalkSpeed = 0
		hum.AutoRotate = false
	end

	-- 2) limpa animações pendentes antes de tocar a de falha
	stopAllAnimations(monster)

	-- 3) solta rope e deixa a boulder “deslizar”
	Utils.DetachRope(monster)
	if boulderBase then
		boulderBase.Anchored = false
	end
	local ownerId = monster:GetAttribute("OwnerId")
	local remotes = RS:WaitForChild("Remotes")
	local EvFail = remotes:WaitForChild("TrainingCameraFail")

	-- Duração pretendida = duração estimada da anima (com fallback) + delay de quase-sucesso
	local estimatedLen = 1.2
	local deathId = getDeathAnimationId(monster)
	if deathId then
		-- vamos pedir p/ cliente rodar a cine por ~estimatedLen + delay
	end
	local delayAfterAnim = (ctx and tonumber(ctx.FailTeleportDelay)) or 0.35
	local runFor = estimatedLen + delayAfterAnim

	EvFail:FireClient(Players:GetPlayerByUserId(ownerId), monster, {
		mode = "death",
		duration = runFor,         -- quanto tempo a órbita/zoom dura
		radiusStart = 12,          -- raio inicial da órbita
		radiusEnd   = 9,           -- zoom leve (raio diminui)
		heightStart = 6,           -- altura inicial
		heightEnd   = 7.5,         -- sobe um pouco
		angularSpeedDeg = 55,      -- graus/seg para girar
		fovStart = 70,             -- FOV inicial
		fovEnd   = 62,             -- FOV final (zoom leve)
		easeTime = 0.25,           -- tween inicial
	})

	---- Agora toca a anima (bloqueante)
	--local animLen = 0
	--if deathId then
	--	animLen = AnimationHandler:PlayCastOnce(monster, deathId, { fallback = estimatedLen, replace = true })
	--else
	--	task.wait(estimatedLen)
	--end

	---- pequeno delay “quase sucesso”
	--task.wait(delayAfterAnim)

	

	-- 4) toca anima “Death” e espera terminar
	local deathId = getDeathAnimationId(monster)
	if deathId then
		AnimationHandler:PlayCastOnce(monster, deathId, { fallback = 1.2, replace = true })
	end

	-- 5) pequeno delay “quase sucesso” antes do teleport
	task.wait((ctx and tonumber(ctx.FailTeleportDelay)) or 0.35)

	-- 6) teleporta de volta (Start > dono)
	local ownerId = monster:GetAttribute("OwnerId")
	if ctx and ctx.Start and monster.PrimaryPart then
		monster:PivotTo(ctx.Start.CFrame + Vector3.new(0, 2, 0))
	elseif _G.FUNCTIONS and _G.FUNCTIONS.teleportToOwner then
		_G.FUNCTIONS:teleportToOwner(monster, ownerId)
	end

	-- 7) reseta boulder ao pivot original (fim do treino por falha)
	if originalAnchored and originalPivot and boulderModel then
		for part, _ in pairs(originalAnchored) do
			if part and part:IsA("BasePart") then
				part.AssemblyLinearVelocity = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero
				part.Anchored = true
			end
		end
		boulderModel:PivotTo(originalPivot)
		for part, wasAnchored in pairs(originalAnchored) do
			if part and part:IsA("BasePart") then
				part.Anchored = wasAnchored
			end
		end
	end

	-- 8) segurança: para qualquer track e libera movimento
	stopAllAnimations(monster)
	if hum then
		hum.WalkSpeed = prevWalkSpeed or 16
		hum.AutoRotate = true
	end

	return { success = false, reason = "boulder_mid_fail" }
end

-- ctx: { Start = BasePart, End = BasePart, NodesFolder = Folder, Boulder = Model, FailTeleportDelay? = number }
function Training:Start(monster: Model, player: Player, ctx)
	assert(ctx and ctx.Boulder and ctx.NodesFolder, "BoulderCarry: missing Boulder/NodesFolder in ctx")

	-- limpa qualquer anima pendente da tentativa anterior
	stopAllAnimations(monster)

	-- Teleporta para o Start se existir
	if ctx.Start and monster.PrimaryPart then
		monster:PivotTo	(ctx.Start.CFrame + Vector3.new(0, 2, 0))
	end

	-- Captura pivot/anchor originais (para resetar no fim — sucesso ou falha)
	local originalPivot = ctx.Boulder:GetPivot()
	local originalAnchored = {}
	for _, p in ipairs(ctx.Boulder:GetDescendants()) do
		if p:IsA("BasePart") then originalAnchored[p] = p.Anchored end
	end
	local base = ctx.Boulder:FindFirstChild("Base") or ctx.Boulder:FindFirstChildWhichIsA("BasePart")
	assert(base, "BoulderCarry: Boulder missing Base Part")
	local att = base:FindFirstChildWhichIsA("Attachment")
	assert(att, "BoulderCarry: Base missing Attachment")

	-- Anexa rope
	local rope = Utils.AttachRope(monster, att)

	

	-- Path
	local hum = monster:FindFirstChildOfClass("Humanoid")
	local success = true

	-- Ordena nodes
	local nodes = {}
	for _, n in ipairs(ctx.NodesFolder:GetChildren()) do
		if n:IsA("BasePart") then table.insert(nodes, n) end
	end
	table.sort(nodes, function(a,b) return nodeIndex(a) < nodeIndex(b) end)

	-- Pré-rolagem: esta tentativa vai falhar?
	local willFailAttempt = (math.random() < 0.25)
	
	local halfwayIndex = math.max(1, math.floor(#nodes / 2))
	
	-- Config via ctx (opcionais)
	local failAtIndex   = tonumber(ctx.FailAtIndex)   -- perna onde falha: entre nodes[failAtIndex] -> nodes[failAtIndex+1]
	local failAtFraction= tonumber(ctx.FailAtFraction) -- fração dentro da perna [0..1]
	if not failAtIndex then
		failAtIndex = math.max(1, math.floor(#nodes / 2)) -- default: “meio” da lista
	end
	if not failAtFraction or failAtFraction < 0 or failAtFraction > 1 then
		failAtFraction = 0.5 -- default: 50% do deslocamento da perna
	end

	-- Pré-rolagem da tentativa
	local willFailAttempt = (math.random() < 0.25) -- enquanto não migramos p/ Bond/Discipline

	local hrp = monster.PrimaryPart or monster:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then
		return handleFailure(monster, ctx, rope, ctx.Boulder, base, originalPivot, originalAnchored)
	end

	for idx, node in ipairs(nodes) do
		local targetPos = node.Position
		local reachedFlag = false

		-- inicia movimentação desta perna
		hum:MoveTo(targetPos)
		local conn; conn = hum.MoveToFinished:Connect(function(ok)
			reachedFlag = ok
		end)

		-- captura o ponto de partida desta perna
		local startPos = hrp.Position

		-- monitora frame-a-frame até concluir a perna OU falhar no ponto configurado
		while not reachedFlag do
			-- aborta se monstro sumiu
			if not monster.Parent then
				if conn then conn:Disconnect() end
				return handleFailure(monster, ctx, rope, ctx.Boulder, base, originalPivot, originalAnchored)
			end

			-- falha configurada: acontece durante a perna failAtIndex -> failAtIndex+1
			if willFailAttempt and idx == failAtIndex then
				local frac = travelFraction(hrp.Position, startPos, targetPos)
				if frac >= failAtFraction then
					if conn then conn:Disconnect() end
					return handleFailure(monster, ctx, rope, ctx.Boulder, base, originalPivot, originalAnchored)
				end
			end

			task.wait() -- próximo frame
		end

		if conn then conn:Disconnect() end

		-- se MoveTo falhou (pathing), trata como falha do treino
		if not reachedFlag then
			return handleFailure(monster, ctx, rope, ctx.Boulder, base, originalPivot, originalAnchored)
		end
	end

	-- SUCESSO: solta rope, teleporta para End e reseta boulder
	Utils.DetachRope(monster)
	base.Anchored = false
	if ctx.End and monster.PrimaryPart then
		monster:PivotTo	(ctx.End.CFrame + Vector3.new(0, 2, 0))
	end

	-- reset da boulder (como no sucesso anterior)
	for part, _ in pairs(originalAnchored) do
		if part and part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
			part.Anchored = true
		end
	end
	ctx.Boulder:PivotTo(originalPivot)
	for part, wasAnchored in pairs(originalAnchored) do
		if part and part:IsA("BasePart") then
			part.Anchored = wasAnchored
		end
	end
	
	_G.FUNCTIONS:teleportToOwner(monster ,player.UserId)

	return { success = success }
end

return Training
