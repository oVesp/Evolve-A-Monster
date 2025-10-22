local module = {}
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")

-- Namespace de modos de treino
local Modes = {}
module.Modes = Modes  -- exporta se quiser acessar externamente

-- simple mapping; tweak to your economy/balance
local BONUS = {
	Sprint      = { Speed = 2 },
	Sparing     = { Strength = 1, Speed = 1, Defense = -1},
	Parrying    = { Defense = 1, Skill = 1, Strength = -1 },
	MindBend    = { Intelligence = 2 },
	LuckyBlocks   = function()
		return { Luck = math.random(-3,3) }
	end,
	RockSmash = { Strength = 2}, 
	BoulderCarry = { Defense = 2 },
	WhackAMole   = { Skill = 2 },
}

-- =========================
--  MODO: BoulderCarry
-- =========================
do
	local B = {}
	Modes.BoulderCarry = B

	-- storage privado por monstro para limpar depois
	local activeLinks = {} :: {[Model]: {constraints: {Instance}, tempAttachments: {Attachment}}}

	local function parseVector3(str)
		if typeof(str) == "Vector3" then return str end
		if typeof(str) ~= "string" then return nil end
		local x,y,z = string.match(str, "([^,]+),([^,]+),([^,]+)")
		x,y,z = tonumber(x), tonumber(y), tonumber(z)
		if x and y and z then return Vector3.new(x,y,z) end
		return nil
	end

	local function getAttrNum(obj: Instance, key: string, default: number?)
		local v = obj:GetAttribute(key)
		if typeof(v) == "number" then return v end
		return default
	end

	local function getAttrBool(obj: Instance, key: string, default: boolean?)
		local v = obj:GetAttribute(key)
		if typeof(v) == "boolean" then return v end
		return default
	end

	local function getAttrStr(obj: Instance, key: string, default: string?)
		local v = obj:GetAttribute(key)
		if typeof(v) == "string" then return v end
		return default
	end

	local function toConstraint(item: Instance, linkType: string): Instance
		if linkType == "Rod" then
			return Instance.new("RodConstraint")
		else
			return Instance.new("RopeConstraint")
		end
	end

	local function findAttachmentOnItem(itemModel: Instance, attachName: string): Attachment?
		for _,desc in ipairs(itemModel:GetDescendants()) do
			if desc:IsA("Attachment") and desc.Name == attachName then
				return desc
			end
		end
		return nil
	end

	local function ensureMonsterAttachment(hrp: BasePart, name: string, offset: Vector3?): Attachment
		local att = hrp:FindFirstChild(name)
		if not att then
			att = Instance.new("Attachment")
			att.Name = name
			att.Parent = hrp
		end
		att.Position = offset or Vector3.new()
		return att
	end

	-- PREPARE: cria vínculos com o que estiver em Route/Interactables
	function B.Prepare(monster: Model, routeFolder: Folder)
		if not monster or not routeFolder then return end
		local hrp = monster:FindFirstChild("HumanoidRootPart") :: BasePart
		if not hrp then return end

		activeLinks[monster] = activeLinks[monster] or {constraints = {}, tempAttachments = {}}
		local bucket = activeLinks[monster]

		local interactables = routeFolder:FindFirstChild("Interactables")
		if not interactables or not interactables:IsA("Folder") then return end

		for _, item in ipairs(interactables:GetChildren()) do
			local linkType = getAttrStr(item, "LinkType", "Rope")
			local attItemName = getAttrStr(item, "AttachmentNameOnItem", "Attachment")
			local attMonsterName = getAttrStr(item, "AttachmentNameOnMonster", "TrainingLink")
			local offset = parseVector3(getAttrStr(item, "OffsetOnMonster", nil))

			local itemAttachment = findAttachmentOnItem(item, attItemName)
			if not itemAttachment then
				warn("[BoulderCarry] Attachment não encontrado:", item:GetFullName(), "nome:", attItemName)
				continue
			end

			local basePart = itemAttachment.Parent :: BasePart
			if basePart and basePart:IsA("BasePart") then
				basePart.Anchored = false
			end

			local monsterAttachment = ensureMonsterAttachment(hrp, attMonsterName, offset)

			local constraint = toConstraint(item, linkType)
			constraint.Attachment0 = monsterAttachment
			constraint.Attachment1 = itemAttachment

			-- parâmetros genéricos por atributo, com defaults razoáveis
			local defaultLen = (monsterAttachment.WorldPosition - itemAttachment.WorldPosition).Magnitude

			if constraint:IsA("RopeConstraint") then
				constraint.Length = getAttrNum(item, "LinkLength", defaultLen)
				constraint.Restitution = getAttrNum(item, "Restitution", constraint.Restitution)
				constraint.Thickness = getAttrNum(item, "Thickness", constraint.Thickness)
				constraint.Visible = getAttrBool(item, "Visible", constraint.Visible)
				--constraint.RigidityEnabled = getAttrBool(item, "RigidityEnabled", constraint.RigidityEnabled)
			else -- RodConstraint
				constraint.Length = getAttrNum(item, "LinkLength", defaultLen)
				constraint.Visible = getAttrBool(item, "Visible", constraint.Visible)
				if constraint:FindFirstChild("Thickness") then
					-- algumas builds têm plugin que injeta prop; ignore se não existir
					(constraint :: any).Thickness = getAttrNum(item, "Thickness", (constraint :: any).Thickness)
				end
			end

			constraint.Parent = itemAttachment.Parent

			table.insert(bucket.constraints, constraint)
			-- track do attachment criado no HRP
			local seen = false
			for _, a in ipairs(bucket.tempAttachments) do
				if a == monsterAttachment then seen = true break end
			end
			if not seen then
				table.insert(bucket.tempAttachments, monsterAttachment)
			end
		end
	end

	-- EXECUTE: opcional (ex.: ajustes finos, peso/drag). Aqui mantemos noops.
	function B.Execute(monster: Model, routeFolder: Folder)
		-- Example: poderia ajustar velocidade, alterar Length dinamicamente, etc.
	end

	-- CLEANUP: destrói constraints + attachments temporários
	function B.Cleanup(monster: Model)
		local bucket = activeLinks[monster]
		if not bucket then return end

		for _, c in ipairs(bucket.constraints) do
			if c and c.Destroy then c:Destroy() end
		end
		for _, a in ipairs(bucket.tempAttachments) do
			if a and a.Parent then a:Destroy() end
		end
		activeLinks[monster] = nil
	end
