require "/scripts/util.lua"

function init()
	self.rpc = nil
	self.targetId = nil

	--that's kinda messy but ahwell
	message.setHandler("gibTargetUId", function() if self.targetId then return world.entityUniqueId(self.targetId) or self.targetId end end)
end

function activate()
  self.targetId = world.objectAt(activeItem.ownerAimPosition())
  if self.targetId then
    self.rpc = world.sendEntityMessage(self.targetId, "screwdriverInteraction")
  --if world.isNpc(self.targetId) then --oops forgot that callScriptedEntity would only work on client stuff in this context so rip
  	--world.callScriptedEntity(self.targetId, npc.say, "Are you trying to screw me over?")
  	--end
  end
end

function update()
	local aimAngle, direction = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
	activeItem.setArmAngle(aimAngle)
	activeItem.setFacingDirection(direction)

	if self.rpc then
		if self.rpc:succeeded() then
			local rpcResult = self.rpc:result()
			if rpcResult[1] and rpcResult[2] then
				activeItem.interact(rpcResult[1], rpcResult[2])
			end
		end
		if self.rpc:finished() then
			self.rpc = nil
			return
		end
	end
end