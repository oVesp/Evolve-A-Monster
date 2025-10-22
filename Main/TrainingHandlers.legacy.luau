-- ServerScriptService/TrainingHandlers.lua
-- Usa _G.DATA / _G.MONSTERGENERATOR / atributo Userid para achar o monstro
-- Chama TrainingSystem.StartSession e notifica o cliente

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SelectTrainingEvent = Remotes:WaitForChild("SelectTrainingEvent")
local OpenTrainingUIEvent = Remotes:WaitForChild("OpenTrainingUIEvent")
local UpdateTrainingStatsEvent = Remotes:WaitForChild("UpdateTrainingStatsEvent")
wait(1)
local TrainingSystem = require(game.ServerScriptService.Main.TrainingSystem.Main)

-- ========= helpers de resolução do monstro =========

local function findWorkspaceOwned(uid: number): Instance?
	for _,inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("Model") and inst:GetAttribute("OwnerId") == uid then
			return inst
		end
	end
	return nil
end

-- tente suas fontes “oficiais” primeiro
local function getPlayerMonster(player: Player): Instance?
	local uid = player.UserId

	-- 1) Registro próprio (_G.MONSTERGENERATOR / _G.DATA / etc.)
	-- Ajuste aqui se você tiver métodos específicos:
	-- ex: if _G.MONSTERGENERATOR and _G.MONSTERGENERATOR.GetActiveInstance then ...
	if _G and _G.DATA and typeof(_G.DATA.GetActiveMonsterInstance) == "function" then
		local inst = _G.DATA:GetActiveMonsterInstance(uid)
		if inst then return inst end
	end
	if _G and _G.MONSTERGENERATOR and typeof(_G.MONSTERGENERATOR.GetActiveInstance) == "function" then
		local inst = _G.MONSTERGENERATOR:GetActiveInstance(uid)
		if inst then return inst end
	end

	-- 2) Fallback: procurar no Workspace por Userid
	return findWorkspaceOwned(uid)
end

-- ========= handlers =========

SelectTrainingEvent.OnServerEvent:Connect(function(player: Player, trainingType: string)
	if typeof(trainingType) ~= "string" then return end

	local monster = getPlayerMonster(player)
	print(typeof(monster))
	if not monster then
		warn("[Training] Nenhum monstro encontrado para", player.Name)
		return
	end
	local ctx = {}
	print(trainingType)
	if trainingType == "BoulderCarry" then
		 ctx = {
			Start = workspace.Training.BoulderCarry.Start,
			End = workspace.Training.BoulderCarry.Finish,
			NodesFolder = workspace.Training.BoulderCarry.Nodes,
			Boulder = workspace.Training.BoulderCarry.Interactables.Boulder,
			FailAtIndex = 2,       -- perna 2->3
			FailAtFraction = 0.5,  -- 50% da perna
		}
	elseif trainingType == "RockSmash" then
		 ctx = {
			Start = workspace.Training.RockSmash:WaitForChild("Start"),
			Boulder = workspace.Training.RockSmash.Interactables
		 }
	elseif trainingType == "Sprint" then
		ctx = {
			Start = workspace.Training.Sprint:WaitForChild("Start"),
			NodesFolder = workspace.Training.Sprint:WaitForChild("Nodes"),
		}
	elseif trainingType == "MindBend" then
		ctx = {
			Start = workspace.Training.MindBend:WaitForChild("Start"),
			Interactables = workspace.Training.MindBend:WaitForChild("Interactables")
		}
	elseif trainingType == "WhackAMole" then
		ctx = {
			Start = workspace.Training.WhackAMole:WaitForChild("Start"),
			Interactables = workspace.Training.WhackAMole:WaitForChild("Interactables")
		}
	elseif trainingType == "LuckyBlocks" then
		ctx = {
			Start = workspace.Training.LuckyBlocks:WaitForChild("Start"),
			Interactables = workspace.Training.LuckyBlocks:WaitForChild("Interactables"),
			Nodes = workspace.Training.LuckyBlocks:WaitForChild("Nodes")
		}
	end
	
	
	TrainingSystem:Start(player, monster, trainingType, ctx)

end)
