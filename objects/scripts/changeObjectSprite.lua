require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.animationTimer = 0
  self.position = entity.position()
end

function update()
  localAnimator.clearDrawables()
  self.imageconfig = animationConfig.animationParameter("imageConfig")
  if self.imageconfig then
    dt = script.updateDt()

    frame = math.floor((self.animationTimer / self.imageconfig.animationCycle) * self.imageconfig.frames)
    if self.animationTimer == 0 then frame = 0 end

    self.animationTimer = self.animationTimer + dt
    if self.animationTimer > self.imageconfig.animationCycle then
        self.animationTimer = 0
    end

    localAnimator.addDrawable({
      image = self.imageconfig.imagePath:gsub("<frame>", frame):gsub("<color>", "default"),
      position = {self.position[1] - 0.5, self.position[2] - -0.5} --wtf is that math??? I thought I'd need to use imageconfig.imagePosition
    }, "object+1")
  end
end