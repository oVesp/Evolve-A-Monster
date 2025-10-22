-- TrainingSystem/Main.lua
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Utils = require(script.Parent.Utils)
local MoveUnlocks = require(RS.Modules.MoveUnlocks)

-- Registry de módulos de treino (lazy require)
local TrainingsFolder = script.Parent.Trainings
local TrainingCache = {}

local Remotes = RS:FindFirstChild("Remotes") or Instance.new("Folder", RS)
Remotes.Name = "Remotes"
local EvFocus  = Remotes:FindFirstChild("TrainingCameraFocus")  or Instance.new("RemoteEvent", Remotes); EvFocus.Name  = "TrainingCameraFocus"
local EvRestore= Remotes:FindFirstChild("TrainingCameraRestore")or Instance.new("RemoteEvent", Remotes); EvRestore.Name= "TrainingCameraRestore"
local EvFail = Remotes:FindFirstChild("TrainingCameraFail")

local TrainingSystem = {}
TrainingSystem.__index = TrainingSystem

function TrainingSystem:GetModule(name)
	if TrainingCache[name] then return TrainingCache[name] end
	local m = TrainingsFolder:FindFirstChild(name)
	assert(m, "Training module not found: "..tostring(name))
	TrainingCache[name] = require(m)
	return TrainingCache[name]
end

local function resolvePlayerForMonster(fallbackPlayer, monster: Model)
	if typeof(fallbackPlayer) == "Instance" and fallbackPlayer:IsA("Player") then
		return fallbackPlayer
	end
	local oid = monster and monster:GetAttribute("OwnerId")
	if oid then
		return Players:GetPlayerByUserId(tonumber(oid))
	end
	return nil
end

-- Orquestração básica
function TrainingSystem:Start(player: Player, monster: Model, trainingName: string, ctx)
	assert(player and monster and trainingName, "missing args")
	local Mod = self:GetModule(trainingName)

	if _G.MOVEMENT then _G.MOVEMENT.StopFollowing(monster) end

	monster:SetAttribute("InTraining", true)
	if _G.STATES then
		local st = _G.STATES:GetStorage(monster)
		if st and st.Following then
			_G.STATES:RemoveState(monster, "Following", st.Following.self_key)
		end
	end

	EvFocus:FireClient(player, monster, trainingName)

	local result
	local ok, err = pcall(function()
		result = Mod:Start(monster, player, ctx or {})
	end)

	if not ok then
		warn("Training error:", err)
		result = { success = false, reason = "error" }
	end

	local success, failReason = Utils.EvaluateSuccess(monster, player, trainingName, ctx, result)

	monster:SetAttribute("InTraining", nil)
	local targetPlayer = resolvePlayerForMonster(player, monster)
	if targetPlayer then
		EvRestore:FireClient(targetPlayer)
	end

	if monster:GetAttribute("OwnerId") and _G.STATES then
		_G.STATES:SetState(monster, "Following")
	end

	-- Ganhos apenas em sucesso do módulo
	local gains = {}
	if result and result.success == true then
		local owner = monster:GetAttribute("OwnerId")
		if owner and _G.DATA then
			local data = _G.DATA:Get(owner)
			-- Optional: tag some progress to bias unlock odds
			data.MoveProgress = data.MoveProgress or {}
			data.MoveProgress[trainingName] = (data.MoveProgress[trainingName] or 0) + 1

			local gained = MoveUnlocks.ResolveUnlocks(data, "training", {
				training = trainingName
			})
		end
		-- >> START: MODIFIED GAIN LOGIC <<
		-- Check for the special stat_override case from modules like LuckyBlocks
		if result.stat_override then
			print("Applying stat override for training:", Mod.Name)
			gains = result.stat_override -- The gains are provided directly by the module
			Utils.ApplyGains(monster, gains, player)
		else
			-- The normal logic for all other trainings
			local baseBonus = Mod.BaseBonus
			gains = Utils.ComputeGains(monster, baseBonus)
			Utils.ApplyGains(monster, gains, player)
		end
		-- >> END: MODIFIED GAIN LOGIC <<

		_G.EFFECTS.PlaySound("Success", {Where = monster.HumanoidRootPart})
	else
		_G.EFFECTS.PlaySound("Fail", {Where = monster.HumanoidRootPart})
	end

	return result, gains
end

return setmetatable({}, TrainingSystem)