-- ServerScriptService/Main/Zones/ZoneUISystem.lua
-- Qualquer BasePart com Tag "ZoneUI" e uma Tag no formato "UI:<ScreenGuiName>"
-- abrirá a UI correspondente quando o jogador tocar.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local OpenTrainingUIEvent = Remotes:WaitForChild("OpenTrainingUIEvent") -- usado para TrainingUI
-- Reaproveite este padrão: você pode ter outros eventos se quiser UIs diferentes

local function extractUINameFromTags(instance: Instance): string?
	if not instance then return nil end
	local tags = CollectionService:GetTags(instance)
	for _,tag in ipairs(tags) do
		-- valor da UI codificado no nome da tag: UI:<NomeDaUI>
		local uiName = string.match(tag, "^UI:(.+)$")
		if uiName then return uiName end
	end
	return nil
end

local function prefillStatsFor(player: Player)
	-- preenche stats lendo atributos do monstro do player (OwnerId)
	local uid = player.UserId
	local monster
	for _,inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("Model") and tonumber(inst:GetAttribute("OwnerId") or 0) == uid then
			monster = inst; break
		end
	end
	local stats = {}
	for _,name in ipairs({"Strength","Defense","Skill","Speed","Intelligence","Luck"}) do
		stats[name] = monster and (monster:GetAttribute(name) or 0) or 0
	end
	return stats
end

local function hookZone(part: BasePart)
	if not part or not part:IsA("BasePart") then return end
	if not CollectionService:HasTag(part, "ZoneUI") then return end

	local uiName = extractUINameFromTags(part)
	if not uiName then
		warn("[ZoneUISystem] Parte com 'ZoneUI' sem tag 'UI:<Name>' ->", part:GetFullName())
		return
	end

	local touching = {}

	part.Touched:Connect(function(hit)
		local plr = Players:GetPlayerFromCharacter(hit and hit.Parent)
		if not plr or touching[plr] then return end
		touching[plr] = true

		if uiName == "TrainingUI" then
			OpenTrainingUIEvent:FireClient(plr, { stats = prefillStatsFor(plr) })
		else
			-- se tiver outras UIs, dispare seus próprios eventos aqui
			print("[ZoneUISystem] UI desconhecida:", uiName)
		end

		task.delay(1, function() touching[plr] = nil end)
	end)
end

-- inicial
for _,inst in ipairs(CollectionService:GetTagged("ZoneUI")) do
	hookZone(inst)
end

CollectionService:GetInstanceAddedSignal("ZoneUI"):Connect(hookZone)
