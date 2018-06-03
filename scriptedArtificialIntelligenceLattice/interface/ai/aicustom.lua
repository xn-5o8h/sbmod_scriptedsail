require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/hobo.lua"

--hello, I'm sorry for you if you're reading this, it's basically a mess. I tried making generic functions but I'm trash???
--I should read on some more thingies for gud interface code??? Anyway, good luck down there!
--TODO: lock button for crewmembers to prevent dismissing?

function init()
  if util.count(root.assetJson("/player.config:statusControllerSettings").primaryScriptSources, "/scripts/fu_tilegroundeffects.lua") > 0 then
    --hacky, hopefully they never change that script's name
    sb.logInfo("scriptedSAIL: FU is installed, consider asking them to support your specie's techstation. Loading FU's SAIL...")
    script.setUpdateDelta(0)
    player.interact("ScriptPane", "/interface/scripted/fu_sail/customSail.config", pane.sourceEntity())
    pane.dismiss()
    return
  end

  setWidgetTable()
  dt = script.updateDt()

  self.config = nil
  self.crew = nil
  self.crewPromise = nil
  self.getDataPromise = nil
  self.shipLevel = util.clamp(player.shipUpgrades().shipLevel, 0, 3)
  self.coroutines = {}
  self.callback = nil
  self.aiCanvas = widget.bindCanvas('aiFaceCanvas')

  self.dismissProgress = 0
  self.deployProgress = 0

  self.animationTimer = 0
  self.staticAnimationTimer = 0
  self.scanlineAnimationTimer = 0

  loadConf()
end

function loadConf()
  if self.getDataPromise == nil then self.getDataPromise = world.sendEntityMessage(pane.sourceEntity(), 'returnData') end
  if self.getDataPromise:succeeded() then
    local datas = self.getDataPromise:result()
    if datas and next(datas) then
      for i = 1, 3 do
        local chipItemDesc = datas['aiDataItemSlot' .. tostring(i)]
        if chipItemDesc then
          local itemDesc = root.itemConfig(chipItemDesc.name).config
          if itemDesc and itemDesc.category == "A.I. Chip" then
            local widgetName = 'configRect.aiDataItemSlot' .. tostring(i)
            widget.setItemSlotItem(widgetName, chipItemDesc)
            self.chip = self.chip or {}
            self.chip = util.mergeTable(self.chip, util.mergeTable(itemDesc, chipItemDesc.parameters).aiData)
          end
        end
      end
    end
  else
    if not self.getDataPromise:finished() then return end
  end
  self.getDataPromise = nil

  self.config = root.assetJson("/ai/ai.config")
  self.config = util.mergeTable(self.config, self.config.species[player.species()] or self.config.species['human'])
  self.config.species = nil

  if self.chip then
    self.config = util.mergeTable(self.config, self.chip)
    self.chip = nil
  end


  self.missions = guessMissions() --we don't have lua bindings for missions, so I'm guessing based on quests for vanilla, and look into config for modded ones.
  --probably no need for that big of a thing but having a serialized script is nice and it could help to sprEAD KNOWLEDGE ABOUT THAT TRICK
  if not self.setportrait then self.setportrait = world.sendEntityMessage(player.id(), 'setDefaults', "SAILportrait", self.config.questPortrait) end
  if self.setportrait:finished() then self.setportrait = nil end

  self.animation = self.config.defaultAnimation

  pane.setTitle(self.config.title, self.config.subtitle)
  pane.setTitleIcon(self.config.titleIcon)
  widget.setButtonEnabled("config", true)
  widget.setButtonEnabled("backButton", true)
  widget.setButtonEnabled("showCrew", true)
  widget.setButtonEnabled("showMissions", true)

  self.fontSize = root.assetJson("/interface.config").font.baseSize

  setBreadcrumb('homeBreadcrumb', nil, self.config.interfaceText.homeBreadcrumbText)

  widget.setText("showCrew", self.config.interfaceText.buttonCrewText)
  widget.setText("showMissions", self.config.interfaceText.buttonMissionsText)
  widget.setText("CrewRect.CrewRect.dismissTextThisIsMessy", self.config.interfaceText.buttonDismissText)
  widget.setText("missionsRect.missionSelectRect.startMissionTextThisIsMessy", self.config.interfaceText.buttonDeployText)
  widget.setText("backButton", self.config.interfaceText.buttonBackText)
  widget.setText('configRect.openAIChipSlotButton', self.config.interfaceText.buttonOpenSlotText)
  widget.setText('configRect.fallbackButton', self.config.interfaceText.buttonFallbackText)
  widget.setText('configRect.openAIChipCraftButton', self.config.interfaceText.buttonOpenCraftingText)

  self.callback()
  self.callback = nil
