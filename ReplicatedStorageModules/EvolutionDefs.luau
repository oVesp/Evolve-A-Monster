-- ReplicatedStorage/Modules/EvolutionDefs.lua
-- Digimon-like branching + convergence. Races decidem moves (com exceções opcionais).

local EvolutionDefs = {}

-- ===== Progressive Stage Caps =====
EvolutionDefs.StageCaps = {
	Fledgeling = 300,   -- Total stats cap
	Rookie = 600,
	Champion = 1200,
	Elder = 1800,
	Unique = 2000
}

-- ===== Stage Order =====
EvolutionDefs.StageOrder = { "Fledgeling","Rookie","Champion","Elder","Unique" }

-- ===== Race Stage Mapping =====
EvolutionDefs.RaceStage = {
	-- Raptor line
	Raptor="Fledgeling", Dino="Rookie", Beast="Champion", Dragon="Elder", Behemoth="Elder",
	-- Construct / Core line
	Core="Fledgeling", Golem="Rookie", Titan="Champion", Colossus="Elder", PrimordialConstruct="Unique",
	-- Demonic line
	Imp="Fledgeling", Devil="Rookie", Archdemon="Champion", AbyssLord="Elder",
	-- Progenitor / Reality line
	RealitySeed="Fledgeling", CosmicWeaver="Champion", VoidWalker="Elder", Architect="Elder", PrimeConcept="Unique",
	-- Boxer / Lagomorph line
	Hopling="Fledgeling", Pugilhare="Rookie", Strikeron="Champion", Monarchare="Elder",
	-- Convergences
	SteelBoxer="Elder", IronColoss="Unique", DreadBeast="Elder", SkyBehemoth="Elder",
	NetherDragon="Unique", OrderArchitect="Unique", EntropicVoid="Unique",
}

function EvolutionDefs:GetEvolutionChance(currentRace, ctx, candidate)
	if not candidate or not candidate.gates then return 0 end

	local progress = 0
	local totalGates = 0

	-- Calculate progress towards requirements
	if candidate.gates.minStats then
		for stat, minV in pairs(candidate.gates.minStats) do
			local current = ctx.stats[stat] or 0
			local statProgress = math.min(1, current / minV)
			progress = progress + statProgress
			totalGates = totalGates + 1
		end
	end

	if candidate.gates.minBond then
		local bondProgress = math.min(1, (ctx.bond or 0) / candidate.gates.minBond)
		progress = progress + bondProgress
		totalGates = totalGates + 1
	end

	if candidate.gates.minWins then
		local winProgress = math.min(1, (ctx.wins or 0) / candidate.gates.minWins)
		progress = progress + winProgress
		totalGates = totalGates + 1
	end

	if totalGates == 0 then return 1.0 end -- No requirements = 100% chance

	local overallProgress = progress / totalGates

	-- Base chance increases with progress, with forced evolution at very low progress
	if overallProgress >= 0.9 then
		return 0.95 -- 95% chance when nearly all requirements met
	elseif overallProgress >= 0.7 then
		return 0.75 -- 75% chance when most requirements met
	elseif overallProgress >= 0.5 then
		return 0.5 -- 50% chance when half requirements met
	elseif overallProgress >= 0.3 then
		return 0.25 -- 25% chance when some progress
	elseif overallProgress >= 0.1 then
		return 0.1 -- 10% base chance with minimal progress
	else
		return 0.05 -- 5% forced evolution chance even with no progress
	end
end

-- ===== Defaults por Path (aplica quando o edge não define prioridade/gates) =====
EvolutionDefs.DefaultPathMeta = {
	Natural     = { priority = 5 },
	Power       = { priority = 7, gates = { minWins = 3 } },
	Wisdom      = { priority = 7, gates = { minStats = { Intelligence = 15 } } },
	Friendship  = { priority = 8, gates = { minBond = 25, maxCareMistakes = 3 } },
	Corrupted   = { priority = 6, gates = { maxCareMistakes = 999 } },
}

-- ===== Ferramentas internas =====
local function meetsGates(ctx, gates)
	if not gates then return true end
	if gates.minBond and (ctx.bond or 0) < gates.minBond then return false end
	if gates.minWins and (ctx.wins or 0) < gates.minWins then return false end
	if gates.maxCareMistakes and (ctx.careMistakes or 0) > gates.maxCareMistakes then return false end
	if gates.minStats then
		for stat, minV in pairs(gates.minStats) do
			if (ctx.stats[stat] or 0) < minV then return false end
		end
	end
	if gates.personalityAnyOf and #gates.personalityAnyOf > 0 then
		local p = tostring(ctx.personality or "")
		local ok = false
		for _, name in ipairs(gates.personalityAnyOf) do
			if name == p then ok = true break end
		end
		if not ok then return false end
	end
	return true
