local folderName = ...

local math_max   = _G.math.max
local math_min   = _G.math.min
local math_floor = _G.math.floor

local ButtonFrameTemplate_HidePortrait = _G.ButtonFrameTemplate_HidePortrait


local function Round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math_floor(num * mult + 0.5) / mult
end


---------------------
-- Constants --------
---------------------

local PIXEL_FILE_PATH = "Interface/BUTTONS/WHITE8X8"


local CONFIG_FRAME_WIDTH = 400
local CONFIG_FRAME_HEIGHT = 550


local GRAPH_WIDTH_MIN = 50
local GRAPH_WIDTH_MAX = 1000

local GRAPH_HEIGHT_MIN = 50
local GRAPH_HEIGHT_MAX = 600

local GRAPH_BAR_THICKNESS_MIN = 1
local GRAPH_BAR_THICKNESS_MAX = 10

local FRAMES_PER_GRAPH_BAR_MIN = 1
local FRAMES_PER_GRAPH_BAR_MAX = 30

local Y_AXIS_TOP_MIN = 1
local Y_AXIS_TOP_MAX = 300

local Y_AXIS_BOTTOM_MIN = 0
local Y_AXIS_BOTTOM_MAX = 299

local GRAPH_LINE_THICKNESS_MIN = 1
local GRAPH_LINE_THICKNESS_MAX = 10


local CONFIG_DEFAULTS = {

  graphAnchor = "CENTER",
  graphX      = 0,
  graphY      = 0,

  graphWidth  = 300,
  graphHeight = 120,

  graphBarThickness = 3,

  framesPerGraphBar = 4,

  show = {
    max = true,
    avg = true,
    min = true,
  },

  color = {
    max = {1.0, 1.0, 1.0},
    avg = {0.8, 0.8, 0.8},
    min = {0.6, 0.6, 0.6},
  },

  yAxisTop = 120,
  yAxisTopDynamic = false,

  yAxisBottom = 0,
  yAxisBottomDynamic = false,

  graphLineThickness = 1,
}





---------------------
-- Locals -----------
---------------------

-- Forward declaration.
local UpdateGraphBarsColor
local RefreshGraph
local OneFrameMode


-- The graph frame.
local gf = nil

local numberOfVisibleBars = 0
local numberOfCreatedBars = 0

-- To calculate the per bar values.
local frameCounter = 0
local minFPS = 99999
local maxFPS = 0
local sumFPS = 0

local graphBars = {
  max = {},
  avg = {},
  min = {},
}

local graphBarValues = {
  max = {},
  avg = {},
  min = {},
}

local graphBarValuesFirstIndex = 0

local graphLines = {}

local horizontalGridLines = {}
local verticalGridLines = {}



-- local function DrawFilledBox(f, bottomLeftX, bottomLeftY, topRightX, topRightY, r, g, b, a)
  -- local box = f:CreateTexture()
  -- box:SetTexture(PIXEL_FILE_PATH)
  -- box:SetColorTexture(r, g, b, a)
  -- box:SetPoint("BOTTOMLEFT", bottomLeftX, bottomLeftY)
  -- box:SetSize(topRightX-bottomLeftX, topRightY-bottomLeftY)
-- end


-- local function DrawEmptyBox(f, bottomLeftX, bottomLeftY, topRightX, topRightY, linewidth, r, g, b, a)

  -- -- LTTTTTTT
  -- -- L      R
  -- -- L      R
  -- -- L      R
  -- -- BBBBBBBR

  -- -- Bottom line
  -- DrawFilledBox(f, bottomLeftX, bottomLeftY, bottomLeftX+topRightX-linewidth, bottomLeftY+linewidth, r, g, b, a)
  -- -- Top line
  -- DrawFilledBox(f, bottomLeftX+linewidth, topRightY-linewidth, bottomLeftX+topRightX, bottomLeftY+topRightY, r, g, b, a)
  -- -- Left line
  -- DrawFilledBox(f, bottomLeftX, bottomLeftY+linewidth, bottomLeftX+linewidth, bottomLeftY+topRightY, r, g, b, a)
  -- -- Right line
  -- DrawFilledBox(f, bottomLeftX+topRightX-linewidth, bottomLeftY, topRightX, bottomLeftY+topRightY-linewidth, r, g, b, a)
