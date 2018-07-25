-- this is only started once on new quests and on init
-- so it isn't updated when someone change their A.I. chip until they change world

function setPortraits(titleFn)
  local SAILportrait = status.statusProperty("SAILportraitDefaults")
  local SAILportraitPath = string.format("/ai/portraits/%squestportrait.png", player.species())

  if SAILportrait then
    -- having it so hardcoded was dumb but I can't really turn back now that some people made their own chips
    -- so we naively look if the saved SAIL portrait is a path since / is forbidden in filenames
    if string.match(SAILportrait, "/") then 
      SAILportraitPath = SAILportrait
    else
      SAILportraitPath = string.format("/ai/portraits/%squestportrait.png", SAILportrait)
    end
  end

  quest.setParameter("sail", {
    type = "noDetail",
    name = "S.A.I.L",
    portrait = {
      { image = SAILportraitPath }
    }
  })

  local config = config.getParameter("portraits")
  local portraitParameters = {
      QuestStarted = config.questStarted or config.default,
      QuestComplete = config.questComplete or config.default,
      QuestFailed = config.questFailed or config.default,
      Objective = config.objective
    }

  local parameters = quest.parameters()
  for portraitName, portrait in pairs(portraitParameters) do
    local drawables
    local title

    if type(portrait) == "string" then
      local paramValue = parameters[portrait]
      if paramValue then
        drawables = paramValue.portrait
        title = paramValue.name
      end
    else
      drawables = portrait.portrait
      title = portrait.title
    end

    if titleFn then
      title = titleFn(title)
    end

    quest.setPortrait(portraitName, drawables)
    quest.setPortraitTitle(portraitName, title)
  end
end
