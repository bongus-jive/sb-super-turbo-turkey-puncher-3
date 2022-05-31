require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  local getParam = config.getParameter
  
  Canvas = widget.bindCanvas("canvas")
  CanvasSize = Canvas:size()
  CanvasCenter = vec2.floor(vec2.mul(CanvasSize, 0.5))
  
  TurkeyPosition = vec2.add(CanvasCenter, getParam("turkeyOffset"))
  RespawnPosition = vec2.add(TurkeyPosition, {0, CanvasSize[2]})
  
  MaxHealth = getParam("turkeyHealth")
  Health = MaxHealth
  DieTimer = 0
  DieTime = getParam("turkeyDieTime")
  DieFrames = getParam("turkeyDieFrames") - 1
  RespawnTimer = 0
  RespawnTime = getParam("turkeyRespawnTime")
  
  local assetsPath = getParam("assetsPath")
  Assets = getParam("assets")
  for _,t in pairs(Assets) do
    for k,v in pairs(t) do
      t[k] = assetsPath..v
    end
  end
  
  pane.stopAllSounds(Assets.sounds.loop)
  pane.playSound(Assets.sounds.loop, -1, 0.5)
  pane.playSound(Assets.sounds.sttp3)
  
  local logoSize = root.imageSize(Assets.images.logo)
  LogoPosition = vec2.sub(CanvasSize, logoSize)
  
  Colors = getParam("colors")
  ColorTime = getParam("colorTime")
  ColorTimer = 0
  
  PunchTimer = 0
  PunchTime = getParam("punchTime")
  HitTime = getParam("hitTime")
  FistFrames = getParam("fistFrames") - 1
  Punching = false
  
  HeadTimer = 0
  HeadTime = getParam("headTime")
  HeadPosition = getParam("headPosition")
  HeadFrames = getParam("headFrames") + 1
  
  Score = 0
  ScorePositioning = getParam("scorePositioning")
  ScoreFontSize = getParam("scoreFontSize")
  PunchPoints = getParam("punchPoints")
  
  PointsText = {}
  PointsTextPositions = getParam("pointsTextPositions")
  PointsTextRise = getParam("pointsTextRise")
  PointsTextTime = getParam("pointsTextTime")
  PointsTextFontSize = getParam("pointsTextFontSize")
  
  BlinkTime = getParam("blinkTime")
  BlinkTimeRange = getParam("blinkTimeRange")
  BlinkTimer = util.randomInRange(BlinkTimeRange)
  BlinkingTimer = 0
  
  TurkeyAnimTimer = 0
  TurkeyAnimTime = getParam("turkeyAnimTime")
  TurkeyAnimFrames = getParam("turkeyAnimFrames")
  
  FeatherFallTimer = 0
  FeatherFallTime = getParam("featherFallTime")
  FeatherPositions = getParam("featherPositions")
  FeatherEndPositions = {}
  local featherFall = getParam("featherFall")
  for i,v in ipairs(FeatherPositions) do
    FeatherEndPositions[i] = vec2.add(v, {0, featherFall[i]})
  end
  
  Cursor = getParam("cursor")
end