-- end





local function ColorPickerCallback(restore)
  local variableSuffix = ColorPickerFrame.variableSuffix
  local oldR, oldG, oldB, oldA = unpack(config.color[variableSuffix])

  local newR, newG, newB, newA
  if restore then
    -- The user bailed, we extract the old color from the table created by ShowColorPicker.
    newR, newG, newB, newA = unpack(restore)
  else
    -- Something changed
    newA, newR, newG, newB = 1-OpacitySliderFrame:GetValue(), ColorPickerFrame:GetColorRGB()
  end

  if oldR ~= newR or oldG ~= newG or oldB ~= newB or oldA ~= newA then
    config.color[variableSuffix] = {newR, newG, newB, newA}
    UpdateGraphBarsColor(graphBars[variableSuffix], config.color[variableSuffix])
    _G["fpsGraph_"..variableSuffix.."ColorButton"].foreground:SetColorTexture(newR, newG, newB, 1)
  end
end


-- https://wow.gamepedia.com/Using_the_ColorPickerFrame
function ShowColorPicker(variableSuffix)
  ColorPickerFrame.variableSuffix = variableSuffix

  local color = config.color[variableSuffix]
  local r, g, b, a = unpack(color)

  if a ~= nil then
    ColorPickerFrame.hasOpacity = true
    ColorPickerFrame.opacity    = 1 - a
  else
    ColorPickerFrame.hasOpacity = false
  end

  ColorPickerFrame.previousValues = color

  ColorPickerFrame.func        = ColorPickerCallback
  ColorPickerFrame.opacityFunc = ColorPickerCallback
  ColorPickerFrame.cancelFunc  = ColorPickerCallback

  ColorPickerFrame:SetColorRGB(r,g,b)

   -- Need to run the OnShow handler.
  ColorPickerFrame:Hide()
  ColorPickerFrame:Show()
end




local function DrawLine(f, startRelativeAnchor, startOffsetX, startOffsetY,
                           endRelativeAnchor, endOffsetX, endOffsetY,
                           thickness, r, g, b, a)

  local line = f:CreateLine()
  line:SetThickness(thickness)
  line:SetColorTexture(r, g, b, a)
  line:SetStartPoint(startRelativeAnchor, f, startOffsetX, startOffsetY)
  line:SetEndPoint(endRelativeAnchor, f, endOffsetX, endOffsetY)

end



local function SetFrameBorder(f, thickness, r, g, b, a)
  -- Bottom line.
  DrawLine(f, "BOTTOMLEFT", 0, 0, "BOTTOMRIGHT", 0, 0, thickness, r, g, b, a)
  -- Top line.
  DrawLine(f, "TOPLEFT", 0, 0, "TOPRIGHT", 0, 0, thickness, r, g, b, a)
  -- Left line.
  DrawLine(f, "BOTTOMLEFT", 0, 0, "TOPLEFT", 0, 0, thickness, r, g, b, a)
  -- Right line.
  DrawLine(f, "BOTTOMRIGHT", 0, 0, "TOPRIGHT", 0, 0, thickness, r, g, b, a)
end



local function DrawGraphBars(graphBars, graphBarValues)
  for i in pairs(graphBars) do
    if i > numberOfVisibleBars then break end
    
    local barTopY = graphBarValues[(graphBarValuesFirstIndex - i + 1) % numberOfVisibleBars]
    if barTopY then
    
      local smoothProgress = frameCounter / config.framesPerGraphBar

      local barStartX
      local barEndX
      if i == 1 then
        barStartX = 0
        barEndX   = config.graphBarThickness * smoothProgress
      else
        barStartX = config.graphBarThickness * (smoothProgress + i - 2)
        barEndX   = math_min(barStartX + config.graphBarThickness, gf.grid:GetWidth())
      end

      if barStartX > gf.grid:GetWidth() then
        graphBars[i]:Hide()
      else
        graphBars[i]:Show()
                
        -- Modify bar height according to yAxisBottom and yAxisTop.
        barTopY = math_max(barTopY - config.yAxisBottom, 0)
        barTopY = gf.grid:GetHeight() * math_min(barTopY / (config.yAxisTop - config.yAxisBottom), 1)

        graphBars[i]:SetPoint("BOTTOMRIGHT", gf.grid, "BOTTOMRIGHT", -barStartX, 0)
        graphBars[i]:SetPoint("TOPLEFT",     gf.grid, "BOTTOMRIGHT", -barEndX,   barTopY)
      end
    end
  end