end



local function snapshotStats(monster: Instance)
	local out = {}
	for _,name in ipairs({"Strength","Defense","Skill","Speed","Intelligence","Luck"}) do
		out[name] = monster:GetAttribute(name) or 0
	end
	return out
end

local function sortByNumericName(a: Instance, b: Instance)
	local na = tonumber(string.match(a.Name, "%d+")) or math.huge
	local nb = tonumber(string.match(b.Name, "%d+")) or math.huge
	if na ~= nb then
		return na < nb
	else
		return a.Name < b.Name
	end
end

function module.ApplyTraining(monster: Instance, trainingType: string)
	if not monster or not monster:IsDescendantOf(game) then return {} end
	local grant = BONUS[trainingType]
	if typeof(grant) == "function" then grant = grant() end
	grant = grant or {}
	for stat, val in pairs(grant) do
		monster:SetAttribute(stat, (monster:GetAttribute(stat) or 0) + val)
	end
	return snapshotStats(monster)
end

local function moveTo(monsterHRP: BasePart, targetPos: Vector3, speed: number): boolean
	local hum: Humanoid? = monsterHRP.Parent:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = speed or hum.WalkSpeed end

	-- helper para esperar com timeout adaptativo
	local function waitToReach(toPos: Vector3)
		local cur = monsterHRP.Position
		local dist = (toPos - cur).Magnitude
		local ws = (hum and hum.WalkSpeed) or 16
		-- tempo base = dist/vel; multiplicador de folga para “carga/arrasto”
		local t = (dist / math.max(ws, 1)) * 1.8 + 0.75
		-- clamp defensivo
		local timeout = math.clamp(t, 3, 30)
		return monsterHRP.Parent.Humanoid.MoveToFinished:Wait(timeout) == true
	end

	local path: Path = PathfindingService:CreatePath({ AgentCanJump = true })
	local ok = pcall(function() path:ComputeAsync(monsterHRP.Position, targetPos) end)
	if ok and path.Status == Enum.PathStatus.Success then
		for _, wp in ipairs(path:GetWaypoints()) do
			monsterHRP.Parent.Humanoid:MoveTo(wp.Position)
			if wp.Action == Enum.PathWaypointAction.Jump and hum then hum.Jump = true end
			if not waitToReach(wp.Position) then
				-- retry único no mesmo waypoint
				monsterHRP.Parent.Humanoid:MoveTo(wp.Position)
				if not waitToReach(wp.Position) then
					return false
				end
			end
		end
		return true
	else
		monsterHRP.Parent.Humanoid:MoveTo(targetPos)
		if not waitToReach(targetPos) then
			-- retry único no destino direto
			monsterHRP.Parent.Humanoid:MoveTo(targetPos)
			return waitToReach(targetPos)
		end
		return true
	end