function update(dt)
  Canvas:clear()
  
  --ui
  local color = updateColors(dt)
  Canvas:drawImage(Assets.images.logoline, LogoPosition, nil, color)
  Canvas:drawImage(Assets.images.logo, LogoPosition)
  
  Canvas:drawText("^shadow;"..Score, ScorePositioning, ScoreFontSize)
  
  --john doom
  HeadTimer = (HeadTimer + dt / HeadTime) % HeadFrames
  local headFrame = math.floor(HeadTimer)
  
  --turkey looking
  TurkeyAnimTimer = (TurkeyAnimTimer + dt / TurkeyAnimTime) % TurkeyAnimFrames
  local turkeyFrame = math.floor(TurkeyAnimTimer)
  local turkeyColor
  
  --turkey blinking
  BlinkTimer = BlinkTimer - dt
  if BlinkTimer <= 0 then
    BlinkTimer = util.randomInRange(BlinkTimeRange)
    BlinkingTimer = BlinkTime
  end
  if BlinkingTimer > 0 then
    BlinkingTimer = math.max(0, BlinkingTimer - dt)
    turkeyFrame = "blink"
  end
  
  --Punch
  if Punching then
    PunchTimer = math.min(1, PunchTimer + dt / PunchTime)
    if PunchTimer == 1 then
      Punching = false
      pane.playSound(Assets.sounds["punch"..math.random(1, 2)])
      
      Health = Health - 1
      if Health == 0 then
        DieTimer = 1
        FeatherFallTimer = 1
        pane.playSound(Assets.sounds.gib)
      end
    end
  --Unpunch
  elseif PunchTimer > 0 then
    PunchTimer = math.max(0, PunchTimer - dt / HitTime)
    turkeyFrame = "hit"
  end
  
  --feathers
  if FeatherFallTimer > 0 then
    FeatherFallTimer = math.max(0, FeatherFallTimer - dt / FeatherFallTime)
    
    for i,v in pairs(FeatherPositions) do
      local pos = vec2.lerp(FeatherFallTimer, FeatherEndPositions[i], v)
      local color = string.format("#FFFFFF%02x", math.floor(FeatherFallTimer * 255))
      Canvas:drawImage(Assets.images["feather"..i], pos, nil, color, true)
    end
  end
  
  --Die
  if DieTimer > 0 then
    headFrame = "kill"
    DieTimer = math.max(0, DieTimer - dt / DieTime)
    turkeyFrame = "gib."..math.floor((1 - DieTimer) * DieFrames)
    
    if DieTimer == 0 then
      RespawnTimer = 1
    end
  --Respawn
  elseif RespawnTimer > 0 then
    RespawnTimer = math.max(0, RespawnTimer - dt / RespawnTime)
    
    local r = util.interpolateSigmoid(RespawnTimer, 0, 1)
    local pos = vec2.lerp(r, TurkeyPosition, RespawnPosition)
    Canvas:drawImage(Assets.images.turkey..":0", pos, nil, nil, true)
    
    turkeyColor = string.format("#FFFFFF%02x", math.floor(RespawnTimer * 255))
    turkeyFrame = "gib."..DieFrames
    
    if RespawnTimer == 0 then
      Health = MaxHealth
    elseif RespawnTimer > 0.75 then
      headFrame = "kill"
    end
  end
  
  Canvas:drawImage(Assets.images.head..":"..headFrame, HeadPosition)
  
  Canvas:drawImage(Assets.images.turkey..":"..turkeyFrame, TurkeyPosition, nil, turkeyColor, true)
  
  local fistFrame = math.ceil(PunchTimer * FistFrames)
  Canvas:drawImage(Assets.images.fist..":"..fistFrame, {0, 0})
  
  --points
  local points = PointsText
  PointsText = {}
  for _,t in ipairs(points) do
    t.progress = t.progress + dt / PointsTextTime
    
    local pos = vec2.lerp(t.progress, t.startPos, t.endPos)
    local color = string.format("#FFFFFF%02x", math.ceil((1 - t.progress) * 255))
    
    Canvas:drawText(t.text, {position = pos, horizontalAnchor = "mid"}, PointsTextFontSize, color)
    
    if t.progress < 1 then
      PointsText[#PointsText + 1] = t
    end
  end
end

function click(position, button, isButtonDown)
  if isButtonDown and not Punching and PunchTimer < 0.6 and Health > 0 then
    Punching = true
    
    local points = PunchPoints[PunchTimer == 0 and 1 or 2]
    if Health == 1 then
      points = points * 10
    end
    Score = Score + points
    
    local pos = vec2.lerp(Health / MaxHealth, PointsTextPositions[2], PointsTextPositions[1])
    PointsText[#PointsText + 1] = {
      progress = 0,
      text = "^shadow;+"..points,
      startPos = pos,
      endPos = vec2.add(pos, {0, PointsTextRise})
    }
  end
end

function cursorOverride(pos)
  if widget.getChildAt(pos) == ".canvas" then
    return Cursor
  end
end

function uninit()
  pane.stopAllSounds(Assets.sounds.loop)
  pane.stopAllSounds(Assets.sounds.sttp3)
end

local function lerpColor(ratio, a, b)
	local r = util.lerp(ratio, a[1], b[1])
	local g = util.lerp(ratio, a[2], b[2])
	local b = util.lerp(ratio, a[3], b[3])
	return {r,g,b}
end

function updateColors(dt)
  ColorTimer = (ColorTimer + dt / ColorTime) % 1
  local t = ColorTimer * #Colors
  local i = math.floor(t)
  return lerpColor(t - i, Colors[i + 1], Colors[i + 2] or Colors[1])
end