end

function update()
  if self.config == nil then
    if not self.callback then self.callback = showShipStatus end
    setWidgets(self.lazy.hideButtons)
    loadConf()
    return
  end

  --since most actions are basically instant, I'm using that for loading wait thingy (currently only for config changes but shhht)
  if self.updateOverwriteCoroutine then
    coroutine.resume(self.updateOverwriteCoroutine)
    return
  end

  if self.crew == nil then
    widget.setButtonEnabled("showCrew", false)
    if self.crewPromise == nil then self.crewPromise = world.sendEntityMessage(player.id(), 'returnCompanions') end
    if self.crewPromise:succeeded() then
      widget.setButtonEnabled("showCrew", true)
      self.crew = self.crewPromise:result()
      self.crewPromise = nil
    end
  end

  --literally stole that from sbvn godbless
  self.coroutines = util.filter(self.coroutines, function(co)
      local s, r = coroutine.resume(co)
      return s
    end)

  -- I don't think I should do that as a coroutine? But I probably can do it better...
  self.dismissProgress = manageButtonProgressThingies(self.dismissProgress, dismiss, 'CrewRect.CrewRect.', 'dismissRecruit', 'dismissProgress')
  self.deployProgress = manageButtonProgressThingies(self.deployProgress, deploy, 'missionsRect.missionSelectRect.', 'startMission', 'startMissionProgress')

  self.aiCanvas:clear()
  self.animationTimer = updatePortrait(self.config.aiAnimations[self.animation], self.animationTimer or 0, self.config.aiFrames)
  self.staticAnimationTimer = updatePortrait(self.config.staticAnimation, self.staticAnimationTimer or 0, self.config.staticFrames, '?multiply=' .. rgbToHex({255, 255, 255, math.floor(self.config.staticOpacity * 255)}))
  self.scanlineAnimationTimer = updatePortrait(self.config.scanlineAnimation, self.scanlineAnimationTimer or 0, self.config.scanlinesFrames, '?multiply=' .. rgbToHex({255, 255, 255, math.floor(self.config.scanlineOpacity * 255)}))
end

function updatePortrait(animationConfig, timerVariable, imagePath, processing, debug)
  animationConfig.animationCycle = animationConfig.animationCycle or 3
  local frame = math.floor((timerVariable / animationConfig.animationCycle) * animationConfig.frameNumber)
  if timerVariable == 0 then frame = 0 end

  timerVariable = timerVariable + dt

  if timerVariable > animationConfig.animationCycle then
    if animationConfig.mode == 'loopForever' then
      timerVariable = 0
    elseif animationConfig.mode == 'stop' then
      timerVariable = animationConfig.animationCycle + 1 --not sure if it's necessary but I don't really want a forever-increasing variable?
      frame = animationConfig.frameNumber - 1 --frames start at 0 but their count starts at 1 zzzzz
    end
  end

  local path = animationConfig.frames:gsub('<image>', imagePath):gsub("<index>", frame) .. (processing or '')
  self.aiCanvas:drawImage('/ai/' .. path, {0, 0})

  if debug then
    self.aiCanvas:drawText(
      timerVariable .. '/' .. animationConfig.animationCycle .. '\n' .. frame .. '/' .. animationConfig.frameNumber,
      {position = {0, 0}, horizontalAnchor = "left", verticalAnchor = "bottom"},
      8, {50,210,50,210}
    )
  end

  return timerVariable
end

