function init()
  objectConfig = root.itemConfig(config.getParameter("techStationName"))
  imageConfig = objectConfig.config.orientations[1]
  imageConfig.imagePath = objectConfig.directory .. imageConfig.imageLayers[1].image or imageConfig.imageLayers[2].image
  imageConfig.imageLayers = nil
end

function activate()
  local target = world.objectAt(activeItem.ownerAimPosition())
  if target and world.entityName(target):find("techstation") > 0 then
    world.sendEntityMessage(target, "setImage", imageConfig)
  end
end