end


local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("onUpdate", function(self, elapsed)

  -- Calculate the framerate between this and the last frame.
  local currentFramerate = 1/elapsed


  if config.framesPerGraphBar == 1 then

    -- Increase the index.
    graphBarValuesFirstIndex = (graphBarValuesFirstIndex + 1) % numberOfVisibleBars

    -- Fill in the most recent value.
    graphBarValues.avg[graphBarValuesFirstIndex] = currentFramerate

  else

    frameCounter = frameCounter + 1

    if config.show.max then maxFPS = math_max(maxFPS, currentFramerate) end
    if config.show.avg then sumFPS = sumFPS + currentFramerate end
    if config.show.min then minFPS = math_min(minFPS, currentFramerate) end

    -- If one graph is complete, fill in the value.
    if frameCounter == config.framesPerGraphBar then

      -- Increase the index.
      graphBarValuesFirstIndex = (graphBarValuesFirstIndex + 1) % numberOfVisibleBars

      -- Fill in the current values and reset the counters.
      if config.show.max then
        graphBarValues.max[graphBarValuesFirstIndex] = maxFPS
        maxFPS = 0
      end
      if config.show.avg then
        graphBarValues.avg[graphBarValuesFirstIndex] = sumFPS/frameCounter
        sumFPS = 0
      end
      if config.show.min then
        graphBarValues.min[graphBarValuesFirstIndex] = minFPS
        minFPS = 99999
      end

      frameCounter = 0
    end

  end

  -- Draw the graph.
  if config.framesPerGraphBar == 1 then
    DrawGraphBars(graphBars.avg, graphBarValues.avg)
  else
    if config.show.max then DrawGraphBars(graphBars.max, graphBarValues.max) end
    if config.show.avg then DrawGraphBars(graphBars.avg, graphBarValues.avg) end
    if config.show.min then DrawGraphBars(graphBars.min, graphBarValues.min) end
  end

end)






local function InsertGraphBar(graphBars, drawLayerSubLevel)
  local newBar = gf.grid:CreateTexture()
  newBar:SetDrawLayer("ARTWORK", drawLayerSubLevel)
  newBar:SetTexture(PIXEL_FILE_PATH)
  tinsert(graphBars, newBar)
end



local function ShowGraphBars(graphBars, color, numberOfRequiredBars)
  for i, bar in pairs(graphBars) do
    if i <= numberOfRequiredBars then
      bar:ClearAllPoints()
      bar:Show()
      bar:SetColorTexture(unpack(color))
    else
      bar:Hide()
    end
  end
end

-- Forward declaration above...
UpdateGraphBarsColor = function(graphBars, color)
  for i, bar in pairs(graphBars) do
    bar:SetColorTexture(unpack(color))
  end
end




local function HideGraph(graphBars, graphBarValues)
  for _, bar in pairs(graphBars) do
    bar:Hide()
  end

  for i in pairs(graphBarValues) do
    graphBarValues[i] = 0
  end
end


local function UpdateLines()
  for k, v in pairs (graphLines) do
    v:SetThickness(config.graphLineThickness)
  end
end