function manageButtonProgressThingies(progressValue, callback, widgetPath, buttonWidget, progressBarWidget)
  if widget.getChecked(widgetPath .. buttonWidget) then
    if progressValue < 1 then
      progressValue = math.min(progressValue + 1 * dt, 1)
    elseif progressValue >= 1 then
      widget.setVisible(widgetPath .. progressBarWidget .. 'End', true)
      callback()
    end
  elseif progressValue > 0 then
    progressValue = math.max(progressValue - 1.5 * dt, 0)
  end

  if progressValue > 0 then
    widget.setVisible(widgetPath .. progressBarWidget, true)
    widget.setProgress(widgetPath .. progressBarWidget, progressValue)
  else
    widget.setVisible(widgetPath .. progressBarWidget, false)
    widget.setVisible(widgetPath .. progressBarWidget .. 'End', false)
  end

  return progressValue
end

function writeStuff(widgetName, dialog)
  local text = dialog.text

  self.animation = dialog.animation
  pane.stopAllSounds(self.config.chatterSound)

  local co = coroutine.create(function()
    local ratio = 0
    local rate = dt / (utf8.len(text) / (self.config.charactersPerSecond * dialog.speedModifier))
    local skip = 0
    pane.playSound(self.config.chatterSound, 1000)

    while ratio < 1.0 do
      ratio = math.min(1.0, ratio + rate)

      local i = math.ceil(ratio * utf8.len(text)) + skip
      if i < utf8.len(text) then
        if utf8.sub(text, i,i) == '^' then
          local tagLen = utf8.len(utf8.sub(text, i, utf8.len(text)):match('%^#?[%a%d]-;'))
          skip = skip + tagLen
          i = i + tagLen
        end
        local outStr = utf8.sub(text, 1, i)
        --we strip all \n and ^colortag; from the text because ^clear; stops at newlines, and is a color itself with 0 alpha, so stops at other colortags
        widget.setText(widgetName, outStr .. '^clear;' .. utf8.sub(text, i + 1, utf8.len(text)):gsub('%^#?[%a%d]-;', ''):gsub('\n', '\n^clear;'))
      else
        resetidunno()
        widget.setText(widgetName, text)
      end

      coroutine.yield()
    end
  end)

  coroutine.resume(co)
  table.insert(self.coroutines, co)
end

function showShipStatus()
  setWidgets(self.lazy.shipStatusRect)
  writeStuff("shipStatusRect.shipStatusText", self.config.shipStatus[tostring(self.shipLevel)])
end

function showMissions()
  resetidunno()
  self.coroutines = {}
  widget.clearListItems('missionsRect.scrollArea.missionItemList') 

  setWidgets(self.lazy.missionsRect)
  setBreadcrumb('pageBreadcrumb', 'homeBreadcrumb', self.config.interfaceText.missionBreadcrumbText)

  if not self.missions or not next(self.missions) then
    writeStuff("missionsRect.noMissionsText", self.config.noMissionsSpeech) --might need to reposition the text widget? I'll check later
    widget.setVisible('missionsRect.noMissionsText', true)
  else
    widget.setVisible('missionsRect.scrollArea', true)
    widget.setVisible('missionsRect.scrollArea.missionItemList', true)



    for _,mission in ipairs(self.missions) do
      local listItem = widget.addListItem('missionsRect.scrollArea.missionItemList')
      widget.setData('missionsRect.scrollArea.missionItemList.' .. listItem, mission)
      widget.setImage('missionsRect.scrollArea.missionItemList.' .. listItem .. '.itemIcon', '/ai/' .. mission.icon)
      if mission.repeated then
        widget.setText('missionsRect.scrollArea.missionItemList.' .. listItem .. '.itemName', mission.repeatButtonText)
      else
        widget.setText('missionsRect.scrollArea.missionItemList.' .. listItem .. '.itemName', mission.buttonText)
      end
    end
  end
end

function showMissionSelect()
  if self.missions == nil then return end

  widget.setVisible('missionsRect.missionSelectRect', true)
  widget.setVisible('missionsRect.scrollArea', false)

  local selection = widget.getListSelected('missionsRect.scrollArea.missionItemList')
  if selection then
    local mission = widget.getData('missionsRect.scrollArea.missionItemList.' .. selection)

    setBreadcrumb('itemBreadcrumb', 'pageBreadcrumb', self.config.interfaceText.buttonDeployText)

    widget.setText('missionsRect.missionSelectRect.missionName', mission.buttonText)
    widget.setImage('missionsRect.missionSelectRect.missionIcon', '/ai/' .. mission.icon)
    
    writeStuff("missionsRect.missionSelectRect.missionText", mission.selectSpeech)
  end