end

local function normalizeEdges(list)
	local out = {}
	for _, v in ipairs(list or {}) do
		if typeof(v) == "string" then
			table.insert(out, { target = v })
		else
			table.insert(out, {
				target   = v.target,
				path     = v.path,
				priority = v.priority,
				gates    = v.gates,
			})
		end
	end
	return out
end

-- ===== Normalized Evolution Requirements =====
EvolutionDefs.EvolutionGraph = {
	-- === Raptor branch ===
	Raptor = {
		{ target="Dino", priority=6, gates={ minStats={ Strength=45, Speed=30 } } },
		{ target="Beast", priority=7, gates={ minWins=4, minStats={ Strength=60, Defense=36 } } },
		{ target="Dragon", priority=7, gates={ minStats={ Intelligence=54, Skill=42, Speed=42 } } },
		{ target="Behemoth", priority=5, gates={ minStats={ Defense=54, Hp=110 } } },
	},
	Dino = {
		{ target="Dragon", priority=9, gates={ minWins=8, minStats={ Strength=105, Speed=75, Skill=60 } } },
		{ target="Behemoth", priority=7, gates={ minStats={ Defense=90, Hp=140 } } },
		{ target="Beast", priority=6, gates={ minWins=6, minStats={ Strength=84, Skill=54 } } },
	},
	Beast = {
		{ target="Dragon", priority=8, gates={ minWins=12, minStats={ Strength=135, Skill=90, Speed=90 } } },
		{ target="Behemoth", priority=6, gates={ minStats={ Defense=135, Hp=180 } } },
		{ target="DreadBeast", priority=8, gates={ maxCareMistakes=999, minStats={ Strength=120 } } },
	},
	Dragon = {
		{ target="NetherDragon", priority=11, gates={ minBond=35, minStats={ Intelligence=150, Skill=96 } } },
	},
	Behemoth = {
		{ target="SkyBehemoth", priority=9, gates={ minStats={ Intelligence=114, Speed=102 } } },
	},

	-- === Construct / Core branch ===
	Core = {
		{ target="Golem", priority=5, gates={ minStats={ Defense=45 } } },
		{ target="Titan", priority=7, gates={ minWins=5, minStats={ Strength=66, Defense=54 } } },
		{ target="Colossus", priority=8, gates={ minBond=28, minStats={ Defense=66, Hp=130 } } },
		{ target="PrimordialConstruct", priority=10, gates={ minStats={ Intelligence=90, Defense=72 } } },
	},
	Golem = {
		{ target="Titan", priority=8, gates={ minWins=8, minStats={ Strength=102, Defense=84 } } },
		{ target="Colossus", priority=6, gates={ minStats={ Defense=108, Hp=160 } } },
	},
	Titan = {
		{ target="Colossus", priority=5, gates={ minStats={ Defense=132, Hp=200 } } },
		{ target="SteelBoxer", priority=8, gates={ minWins=12, minStats={ Strength=135, Defense=120, Skill=78 } } },
	},
	Colossus = {
		{ target="IronColoss", priority=11, gates={ minBond=55, maxCareMistakes=2, minStats={ Defense=180, Hp=260 } } },
	},

	-- === Demonic branch ===
	Imp = {
		{ target="Devil", priority=5, gates={ minStats={ Skill=36 } } },
		{ target="Archdemon", priority=8, gates={ minWins=6, minStats={ Strength=78, Intelligence=54 } } },
		{ target="AbyssLord", priority=9, gates={ maxCareMistakes=999, minStats={ Strength=72 } } },
	},
	Devil = {
		{ target="Archdemon", priority=7, gates={ minWins=10, minStats={ Strength=102, Skill=72 } } },
		{ target="AbyssLord", priority=8, gates={ maxCareMistakes=999, minStats={ Strength=90, Defense=72 } } },
	},
	Archdemon = {
		{ target="AbyssLord", priority=9, gates={ minWins=14, minStats={ Strength=132, Intelligence=90 } } },
	},

	-- === Progenitor / Reality branch ===
	RealitySeed = {
		{ target="CosmicWeaver", priority=10, gates={ maxCareMistakes=3, minStats={ Intelligence=3 } } },
		{ target="VoidWalker", priority=7, gates={ minWins=5, minStats={ Strength=84, Skill=66 } } },
		{ target="Architect", priority=9, gates={ minBond=30, minStats={ Intelligence=75, Defense=60 } } },
		{ target="PrimeConcept", priority=12, gates={ minBond=40, minWins=6, minStats={ Intelligence=120, Defense=84 } } },
	},
	CosmicWeaver = {
		{ target="Architect", priority=10, gates={ minBond=25, minStats={ Intelligence=150, Skill=105 } } },
		{ target="VoidWalker", priority=7, gates={ minWins=10, minStats={ Strength=135, Speed=90 } } },
		{ target="PrimeConcept", priority=12, gates={ minBond=60, minWins=8, maxCareMistakes=2, minStats={ Intelligence=180, Defense=135 } } },
	},
	VoidWalker = {
		{ target="EntropicVoid", priority=11, gates={ maxCareMistakes=999, minStats={ Strength=165, Intelligence=120 } } },
	},
	Architect = {
		{ target="OrderArchitect", priority=11, gates={ minBond=65, minStats={ Intelligence=186, Skill=120 } } },
	},

	-- === Boxer / Lagomorph branch ===
	Hopling = {
		{ target="Pugilhare", priority=5, gates={ minStats={ Skill=42, Speed=36 } } },
		{ target="Strikeron", priority=7, gates={ minWins=4, minStats={ Strength=54, Speed=42 } } },
		{ target="Monarchare", priority=8, gates={ minBond=26, minStats={ Skill=42, Intelligence=36 } } },
	},
	Pugilhare = {
		{ target="Strikeron", priority=8, gates={ minWins=6, minStats={ Strength=78, Skill=66, Speed=60 } } },
		{ target="Monarchare", priority=8, gates={ minBond=35, minStats={ Skill=72, Speed=60 } } },
		{ target="SteelBoxer", priority=9, gates={ minWins=10, minStats={ Strength=120, Skill=96, Speed=84 } } },
	},
	Strikeron = {
		{ target="Monarchare", priority=6, gates={ minStats={ Skill=96, Speed=84 } } },
		{ target="SteelBoxer", priority=9, gates={ minWins=12, minStats={ Strength=126, Skill=102, Speed=90 } } },
	},
	Monarchare = {
		{ target="SteelBoxer", priority=8, gates={ minWins=14, minStats={ Strength=132, Skill=108 } } },
	},
}

