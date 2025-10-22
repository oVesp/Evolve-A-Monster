-- ServerScriptService>Main>TrainingSystem>Trainings>Sprint.lua

local module = {}

local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Utils = require(script.Parent.Parent.Utils)
local Functions =_G.FUNCTIONS

module.BaseBonus = {
	Speed = 2,
}

function module:Start(monster: Model, player: Player, ctx: table)
	assert(monster and player and ctx, "Sprint training requires monster, player, and context")

	local nodesFolder = ctx.NodesFolder
	local startPart = ctx.Start

	if not nodesFolder or not nodesFolder:IsA("Folder") then
		warn("[Sprint] Missing or invalid NodesFolder")
		return { success = false, reason = "invalid_nodes" }
	end

	if not startPart or not startPart:IsA("BasePart") then
		warn("[Sprint] Missing or invalid Start part")
		return { success = false, reason = "invalid_start" }
	end

	local nodes = nodesFolder:GetChildren()
	table.sort(nodes, function(a, b) return a.Name < b.Name end)

	if #nodes < 2 then
		warn("[Sprint] Not enough nodes for path")
		return { success = false, reason = "not_enough_nodes" }
	end

	local humanoid = monster:FindFirstChildOfClass("Humanoid")
	if not humanoid or not monster.PrimaryPart then
		warn("[Sprint] Monster missing Humanoid or PrimaryPart")
		return { success = false, reason = "bad_monster" }
	end

	-- Teleport monster to the start position
	monster:PivotTo(startPart.CFrame + Vector3.new(0, 3, 0))
	RunService.Heartbeat:Wait()

	-- Adjust WalkSpeed based on Speed stat (range 0-999 → scaled to 8–24)
	local speedStat = monster:GetAttribute("Speed") or 0
	local walkSpeedMult = math.clamp(speedStat / 999, 0, 1)
	local baseSpeed = 16
	local finalSpeed = math.clamp(baseSpeed * (0.5 + 1.0 * walkSpeedMult), 8, 24)
	local originalSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = finalSpeed

	local success = true
	local failedAt = nil

	for i, node in ipairs(nodes) do
		humanoid:MoveTo(node.Position)
		local timeout = 9
		local reached = false

		local conn = humanoid.MoveToFinished:Connect(function(reachedTarget)
			reached = reachedTarget
		end)

		local startTime = tick()
		while not reached and tick() - startTime < timeout do
			RunService.Heartbeat:Wait()
		end
		conn:Disconnect()

		if not reached then
			warn("[Sprint] Timeout reaching node", node.Name)
			-- Still count as movement, don't fail
		end

		-- Random fail chance after midpoint
		if i >= math.floor(#nodes / 2) and math.random() < 0.3 then
			warn("[Sprint] Monster failed randomly during sprint")

			-- Cinematic fail
			local EvFail = ReplicatedStorage.Remotes:FindFirstChild("TrainingCameraFail")
			if EvFail then
				EvFail:FireClient(player, monster, {
					duration = 1.3,
					heightStart = 6,
					heightEnd = 7.5,
					radiusStart = 12,
					radiusEnd = 9,
					angularSpeedDeg = 55,
					fovStart = 70,
					fovEnd = 62,
				})
			end

			-- Death animation + freeze
			Functions.playDeathFrozen(monster, 0.65, 1.8)

			-- Wait before restoring camera (simulate BoulderCarry behavior)
			task.wait(2.0)

			success = false
			failedAt = i
			break
		end
	end

	-- Restore original speed
	humanoid.WalkSpeed = originalSpeed

	if success then
		return { success = true }
	else
		return { success = false, reason = "random_fail", failedAt = failedAt }
	end
end

return module