end

function deploy()
  local selection = widget.getListSelected('missionsRect.scrollArea.missionItemList')
  if selection then
    local buttonWidgetName = 'missionsRect.missionSelectRect.startMission'
    if widget.getChecked(buttonWidgetName) then
      widget.setChecked(buttonWidgetName, false)
      widget.setText('missionsRect.missionSelectRect.startMissionTextThisIsMessy', self.config.interfaceText.buttonDeployText)
    else
      widget.setChecked(buttonWidgetName, true)
      widget.setText('missionsRect.missionSelectRect.startMissionTextThisIsMessy', self.config.interfaceText.buttonCancelText)
    end

    if self.deployProgress >= 1 then
      local mission = widget.getData('missionsRect.scrollArea.missionItemList.' .. selection)
      player.warp('instanceworld:' .. mission.missionWorld, 'beam')
      close()
    end
  end
end

function showCrew()
  resetidunno()
  self.coroutines = {}

  --should I do that, or change where that list is populated? I'm not sure what vanilla one does but it seems to retrive realtime portraits so this seems gud?
  widget.clearListItems('CrewRect.scrollArea.crewItemList') 

  setWidgets(self.lazy.crewRect)
  setBreadcrumb('pageBreadcrumb', 'homeBreadcrumb', self.config.interfaceText.crewBreadcrumbText)

  if not next(self.crew) then
    writeStuff("CrewRect.noCrewText", self.config.noCrewSpeech) 
    widget.setVisible('CrewRect.noCrewText', true)
  else
    widget.setVisible('CrewRect.scrollArea', true)
    widget.setVisible('CrewRect.scrollArea.crewItemList', true)

    for _,crewMember in ipairs(self.crew) do
      local listItem = widget.addListItem('CrewRect.scrollArea.crewItemList')
      widget.setText('CrewRect.scrollArea.crewItemList.' .. listItem .. '.itemName', crewMember.name)
      widget.setData('CrewRect.scrollArea.crewItemList.' .. listItem, crewMember)
      local itemIcon = widget.bindCanvas('CrewRect.scrollArea.crewItemList.' .. listItem .. '.itemIcon')
      for _,portrait in pairs(crewMember.portrait) do
        itemIcon:drawImage(portrait.image, {-15.5, -19.5})
      end
    end
  end
end

function showCrewMember()
  if self.crew == nil then return end

  widget.setVisible('CrewRect.CrewRect', true)
  widget.setVisible('CrewRect.scrollArea', false)

  local selection = widget.getListSelected('CrewRect.scrollArea.crewItemList')
  if selection then
    local crewMember = widget.getData('CrewRect.scrollArea.crewItemList.' .. selection)
    crewMember.name = crewMember.name or self.config.interfaceText.defaultRecruitName
    crewMember.description = crewMember.description or self.config.interfaceText.defaultRecruitDescription

    setBreadcrumb('itemBreadcrumb', 'pageBreadcrumb', crewMember.name)

    widget.setText('CrewRect.CrewRect.recruitName', crewMember.name)
    local recruitIcon = widget.bindCanvas('CrewRect.CrewRect.recruitIcon')
    for _,portrait in pairs(crewMember.portrait) do
      recruitIcon:drawImage(portrait.image, {-15.5, -19.5})
    end
    writeStuff("CrewRect.CrewRect.recruitText", {text = crewMember.description, animation = "talk", speedModifier = 0.7})
  end
end