-- Called when the graph size is changed.
-- Forward declaration above...
RefreshGraph = function()

  if config.framesPerGraphBar == 1 then
    OneFrameMode(true)
    HideGraph(graphBars.max, graphBarValues.max)
    HideGraph(graphBars.min, graphBarValues.min)
  else
    OneFrameMode(false)
    if not config.show.max then HideGraph(graphBars.max, graphBarValues.max) end
    if not config.show.avg then HideGraph(graphBars.avg, graphBarValues.avg) end
    if not config.show.min then HideGraph(graphBars.min, graphBarValues.min) end
  end


  UpdateLines()

  gf:SetWidth(config.graphWidth)
  gf:SetHeight(config.graphHeight)
  gf:ClearAllPoints()
  gf:SetPoint(config.graphAnchor, config.graphX, config.graphY)

  -- Determine how many bars we need.
  -- We need two more bars because the worst case is
  -- that the first bar is just started to be shifted in
  -- and the grid width is almost one bar width wider than the rounded number of bars.
  local numberOfRequiredBars = math_floor(gf.grid:GetWidth() / config.graphBarThickness) + 2


  -- If necessary create all we need.
  if numberOfRequiredBars > numberOfCreatedBars then
    -- The easiest way to make sure that all graphs have the same amount
    -- of bars is to insert them all, regardless of whether they are
    -- needed or not...
    for i = numberOfCreatedBars+1, numberOfRequiredBars, 1 do
      InsertGraphBar(graphBars.max, -1)
      InsertGraphBar(graphBars.avg, 0)
      InsertGraphBar(graphBars.min, 1)
    end

    numberOfCreatedBars = numberOfRequiredBars
  end

  -- Make visible as many bars as we need and hide the others.
  if config.framesPerGraphBar == 1 then
    ShowGraphBars(graphBars.avg, config.color.avg, numberOfRequiredBars)
  else
    if config.show.max then ShowGraphBars(graphBars.max, config.color.max, numberOfRequiredBars) end
    if config.show.avg then ShowGraphBars(graphBars.avg, config.color.avg, numberOfRequiredBars) end
    if config.show.min then ShowGraphBars(graphBars.min, config.color.min, numberOfRequiredBars) end
  end

  numberOfVisibleBars = numberOfRequiredBars

  -- Reset the counters.
  frameCounter = 0
  minFPS = 99999
  maxFPS = 0
  sumFPS = 0
end





local function CreateGraph()

  if gf then return end

  gf = CreateFrame("Frame", "fpsGraph_graphFrame", UIParent)
  gf:SetFrameStrata("BACKGROUND")
  gf:SetMovable(true)
  gf:EnableMouse(true)
  gf:RegisterForDrag("LeftButton")
  gf:SetScript("OnDragStart", gf.StartMoving)
  gf:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing(self)
      config.graphAnchor, _, _, config.graphX, config.graphY = self:GetPoint(1)
    end)
  gf:SetClampedToScreen(true)

  gf:Show()


  gf.grid = CreateFrame("Frame", nil, gf)
  gf.grid:SetPoint("BOTTOMLEFT", 10, 10)
  gf.grid:SetPoint("TOPRIGHT", -50, -10)


  SetFrameBorder(gf.grid, 1, 1, 0, 0, 1)
  SetFrameBorder(gf, 1, 0, 0, 1, 1)


  RefreshGraph()
end












local function AddSlider(parentFrame, anchor, offsetX, offsetY, sliderTitle, variableName, minValue, maxValue, valueStep, valueChangedFunction)
  local slider = CreateFrame("Slider", "fpsGraph_"..variableName.."Slider", parentFrame, "OptionsSliderTemplate")
  slider:SetPoint(anchor, offsetX, offsetY)
  slider:SetWidth(CONFIG_FRAME_WIDTH - 85)
  slider:SetHeight(17)
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(valueStep)
  slider:SetObeyStepOnDrag(true)
  slider:SetValue(config[variableName])

  _G[slider:GetName() .. 'Low']:SetText(minValue)
  _G[slider:GetName() .. 'High']:SetText(maxValue)
  _G[slider:GetName() .. 'Text']:SetText(sliderTitle)

  slider.valueLabel = parentFrame:CreateFontString("fpsGraph_"..variableName.."SliderValueLabel", "HIGH")
  slider.valueLabel:SetFont("Fonts\\FRIZQT__.TTF", 11)
  slider.valueLabel:SetTextColor(1, 1, 1)
  slider.valueLabel:SetPoint("LEFT", slider, "RIGHT", 15, 0)
  slider.valueLabel:SetWidth(25)
  slider.valueLabel:SetJustifyH("CENTER")
  slider.valueLabel:SetText(config[variableName])

  slider:SetScript("OnValueChanged", function(self, value)
      config[variableName] = value
      self.valueLabel:SetText(value)
      if valueChangedFunction then valueChangedFunction(self, value) end
      RefreshGraph()
    end
  )