-- ===== API =====
function EvolutionDefs:GetStage(race)
	return self.RaceStage[race] or "Fledgeling"
end

function EvolutionDefs:GetCandidates(currentRace, ctx)
	local raw = self.EvolutionGraph[currentRace]
	if not raw then return {} end
	local edges = normalizeEdges(raw)
	local candidates = {}

	for _, edge in ipairs(edges) do
		local path = edge.path or "Natural"
		local defaults = self.DefaultPathMeta[path] or {}
		local priority = edge.priority or defaults.priority or 0

		local mergedGates
		if defaults.gates or edge.gates then
			mergedGates = {}
			if defaults.gates then for k,v in pairs(defaults.gates) do mergedGates[k]=v end end
			if edge.gates   then for k,v in pairs(edge.gates)   do mergedGates[k]=v end end
		end

		if meetsGates(ctx or {}, mergedGates) then
			table.insert(candidates, { target=edge.target, path=path, priority=priority, gates=mergedGates })
		end
	end

	table.sort(candidates, function(a,b)
		if (a.priority or 0) == (b.priority or 0) then
			return (a.target or "") < (b.target or "")
		end
		return (a.priority or 0) > (b.priority or 0)
	end)

	return candidates
end

-- Critério padrão: maior priority; empate → alfabética. (Troque por ponderado se quiser)
function EvolutionDefs:PickEvolution(currentRace, ctx)
	local cands = self:GetCandidates(currentRace, ctx)
	return cands[1] and cands[1].target or nil
end