function dismiss()
  local selection = widget.getListSelected('CrewRect.scrollArea.crewItemList')
  if selection then
    local buttonWidgetName = 'CrewRect.CrewRect.dismissRecruit'
    if widget.getChecked(buttonWidgetName) then
      widget.setChecked(buttonWidgetName, false)
      widget.setText('CrewRect.CrewRect.dismissTextThisIsMessy', self.config.interfaceText.buttonDismissText)
    else
      widget.setChecked(buttonWidgetName, true)
      widget.setText('CrewRect.CrewRect.dismissTextThisIsMessy', self.config.interfaceText.buttonCancelText)
    end

    if self.dismissProgress >= 1 then
      local crewMember = widget.getData('CrewRect.scrollArea.crewItemList.' .. selection)
      world.sendEntityMessage(player.id(), 'dismissCompanion', crewMember.podUuid)
      self.crew = util.filter(self.crew, function(crew) if crew.podUuid ~= crewMember.podUuid then return true end end)

      widget.setVisible('CrewRect.CrewRect.dismissProgress', false)
      widget.setProgress('CrewRect.CrewRect.dismissProgress', 0)
      widget.setVisible('CrewRect.CrewRect.dismissProgressEnd', false)

      goBack()
    end
  end
end

function showConfig()
  resetidunno()
  --self.coroutines = {}
  setWidgets(self.lazy.configRect)
  if self.config.disableChipSlot then
    widget.setButtonEnabled('configRect.openAIChipSlotButton', false)
    widget.setButtonEnabled('configRect.openAIChipCraftButton', false)
  end
  setBreadcrumb('pageBreadcrumb', 'homeBreadcrumb', self.config.interfaceText.configBreadcrumbText)
  writeStuff('configRect.fallbackText',  {text = self.config.interfaceText.fallbackText, animation = "talk", speedModifier = 1})
  writeStuff('configRect.aiDataText',  {text = self.config.interfaceText.aiDataText, animation = "talk", speedModifier = 1})
  
  widget.setProgress('configRect.chipSlotHatchLeftTest', 1)
  widget.setProgress('configRect.chipSlotHatchRightTest', 1)
end

function fallbackButton()
  if widget.getChecked('configRect.fallbackButton') then
    world.sendEntityMessage(pane.sourceEntity(), 'setFallback', true)
    writeStuff('configRect.fallbackText', {text = self.config.interfaceText.fallbackActivatedText, animation = "talk", speedModifier = 1})
  else
    writeStuff('configRect.fallbackText',  {text = self.config.interfaceText.fallbackText, animation = "talk", speedModifier = 1})
  end
end

function openAIChipSlot()
  if widget.getChecked('configRect.openAIChipSlotButton') then
    widget.setText('configRect.openAIChipSlotButton', self.config.interfaceText.buttonCloseSlotText)

    widget.setVisible('configRect.aiDataItemSlot', true)
    widget.setVisible('configRect.chipSlotHatchLeftTest', true)
    widget.setProgress('configRect.chipSlotHatchLeftTest', 1)

    local co = coroutine.create(function()
      local progress = 1

      while progress > 0 and widget.getChecked('configRect.openAIChipSlotButton') do
        progress = math.max(progress - 1 * dt, 0)
        widget.setProgress('configRect.chipSlotHatchLeftTest', progress)
        coroutine.yield()
      end
      if widget.getChecked('configRect.openAIChipSlotButton') then
        widget.setProgress('configRect.chipSlotHatchLeftTest', 0)
        widget.setVisible('configRect.chipSlotHatchLeftTest', false)
      end
    end)

    coroutine.resume(co)
    table.insert(self.coroutines, co)
  else
    widget.setText('configRect.openAIChipSlotButton', self.config.interfaceText.buttonOpenSlotText)

    widget.setProgress('configRect.chipSlotHatchLeftTest', 0)
    widget.setVisible('configRect.chipSlotHatchLeftTest', true)

    local co = coroutine.create(function()
      local progress = 0

      while progress < 1  and not widget.getChecked('configRect.openAIChipSlotButton') do
        progress = math.min(progress + 1 * dt, 1)
        widget.setProgress('configRect.chipSlotHatchLeftTest', progress)
        coroutine.yield()
      end
      if not widget.getChecked('configRect.openAIChipSlotButton') then
        widget.setProgress('configRect.chipSlotHatchLeftTest', 1)
        widget.setVisible('configRect.aiDataItemSlot', false)
      end
    end)

    coroutine.resume(co)
    table.insert(self.coroutines, co)
  end
