function reset()
end

function actualReset()
  if not self.techstationId then return end
  for i = 1, 3 do
    world.sendEntityMessage(self.techstationId, 'storeData', 'aiDataItemSlot' .. i, nil)
  end
  world.sendEntityMessage(self.techstationId, 'setImage', nil)
  world.sendEntityMessage(self.techstationId, 'setInterfaceObj', nil)
  widget.setItemSlotItem('itemSlot', nil)
end

function manageButtonProgressThingies(progressValue, callback, widgetPath, buttonWidget, progressBarWidget)

end

function init()
  dt = script.updateDt()
  self.askConsoleUId = world.sendEntityMessage(player.id(), "gibTargetUId")
  self.askDataKindly = nil
  self.techstationId = nil
  self.progress = 0
  widget.setItemSlotProgress('itemSlot', 0)
end


function itemSlot(widgetName)
  if self.techstationId then
    local swapItem = player.swapSlotItem()
    local objectConfig = root.itemConfig(swapItem)
    local imageConfig = nil
    if swapItem then
      if objectConfig.config.uniqueId ~= self.techstationId then return end
      --I could probably get all those datas from the object's script and send the itemDescriptor directly but rip
      imageConfig = objectConfig.config.orientations[1] 
      imageConfig.imagePath = objectConfig.directory .. imageConfig.imageLayers[1].image or imageConfig.imageLayers[2].image
      imageConfig.imageLayers = nil
    end

    local currentItem = widget.itemSlotItem(widgetName)
    world.sendEntityMessage(self.techstationId, 'setImage', imageConfig)
    world.sendEntityMessage(self.techstationId, 'setInterfaceObj', swapItem)
    player.setSwapSlotItem(currentItem)
    widget.setItemSlotItem('itemSlot', swapItem)
  end
end

function update()
  if self.askConsoleUId and self.askConsoleUId:succeeded() then
    self.techstationId = self.askConsoleUId:result()
    widget.setVisible('itemSlot', true)
    self.askConsoleUId = nil
    widget.setItemSlotProgress('itemSlot', 1)
  end

  if widget.getChecked('resetButton') then
    if self.progress < 1 then
      self.progress = math.min(self.progress + 1 * dt, 1)
    elseif self.progress >= 1 then
      widget.setVisible('itemSlot' .. 'progress' .. 'End', true)
      actualReset()
      widget.setChecked('resetButton', false)
    end
  else
    if self.progress > 0 then
      self.progress = math.max(self.progress - 1.5 * dt, 0)
    end
  end
  if self.progress > 0 then
    widget.setVisible('resetButton' .. 'Progress', true)
  else
    widget.setVisible('resetButton' .. 'Progress', false)
    widget.setVisible('resetButton' .. 'Progress' .. 'End', false)
    widget.setItemSlotProgress('itemSlot', 1)
  end
  
  widget.setProgress('resetButton' .. 'Progress', self.progress)
  widget.setItemSlotProgress('itemSlot', 1 - self.progress)

  if self.techstationId and not self.ineedsomevartocheck then
    if not self.askDataKindly then self.askDataKindly = world.sendEntityMessage(self.techstationId, 'gibInterfaceObj') end
    if self.askDataKindly:succeeded() then
      self.ineedsomevartocheck = "pls" --funfact at one point I was setting this to result(), and using it instead of result() below, so if it was
      widget.setItemSlotItem('itemSlot', self.askDataKindly:result()) -- nil it'd set the item slot to nil at each tick, even after the player changes it
    end --it took me way too long to realize
  end
end


function close()
  pane.dismiss()
end