-- ServerScriptService > Main (Versão Final à Prova de Falhas)

print("[Main] Iniciando o servidor em modo de segurança...")

-- Função segura para carregar módulos. Se um falhar, ele nos dirá qual.
local function safeRequire(moduleScript)
	local success, module = pcall(require, moduleScript)
	if not success then
		warn(("[Main] ERRO CRÍTICO: O módulo '%s' falhou ao carregar. O erro é: %s"):format(moduleScript.Name, tostring(module)))
		return nil
	end
	print(("[Main] Módulo '%s' carregado com sucesso."):format(moduleScript.Name))
	return module
end

-- Carrega todos os módulos de forma segura
_G.DATA = safeRequire(script.Data)
_G.STATES = safeRequire(script.States)
_G.MOVEMENT = safeRequire(game.ReplicatedStorage.Modules.Movement)
_G.FUNCTIONS = safeRequire(script.Functions)
_G.COMBATMANAGER = require(script.CombatManager)
_G.UTILS = safeRequire(script.Utils)
_G.EFFECTS = safeRequire(game.ReplicatedStorage.Modules["Effects&SFX"])
_G.MONSTERGENERATOR = safeRequire(script.MonsterGenerator)
_G.COMBAT_ARENA = safeRequire(script.CombatZone)
_G.TRAINING_SYSTEM = safeRequire(script.TrainingSystem.Main)
_G.EVOLUTION = safeRequire(script.EvolutionManager)
if _G.EVOLUTION and _G.EVOLUTION.Init then
	_G.EVOLUTION.Init()
	print("[Main] Evolution system initialized")
end
_G.SHARED = safeRequire(script.Shared)
_G.PATHENCOUNTER = safeRequire(script.PathEncounterRunner)
_G.COMBAT_ZONE = safeRequire(script.CombatZone)
if _G.PATHENCOUNTER then
    _G.PATHENCOUNTER.Initialize()
    print("[Main] Path encounter system initialized")
end
--_G.MATCHMAKING = safeRequire(script.MatchmakingService)

-- Carrega o nosso gerenciador de filas
local QueueManager = safeRequire(script.QueueManager)

-- Se o QueueManager ou o CombatManager falharem, não podemos continuar com a fila.
if not QueueManager or not _G.COMBATMANAGER then
	warn("[Main] ERRO GRAVE: QueueManager ou CombatManager não puderam ser carregados. O sistema de filas será desativado.")
	return -- Para o script aqui
end

print("[Main] Todos os módulos essenciais para a fila foram carregados.")

-- Serviços
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Espera e valida os RemoteEvents da Fila
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local JoinQueueRE = Remotes:WaitForChild("JoinQueue")
local LeaveQueueRE = Remotes:WaitForChild("LeaveQueue")
local QueueStatusUpdate = Remotes:WaitForChild("QueueStatusUpdate")
print("[Main] RemoteEvents da fila encontrados.")

-------------------------------------------------------------------
-- LÓGICA DO SISTEMA DE FILAS
-------------------------------------------------------------------

JoinQueueRE.OnServerEvent:Connect(function(player, queueName)
	if type(queueName) ~= "string" then return end
	print(("[Main] SUCESSO: Evento 'JoinQueue' recebido de %s para a fila '%s'."):format(player.Name, queueName))
	local success, message = QueueManager.Join(player, queueName)
	if not success then
		print(("[Main] Falha ao entrar na fila para %s. Notificando cliente: %s"):format(player.Name, message))
		QueueStatusUpdate:FireClient(player, { status = "Failed", message = message })
	end
end)

LeaveQueueRE.OnServerEvent:Connect(function(player)
	print(("[Main] Evento 'LeaveQueue' recebido de %s."):format(player.Name))
	QueueManager.Leave(player)
end)

Players.PlayerRemoving:Connect(function(player)
	print(("[Main] Jogador %s desconectou, removendo da fila."):format(player.Name))
	QueueManager.Leave(player)
end)

print("--- [Main] Sistema de Fila está online e pronto. ---")

-- Sua lógica de carregamento de dados (mantida)
Players.PlayerAdded:Connect(function(player)
	player.AttributeChanged:Connect(function(attr)
		if player:GetAttribute("DataLoaded") then
			_G.GAME = safeRequire(script.Game)
			_G.NPCEventTrigger = safeRequire(script.EncounterManager)
			if _G.NPCEventTrigger then
				wait(1)
				_G.NPCEventTrigger.Initialize()
			end
		end
	end)
end)