end

function showLoading() -- I really don't like rewriting the whole thing again, but that's the only easy way I found to add the tiny bits I needed??
  resetidunno()
  setWidgets(self.lazy.hideButtons)
  local text = self.config.interfaceText.overwrittingConfText
  self.animation = "unique"

  self.updateOverwriteCoroutine = coroutine.create(function()
  --local co = coroutine.create(function()
    local ratio = 0
    local rate = dt / (utf8.len(text) / self.config.charactersPerSecond)
    local skip = 0
    pane.playSound(self.config.chatterSound, 1000)

    while ratio < 1.0 do
      ratio = math.min(1.0, ratio + rate)

      local i = math.ceil(ratio * utf8.len(text)) + skip
      if i < utf8.len(text) then
        if utf8.sub(text, i,i) == '^' then
          local tagLen = utf8.len(utf8.sub(text, i, utf8.len(text)):match('%^#?[%a%d]-;'))
          skip = skip + tagLen
          i = i + tagLen
        end
        local outStr = utf8.sub(text, 1, i)
        --we strip all \n and ^colortag; from the text because ^clear; stops at newlines, and is a color itself with 0 alpha, so stops at other colortags
        pane.setTitle(self.config.title, outStr .. '^clear;' .. utf8.sub(text, i + 1, utf8.len(text)):gsub('%^#?[%a%d]-;', ''):gsub('\n', '\n^clear;'))
      else
        resetidunno()
        pane.setTitle(self.config.title, text)
      end

      widget.setItemSlotProgress('configRect.aiDataItemSlot', ratio)
      self.aiCanvas:clear()
      self.animationTimer = updatePortrait(self.config.aiAnimations[self.animation], self.animationTimer, self.config.aiFrames)
      self.staticAnimationTimer = updatePortrait(self.config.staticAnimation, self.staticAnimationTimer, self.config.staticFrames, '?multiply=' .. rgbToHex({255, 255, 255, math.floor(self.config.staticOpacity * 255)}))
      self.scanlineAnimationTimer = updatePortrait(self.config.scanlineAnimation, self.scanlineAnimationTimer, self.config.scanlinesFrames, '?multiply=' .. rgbToHex({255, 255, 255, math.floor(self.config.scanlineOpacity * 255)}))
      coroutine.yield()
    end

    self.updateOverwriteCoroutine = nil
    self.config = nil
    loadConf()
  end)

  coroutine.resume(self.updateOverwriteCoroutine)
  --coroutine.resume(co)
  --table.insert(self.coroutines, co)
end

function aiDataItemSlot(widgetName)
  if not widget.active('configRect.chipSlotHatchLeftTest') and not self.updateOverwriteCoroutine then
    local swapItem = player.swapSlotItem()
    if (swapItem and root.itemConfig(swapItem).config.category == "A.I. Chip") or not swapItem then
      local currentItem = widget.itemSlotItem('configRect.' .. widgetName)
      player.setSwapSlotItem(currentItem)
      widget.setItemSlotItem('configRect.' .. widgetName, swapItem)
      world.sendEntityMessage(pane.sourceEntity(), 'storeData', widgetName, swapItem)
      self.callback = showConfig
      loadConf()
      showLoading()
    end
  end
end

function openAIChipCraft()
  local interactData = {
    config = "/interface/windowconfig/craftingmerchant.config",
    --disableTimer = false,
    paneLayoutOverride = {
      windowtitle = {
        title = self.config.interfaceText.craftingTitle,
        subtitle = self.config.interfaceText.craftingSubtitle,
        icon = { file = self.config.titleIcon }
      },
      lblSchematics = { value = self.config.interfaceText.craftingSchematicsTxt },
      lblProducttitle = { value = self.config.interfaceText.craftingProductTxt },
      btnCraft = { caption = self.config.interfaceText.buttonCraft },
      btnStopCraft = { caption = self.config.interfaceText.buttonStopCraft },
      lblProduct = { value = self.config.interfaceText.craftingMatAvailTxt },
      imgPlayerMoneyIcon = { visible = false },
      lblPlayerMoney = { visible = false }
    },
    filter = { "aichip" }
  }

  player.interact("OpenCraftingInterface", interactData, pane.sourceEntity())
  pane.dismiss()
end

function goBack()
  self.coroutines = {}

  if widget.active('itemBreadcrumb') then
    local prevBcTxt = widget.getData('pageBreadcrumb') --I'd have prefered to use widget.getText() but it only works on textBoxWidget aaa
    if prevBcTxt == self.config.interfaceText.crewBreadcrumbText then
      self.dismissProgress = 0

      widget.setChecked('CrewRect.CrewRect.dismissRecruit', false)
      widget.setVisible('CrewRect.CrewRect.dismissProgress', false)
      widget.setProgress('CrewRect.CrewRect.dismissProgress', 0)
      widget.setVisible('CrewRect.CrewRect.dismissProgressEnd', false)
      widget.setText('CrewRect.CrewRect.dismissTextThisIsMessy', self.config.interfaceText.buttonDismissText)

      resetidunno()
      showCrew()
    elseif prevBcTxt == self.config.interfaceText.missionBreadcrumbText then
      self.deployProgress = 0

      widget.setChecked('missionsRect.missionSelectRect.startMission', false)
      widget.setVisible('missionsRect.missionSelectRect.startMissionProgress', false)
      widget.setProgress('missionsRect.missionSelectRect.startMissionProgress', 0)
      widget.setVisible('missionsRect.missionSelectRect.startMissionProgress', false)
      widget.setText('missionsRect.missionSelectRect.startMissionTextThisIsMessy', self.config.interfaceText.buttonDeployText)

      resetidunno()
      showMissions()
    end
  elseif widget.active('pageBreadcrumb') then
    resetidunno()
    showShipStatus()
  end
end

function setBreadcrumb(breadcrumb, prevBreadcrumb, text)
  widget.setText(breadcrumb, text)
  widget.setData(breadcrumb, text)

  local mult = 1
  if prevBreadcrumb then
    mult = 2 --I don't feel like this is very ellegant but ahwell

    prevBcPos = widget.getPosition(prevBreadcrumb .. 'Bg')
    prevBcSize = widget.getSize(prevBreadcrumb .. 'Bg')

    widget.setPosition(breadcrumb, {prevBcSize[1] + prevBcPos[1] + 2, prevBcPos[2] - 1})

    widget.setPosition(breadcrumb .. 'Bg', {prevBcPos[1] + prevBcSize[1] - self.config.interfaceText.breadcrumbRightPadding - self.config.interfaceText.breadcrumbLeftPadding, prevBcPos[2]}) 
  end

  widget.setVisible(breadcrumb, true)
  widget.setVisible(breadcrumb .. 'Bg', true)

  widget.setSize(breadcrumb .. 'Bg', {hobo.getLengthUtf8(text, self.fontSize) + self.config.interfaceText.breadcrumbRightPadding * mult + self.config.interfaceText.breadcrumbLeftPadding * mult, 9})
end

function setWidgets(config)
  for _, widgetConf in pairs(config) do
    widget.setVisible(widgetConf[1], widgetConf[2])
  end
end

function guessMissions()
  local missions = {}
  local missionsQuestTable = root.assetJson('/ai/missionsTableForMods.config').missionsTable

  for _,mission in ipairs(missionsQuestTable) do
    if player.hasQuest(mission[2]) then
      local missionData = root.assetJson('/ai/' .. mission[1] .. '.aimission')
      local specieDialog = missionData.speciesText[player.species()]
      local configDialog = nil
      if self.config.missionsText then
        configDialog = self.config.missionsText[mission[1]]
      end
      local dialogs = missionData.speciesText.default
      if specieDialog then dialogs = util.mergeTable(dialogs, specieDialog) end
      if configDialog then dialogs = util.mergeTable(dialogs, configDialog) end
      missionData = util.mergeTable(missionData, dialogs)
      missionData.speciesText = nil
      missionData.repeated = player.hasCompletedQuest(mission[2])
      table.insert(missions, missionData)
    end
  end
  
  --root.questConfig()
  return missions
end

function resetidunno()
  if self.config then
    self.animation = self.config.defaultAnimation
    pane.stopAllSounds(self.config.chatterSound)
  end

  self.animationTimer = 0
  self.staticAnimationTimer = 0
  self.scanlineAnimationTimer = 0
end

function close() pane.dismiss() end
function dismissed() if self.config ~= nil then pane.stopAllSounds(self.config.chatterSound) end end

function setWidgetTable() --dunno if there's a better way to do that but this works for now
  self.lazy = { 
    base = {
      {'shipStatusRect', true},
      {'missionsRect', false},
      {'CrewRect', false},
      {'configRect', false},

      {'missionsRect.noMissionsText', false},
      {'missionsRect.scrollArea', false},
      {'missionsRect.missionSelectRect', false},

      {'CrewRect.noCrewText', false},
      {'CrewRect.scrollArea', false},
      {'CrewRect.CrewRect', false},

      {'showMissions', false},
      {'backButton', false},
      {'config', false},
      {'showCrew', false},

      {'pageBreadcrumbBg', false},
      {'itemBreadcrumbBg', false},
      {'pageBreadcrumb', false},
      {'itemBreadcrumb', false}
    },

    shipStatusRect = {
      {'shipStatusRect', true},
      {'missionsRect', false},
      {'CrewRect', false},
      {'configRect', false},

      {'showMissions', true},
      {'backButton', false},
      {'config', true},
      {'showCrew', true},


      {'pageBreadcrumbBg', false},
      {'itemBreadcrumbBg', false},
      {'pageBreadcrumb', false},
      {'itemBreadcrumb', false}
    },

  missionsRect = {
      {'shipStatusRect', false},
      {'missionsRect', true},
      {'CrewRect', false},
      {'configRect', false},

      {'missionsRect.noMissionsText', false},
      {'missionsRect.scrollArea', false},
      {'missionsRect.missionSelectRect', false},

      {'showMissions', false},
      {'config', true},
      {'backButton', true},
      {'showCrew', false},

      {'pageBreadcrumbBg', true},
      {'itemBreadcrumbBg', false},
      {'pageBreadcrumb', true},
      {'itemBreadcrumb', false}
    },

    crewRect = {
      {'shipStatusRect', false},
      {'missionsRect', false},
      {'CrewRect', true},
      {'configRect', false},

      {'showMissions', false},
      {'config', true},
      {'backButton', true},
      {'showCrew', false},

      {'CrewRect.noCrewText', false},
      {'CrewRect.scrollArea', false},
      {'CrewRect.CrewRect', false},

      {'pageBreadcrumbBg', true},
      {'itemBreadcrumbBg', false},
      {'pageBreadcrumb', true},
      {'itemBreadcrumb', false}
    },

    configRect = {
      {'shipStatusRect', false},
      {'missionsRect', false},
      {'CrewRect', false},
      {'configRect', true},

      {'showMissions', false},
      {'config', false},
      {'backButton', true},
      {'showCrew', false},

      {'pageBreadcrumbBg', true},
      {'itemBreadcrumbBg', false},
      {'pageBreadcrumb', true},
      {'itemBreadcrumb', false}
    },

    hideButtons = {
      {'showMissions', false},
      {'backButton', false},
      {'config', false},
      {'showCrew', false}
    }
  }
end

function rgbToHex(rgb) --https://gist.github.com/marceloCodget/3862929
  local hexadecimal = ""

  for key, value in pairs(rgb) do
    local hex = ''

    while(value > 0)do
      local index = math.fmod(value, 16) + 1
      value = math.floor(value / 16)
      hex = string.sub('0123456789ABCDEF', index, index) .. hex     
    end

    if(string.len(hex) == 0)then
      hex = '00'
    elseif(string.len(hex) == 1)then
      hex = '0' .. hex
    end

    hexadecimal = hexadecimal .. hex
  end

  return hexadecimal
end


function utf8.sub(s,i,j) --godbless Magicks and https://stackoverflow.com/questions/43138867/lua-unicode-using-string-sub-with-two-byted-chars
    i=utf8.offset(s,i)
    j=utf8.offset(s,j+1)-1
    return string.sub(s,i,j)
end