end




local function AddSeriesSelector(parentFrame, anchor, offsetX, offsetY, labelText, variableSuffix)

  local checkbox = CreateFrame("CheckButton", "fpsGraph_"..variableSuffix.."Checkbox", parentFrame, "UICheckButtonTemplate")
  checkbox:SetSize(22, 22)
  checkbox:SetPoint(anchor, offsetX, offsetY)

  if config.show[variableSuffix] == true then
    checkbox:SetChecked(true)
  else
    checkbox:SetChecked(false)
  end

  checkbox:SetScript("OnClick", function(self)
      if self:GetChecked() then
        config.show[variableSuffix] = true
      else
        config.show[variableSuffix] = false
      end
      RefreshGraph()
    end
  )

  local label = parentFrame:CreateFontString("fpsGraph_"..variableSuffix.."SeriesSelector", "HIGH")
  label:SetPoint("LEFT", checkbox, "RIGHT", 10, 0)
  label:SetWidth(180)
  label:SetFont("Fonts\\FRIZQT__.TTF", 12)
  label:SetTextColor(1, 1, 1)
  label:SetJustifyH("LEFT")
  label:SetText(labelText)



  local colorButton = CreateFrame("Button", "fpsGraph_"..variableSuffix.."ColorButton", parentFrame)


  colorButton:SetSize(15, 15)
  colorButton:SetPoint("LEFT", label, "RIGHT", 10, 0)


  colorButton.background = colorButton:CreateTexture()

  colorButton.background:SetAllPoints()
  colorButton.background:SetDrawLayer("BACKGROUND", 0)
  colorButton.background:SetTexture(PIXEL_FILE_PATH)
  colorButton.background:SetColorTexture(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)

  local layer, subLevel = colorButton.background:GetDrawLayer()

  colorButton.foreground = colorButton:CreateTexture()
  colorButton.foreground:SetDrawLayer(layer, subLevel+1)

  colorButton.foreground:SetTexture(PIXEL_FILE_PATH)
  colorButton.foreground:SetColorTexture(unpack(config.color[variableSuffix]))
  colorButton.foreground:SetPoint("TOPLEFT", 1, -1)
  colorButton.foreground:SetPoint("BOTTOMRIGHT", -1, 1)


  colorButton:SetScript("OnEnter", function(self)
      self.background:SetColorTexture(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    end
  )
  colorButton:SetScript("OnLeave", function(self)
      self.background:SetColorTexture(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
    end
  )


  colorButton:SetScript("OnClick", function()
      ShowColorPicker(variableSuffix)
    end
  )


end


-- When only one frame per graph bar is selected, max, avg and min are all the same.
-- So we only show avg.
-- Forward declaration above...
OneFrameMode = function(set)

  if set then

    _G["fpsGraph_maxCheckbox"]:SetChecked(false)
    _G["fpsGraph_avgCheckbox"]:SetChecked(true)
    _G["fpsGraph_minCheckbox"]:SetChecked(false)

    _G["fpsGraph_maxCheckbox"]:Disable()
    _G["fpsGraph_avgCheckbox"]:Disable()
    _G["fpsGraph_minCheckbox"]:Disable()

  else

    _G["fpsGraph_maxCheckbox"]:Enable()
    _G["fpsGraph_avgCheckbox"]:Enable()
    _G["fpsGraph_minCheckbox"]:Enable()

    _G["fpsGraph_maxCheckbox"]:SetChecked(config.show.max)
    _G["fpsGraph_avgCheckbox"]:SetChecked(config.show.avg)
    _G["fpsGraph_minCheckbox"]:SetChecked(config.show.min)

  end
end





local cf = nil

local function DrawConfigFrame()

  if cf then return end

  cf = CreateFrame("Frame", "fpsGraph_configFrame", UIParent, "ButtonFrameTemplate")

  cf:SetPoint("TOPLEFT")
  ButtonFrameTemplate_HidePortrait(cf)
  -- SetPortraitToTexture(...)
  -- ButtonFrameTemplate_HideAttic(cf)
  -- ButtonFrameTemplate_HideButtonBar(cf)

  cf:SetFrameStrata("HIGH")
  cf:SetWidth(CONFIG_FRAME_WIDTH)
  cf:SetHeight(CONFIG_FRAME_HEIGHT)
  cf:SetMovable(true)
  cf:EnableMouse(true)
  cf:RegisterForDrag("LeftButton")
  cf:SetScript("OnDragStart", cf.StartMoving)
  cf:SetScript("OnDragStop", cf.StopMovingOrSizing)
  cf:SetClampedToScreen(true)


  _G[cf:GetName().."TitleText"]:SetText("Framerate Graph - Config")
  _G[cf:GetName().."TitleText"]:ClearAllPoints()
  _G[cf:GetName().."TitleText"]:SetPoint("TOPLEFT", 10, -6)


  AddSlider(cf.Inset, "TOPLEFT", 20, -20, "Graph width", "graphWidth", GRAPH_WIDTH_MIN, GRAPH_WIDTH_MAX, 1)
  AddSlider(cf.Inset, "TOPLEFT", 20, -60, "Graph height", "graphHeight", GRAPH_HEIGHT_MIN, GRAPH_HEIGHT_MAX, 1)
  AddSlider(cf.Inset, "TOPLEFT", 20, -100, "Graph bar thickness", "graphBarThickness", GRAPH_BAR_THICKNESS_MIN, GRAPH_BAR_THICKNESS_MAX, 1)
  AddSlider(cf.Inset, "TOPLEFT", 20, -140, "Frames per graph bar", "framesPerGraphBar", FRAMES_PER_GRAPH_BAR_MIN, FRAMES_PER_GRAPH_BAR_MAX, 1)

  AddSeriesSelector(cf.Inset, "TOPLEFT", 20, -180, "Maximum FPS per graph bar", "max")
  AddSeriesSelector(cf.Inset, "TOPLEFT", 20, -200, "Average FPS per graph bar", "avg")
  AddSeriesSelector(cf.Inset, "TOPLEFT", 20, -220, "Minimum FPS per graph bar", "min")

  AddSlider(cf.Inset, "TOPLEFT", 20, -280, "Y-axis top", "yAxisTop", Y_AXIS_TOP_MIN, Y_AXIS_TOP_MAX, 1,
      function(self, value)
        if value < config.yAxisBottom + 1 then
          _G["fpsGraph_yAxisBottomSlider"]:SetValue(value-1)
        end
      end
    )
  AddSlider(cf.Inset, "TOPLEFT", 20, -320, "Y-axis bottom", "yAxisBottom", Y_AXIS_BOTTOM_MIN, Y_AXIS_BOTTOM_MAX, 1,
      function(self, value)
        if value > config.yAxisTop - 1 then
          _G["fpsGraph_yAxisTopSlider"]:SetValue(value+1)
        end
      end
    )

  AddSlider(cf.Inset, "TOPLEFT", 20, -380, "Graph line thickness", "graphLineThickness", GRAPH_LINE_THICKNESS_MIN, GRAPH_LINE_THICKNESS_MAX, 1)


  tinsert(UISpecialFrames, cf:GetName())

end



local addonLoadedFrame = CreateFrame("Frame")
addonLoadedFrame:RegisterEvent("ADDON_LOADED")

addonLoadedFrame:SetScript("OnEvent", function(self, event, arg1)
  if arg1 == folderName then

    if not config then
      config = CONFIG_DEFAULTS
    else

      -- Remove obsolete values from saved variables.
      for k in pairs (config) do
        if not CONFIG_DEFAULTS[k] then
          config[k] = nil
        end
      end

      -- Fill missing values.
      for k, v in pairs (CONFIG_DEFAULTS) do
        if not config[k] then
          config[k] = v
        end
      end


    end


  DrawConfigFrame()

  CreateGraph()

  end
end)






-- For debugging!
-- local startupFrame = CreateFrame("Frame")
-- startupFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
-- startupFrame:SetScript("OnEvent", function()
  -- cf:Show()
-- end)
  
  
  
  


-- FPS (frames per second)    

-- FI (frame-to-frame interval) in msec (milliseconds)



-- Texture:SetGradientAlpha(orientation, minR, minG, minB, minA, maxR, maxG, maxB, maxA)