end

local function getRouteFolder(trainingType: string): Folder?
	local routes = Workspace:FindFirstChild("Training")
	if not routes then return nil end
	local folder = routes:FindFirstChild(trainingType)
	return (folder and folder:IsA("Folder")) and folder or nil
end

local function runCourse(monster: Instance, trainingType: string)
	local hrp: BasePart = monster:FindFirstChild("HumanoidRootPart") :: any
	if not hrp then return end

	-- cancela qualquer movimento antes de iniciar o percurso
	local hum: Humanoid? = monster:FindFirstChildOfClass("Humanoid")
	if hum and monster.PrimaryPart then
		hum:MoveTo(monster.PrimaryPart.Position)
	end

	local baseSpeed = (monster:GetAttribute("Speed") or 2)
	local travelSpeed = math.clamp(10 + baseSpeed * 2, 8, 28)

	local folder = getRouteFolder(trainingType)
	if folder then
		local points = {}
		for _,p in ipairs(folder:GetChildren()) do
			if p:IsA("BasePart") then table.insert(points, p) end
		end
		table.sort(points, sortByNumericName)
		for _,p in ipairs(points) do
			if not moveTo(hrp, p.Position, travelSpeed) then break end
		end
	else
		-- fallback curto/seguro
		local forward = hrp.CFrame * CFrame.new(0, 0, -25)
		moveTo(hrp, forward.Position, travelSpeed)
		moveTo(hrp, hrp.Position, travelSpeed)
	end
end

function module.StartSession(player: Player, monster: Instance, trainingType: string)
	if not monster then return nil end

	-- Estado Training (para pausar Following etc.)
	if _G and _G.STATES and typeof(_G.STATES.SetState) == "function" then
		_G.STATES:SetState(monster, "Training")
	end

	-- Resolve a pasta da rota uma única vez
	local routes = workspace:FindFirstChild("Training")
	local routeFolder = routes and routes:FindFirstChild(trainingType)

	-- Se existir modo especializado, chama Prepare/Execute/Cleanup
	local mode = Modes[trainingType]

	if mode and mode.Prepare then
		mode.Prepare(monster, routeFolder)
	end

	-- Se o modo tiver execução própria, use-a; caso contrário, use seu runCourse padrão
	if mode and mode.Execute then
		mode.Execute(monster, routeFolder)
	else
		-- runCourse(monster, trainingType)  -- use sua implementação atual
		runCourse(monster, trainingType)
	end

	-- limpeza específica do modo (remove constraints/attachments)
	if mode and mode.Cleanup then
		mode.Cleanup(monster)
	end

	task.wait(0.25)

	local snap = module.ApplyTraining(monster, trainingType)

	-- Sair de Training → voltar pro que fazia sentido
	local hasOwner = monster:GetAttribute("OwnerId") ~= nil
	if _G and _G.STATES and typeof(_G.STATES.SetState) == "function" then
		_G.STATES:SetState(monster, hasOwner and "Following" or "Idle")
	end

	return snap
end


return module
