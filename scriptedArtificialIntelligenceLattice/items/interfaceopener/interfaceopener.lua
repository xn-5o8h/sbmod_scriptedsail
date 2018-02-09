function init()
	activeItem.interact(config.getParameter("interactAction"), config.getParameter("interactData"), config.getParameter("techStationId"))
	player.setSwapSlotItem(config.getParameter("swapItem"))
end