-- ===== Moves por Raça (raça decide por padrão) =====
EvolutionDefs.MovesByRace = {
	-- Raptor
	Raptor = { "Tackle", "Bite" },
	Dino = { "Crush", "Roar", "TailSwipe" },
	Beast = { "Pounce", "SavageClaw", "Intimidate" },
	Dragon = { "FlameBreath", "WingBuffet", "Roar" },
	Behemoth = { "Quake", "GuardBreak", "Rend" },
	NetherDragon = { "NetherFlame", "VoidWing", "AbyssRoar" },
	DreadBeast = { "Frenzy", "Ravage", "Howl" },
	SkyBehemoth = { "JetRush", "SkyQuake", "AerialGuard" },

	-- Construct
	Core = { "PebbleShot", "Harden" },
	Golem = { "RockFist", "Fortify" },
	Titan = { "Earthshatter", "Bulwark" },
	Colossus = { "SeismicSlam", "StoneWall" },
	PrimordialConstruct = { "PrimeStrike", "AegisMatrix" },
	IronColoss = { "IronDread", "MagnaWall", "CataclysmicSlam" },

	-- Demonic
	Imp = { "ImpFire", "Taunt" },
	Devil = { "HellClaw", "DarkPulse" },
	Archdemon = { "AbyssalHowl", "SoulDrain" },
	AbyssLord = { "Cataclysm", "OblivionMark" },

	-- Progenitor / Reality
	RealitySeed = { "CosmicThread", "Weave Pulse" },
	CosmicWeaver = { "Singularity", "WarpLance" },
	VoidWalker = { "VoidStep", "NullSlash" },
	Architect = { "Blueprint", "Construct" },
	PrimeConcept = { "PrimeLaw", "Rewrite" },
	EntropicVoid = { "EntropyWave", "NullVortex", "Erase" },
	OrderArchitect = { "PrimeEdict", "AxiomWall", "Reconstruct" },

	-- Boxer / Lagomorph
	Hopling = { "Jab", "Feint" },
	Pugilhare = { "QuickHook", "Counter" },
	Strikeron = { "PowerStraight", "Weave" },
	Monarchare = { "RoyalGuard", "StarUpper" },
	SteelBoxer = { "MetalKnuckle", "SteelGuard", "DempseyRoll" },
}

-- Exceções de moves (opcionais)
function EvolutionDefs.ExceptionMovesForRace(race, ctx)
	-- Ex.: estrategista ganha "Feint" extra no ramo boxer
	if (race == "Pugilhare" or race == "Strikeron") and ctx.personality == "Strategist" then
		local base = EvolutionDefs.MovesByRace[race] or {}
		local out = { table.unpack(base) }
		local hasFeint = false
		for _,m in ipairs(out) do if m=="Feint" then hasFeint=true break end end
		if not hasFeint then table.insert(out, "Feint") end
		return out
	end
	-- Ex.: SteelBoxer mantém 1 move do estágio anterior (se houver)
	if race == "SteelBoxer" and ctx.previousMoves and ctx.previousMoves[1] then
		local out = { table.unpack(EvolutionDefs.MovesByRace[race] or {}) }
		table.insert(out, 1, ctx.previousMoves[1])
		return out
	end
	return nil
end

function EvolutionDefs:GetMovesForRace(race, ctx)
	local custom = self.ExceptionMovesForRace(race, ctx or {})
	if custom then return custom end
	local base = self.MovesByRace[race]
	if base and #base > 0 then return table.clone(base) end

	-- Fallback: tenta pegar do módulo Moves, se existir
	local ok, Moves = pcall(function() return require(game.ReplicatedStorage.Modules.Moves) end)
	if ok and Moves and Moves.GetStarterMoves then
		print("STARTERMOVES")
		return Moves:GetStarterMoves(race)
	end
	return {}
end

-- ===== Utilidades de edição =====
function EvolutionDefs:Register(fromRace, edgeOrTarget)
	self.EvolutionGraph[fromRace] = self.EvolutionGraph[fromRace] or {}
	table.insert(self.EvolutionGraph[fromRace], edgeOrTarget)
end

function EvolutionDefs:Override(fromRace, list)
	self.EvolutionGraph[fromRace] = list or {}
end

function EvolutionDefs:SetStage(race, stage)
	self.RaceStage[race] = stage
end

function EvolutionDefs:Validate()
	local ok, errs = true, {}
	for from, list in pairs(self.EvolutionGraph) do
		for i, edge in ipairs(normalizeEdges(list)) do
			if type(edge.target) ~= "string" then
				ok = false; table.insert(errs, string.format("Edge inválida em %s[%d]: target ausente", from, i))
			end
		end
	end
	return ok, errs
end

return EvolutionDefs
