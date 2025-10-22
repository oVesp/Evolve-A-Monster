-- MonsterDataTemplate.luau (MVP – Progenitor Focus)
-- Retrocompatível: mantém chaves antigas e adiciona novas (BaseRaceFamily, History, Bond, etc.)

return {
	id = "1",

	-- Identidade
	Name = "DefaultName",
	Race = "RealitySeed",            -- Fledgeling do caminho Progenitor (MVP)
	Stage = "Fledgeling",
	BaseRaceFamily = "Progenitor",   -- Usado pelos gates de evolução (ex.: caminho Progenitor)

	-- Dono/controle
	OwnerId = nil,                   -- Setado quando for do jogador

	-- Progressão
	Alignment = "Neutral",
	Age = 0,                         -- Pode ser tempo de vida/horas (real-time aging)
	Level = 1,

	-- Métricas para evolução (Digimon-like)
	Bond = 0,                        -- Relação com o dono (0–100)
	Wins = 0,                        -- Vitórias em combate
	SessionTime = 0,                 -- Tempo ativo na sessão (segundos)
	CareMistakes = 0,                -- Maus cuidados influenciam rotas alternativas

	-- Stats (com aliases para compatibilidade)
	Stats = {
		Hp = 100,
		Mp = 100,

		-- Primários (nomes antigos e aliases comuns)
		Strength = 10, STR = 10,
		Defense  = 10, DEF = 10,
		Skill    = 10, SKL = 10,

		Speed = 10,  SPD = 10,

		-- Intelectuais / Sabedoria (alguns sistemas usam INT, outros WIS)
		Intelligence = 10, INT = 10,
		Luck          = 10, LCK = 10,  -- “Wit” ≈ “Wisdom”; ambos preenchidos para facilitar leitura
	},

	-- Personalidade e afinidades
	Personality = "Unpredictable",
	Element = "None",

	-- Moves (mantém estrutura antiga)
	Moves = {
		{ "BasicAttack" }
	},

	-- Estado de runtime
	State = "Idle",

	-- Aparência/Modelo (preenchido na Build ou pelo Generator)
	Appearance = {
		-- BodyParts / Accessories / Colors...
	},

	-- Histórico e metadados (para evolução e reconstrução)
	History = { "RealitySeed" },     -- Empilha as formas (ex.: + "CosmicWeaver", ... "PrimeConcept")
	LastUpdatePlayed = "0",          -- Opcional: para difs e persistência
	Info = {},                       -- Espaço para meta/flags externos

	Version = "1.0",
}
