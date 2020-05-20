local folderName = ...


local math_floor = _G.math.floor
local math_min   = _G.math.min
local math_max   = _G.math.max

local function Round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0);
  return math_floor(num * mult + 0.5) / mult;
end


local ButtonFrameTemplate_HidePortrait = _G.ButtonFrameTemplate_HidePortrait


local pixelFilePath = "Interface/BUTTONS/WHITE8X8"


local graphWidthMin = 50
local graphWidthMax = 1000

local graphHeightMin = 50
local graphHeightMax = 600

local graphBarThicknessMin = 1
local graphBarThicknessMax = 10

local framesPerGraphBarMin = 1
local framesPerGraphBarMax = 30


local graphLineThicknessMin = 1
local graphLineThicknessMax = 10



local configDefaults = {

  graphAnchor = "CENTER",
  graphX      = 0,
  graphY      = 0,

  graphWidth  = 300,
  graphHeight = 100,

  graphBarThickness = 1,

  framesPerGraphBar = 1,

  showMax = true,
  showAvg = true,
  showMin = true,
  
  maxColor = {1, 0, 0, 1},
  avgColor = {0, 1, 0, 1},
  minColor = {0, 0, 1, 1},
  
    
  graphLineThickness = 1,

}





-- The graph frame.
local gf = nil



local numberOfVisibleBars = 0
local numberOfCreatedBars = 0
local graphBarsMin = {}
local graphBarsMax = {}
local graphBarsAvg = {}

local graphBarValuesMin = {}
local graphBarValuesMax = {}
local graphBarValuesAvg = {}
local graphBarValuesFirstIndex = 0


local graphLines = {}


local horizontalGridLines = {}
local verticalGridLines = {}



-- To calculate the per bar values.
-- (Only applicable if framesPerGraphBar > 1.)
local frameCounter = 0
local minFPS = 99999
local maxFPS = 0
local sumFPS = 0













local function DrawFilledBox(f, bottomLeftX, bottomLeftY, topRightX, topRightY, r, g, b, a)
  local box = f:CreateTexture()
  box:SetTexture(pixelFilePath)
  box:SetColorTexture(r, g, b, a)
  box:SetPoint("BOTTOMLEFT", bottomLeftX, bottomLeftY)
  box:SetSize(topRightX-bottomLeftX, topRightY-bottomLeftY)
end


local function DrawEmptyBox(f, bottomLeftX, bottomLeftY, topRightX, topRightY, linewidth, r, g, b, a)

  -- LTTTTTTT
  -- L      R
  -- L      R
  -- L      R
  -- BBBBBBBR

  -- Bottom line
  DrawFilledBox(f, bottomLeftX, bottomLeftY, bottomLeftX+topRightX-linewidth, bottomLeftY+linewidth, r, g, b, a)
  -- Top line
  DrawFilledBox(f, bottomLeftX+linewidth, topRightY-linewidth, bottomLeftX+topRightX, bottomLeftY+topRightY, r, g, b, a)
  -- Left line
  DrawFilledBox(f, bottomLeftX, bottomLeftY+linewidth, bottomLeftX+linewidth, bottomLeftY+topRightY, r, g, b, a)
  -- Right line
  DrawFilledBox(f, bottomLeftX+topRightX-linewidth, bottomLeftY, topRightX, bottomLeftY+topRightY-linewidth, r, g, b, a)

end





local function DrawLine(f, startAnchor, startRelativeAnchor, startOffsetX, startOffsetY,
                           endAnchor, endRelativeAnchor, endOffsetX, endOffsetY,
                           thickness, r, g, b, a)

  local line = f:CreateLine()
  line:SetThickness(thickness)
  line:SetColorTexture(r, g, b, a)
  line:SetStartPoint(startAnchor, f, startRelativeAnchor, startOffsetX, startOffsetY)
  line:SetEndPoint(endAnchor, f, endRelativeAnchor, endOffsetX, endOffsetY)

  tinsert(graphLines, line)
end



local function SetFrameBorder(f, thickness, r, g, b, a)
  -- Bottom line.
  DrawLine(f, "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, thickness, r, g, b, a)
  -- Top line.
  DrawLine(f, "TOPLEFT", "TOPLEFT", 0, 0, "TOPRIGHT", "TOPRIGHT", 0, 0, thickness, r, g, b, a)
  -- Left line.
  DrawLine(f, "BOTTOMLEFT", "BOTTOMLEFT", 0, 0, "TOPLEFT", "TOPLEFT", 0, 0, thickness, r, g, b, a)
  -- Right line.
  DrawLine(f, "BOTTOMRIGHT", "BOTTOMRIGHT", 0, 0, "TOPRIGHT", "TOPRIGHT", 0, 0, thickness, r, g, b, a)
end



















local function DrawGraphBar(graphBars, graphBarValues, i, smoothProgress)

  if i == 1 then

    graphBars[i]:SetPoint("BOTTOMRIGHT", gf.grid, "BOTTOMRIGHT", 0, 0)
    graphBars[i]:SetPoint("TOPLEFT", gf.grid, "BOTTOMRIGHT", -smoothProgress * config.graphBarThickness, graphBarValues[graphBarValuesFirstIndex])

  else

    local graphStartX = config.graphBarThickness * (i - 2 + smoothProgress)

    if graphStartX > gf.grid:GetWidth() then
      graphBars[i]:Hide()
    else
      graphBars[i]:Show()
    end

    local graphEndX = math_min(graphStartX + config.graphBarThickness, gf.grid:GetWidth())

    graphBars[i]:SetPoint("BOTTOMRIGHT", gf.grid, "BOTTOMRIGHT", -graphStartX, 0)
    graphBars[i]:SetPoint("TOPLEFT", gf.grid, "BOTTOMRIGHT", -graphEndX, graphBarValues[(graphBarValuesFirstIndex - i + 1) % numberOfVisibleBars])
  end
  
end



local function DrawGraphBars(graphBars, graphBarValues)
  for i in pairs(graphBars) do
    if i > numberOfVisibleBars then break end
    local smoothProgress = frameCounter / config.framesPerGraphBar
    DrawGraphBar(graphBars, graphBarValues, i, smoothProgress)
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
    graphBarValuesAvg[graphBarValuesFirstIndex] = currentFramerate
   
  else
  
    frameCounter = frameCounter + 1
  
    if config.showMax then maxFPS = math_max(maxFPS, currentFramerate) end
    if config.showAvg then sumFPS = sumFPS + currentFramerate end
    if config.showMin then minFPS = math_min(minFPS, currentFramerate) end
  
    -- If one graph is complete, fill in the value.
    if frameCounter == config.framesPerGraphBar then

      -- Increase the index.
      graphBarValuesFirstIndex = (graphBarValuesFirstIndex + 1) % numberOfVisibleBars

      -- Fill in the current values and reset the counters.
      if config.showMax then
        graphBarValuesMax[graphBarValuesFirstIndex] = maxFPS
        maxFPS = 0
      end
      if config.showAvg then
        graphBarValuesAvg[graphBarValuesFirstIndex] = sumFPS/frameCounter
        sumFPS = 0
      end
      if config.showMin then
        graphBarValuesMin[graphBarValuesFirstIndex] = minFPS
        minFPS = 99999
      end

      frameCounter = 0
    end
  
  end
    
  
  -- Draw the graph.
  if config.framesPerGraphBar == 1 then
    DrawGraphBars(graphBarsAvg, graphBarValuesAvg)
  else
    if config.showMax then DrawGraphBars(graphBarsMax, graphBarValuesMax) end
    if config.showAvg then DrawGraphBars(graphBarsAvg, graphBarValuesAvg) end
    if config.showMin then DrawGraphBars(graphBarsMin, graphBarValuesMin) end
  end
  
end)






local function InsertGraphBar(graphBars, drawLayerSubLevel)
  local newBar = gf.grid:CreateTexture()
  newBar:SetDrawLayer("ARTWORK", drawLayerSubLevel)
  newBar:SetTexture(pixelFilePath)
  tinsert(graphBars, newBar)
end


local function ShowGraphBar(bar, color)
  bar:ClearAllPoints()
  bar:Show()
  bar:SetColorTexture(unpack(color))
end
local function ShowGraphBars(graphBars, color, numberOfRequiredBars)
  for i, bar in pairs(graphBars) do
    if i <= numberOfRequiredBars then
      ShowGraphBar(bar, color)
    else
      bar:Hide()
    end
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
local function RefreshGraph()

  if config.framesPerGraphBar == 1 then
    HideGraph(graphBarsMax, graphBarValuesMax)
    HideGraph(graphBarsMin, graphBarValuesMin)
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
      InsertGraphBar(graphBarsMax, -1)
      InsertGraphBar(graphBarsAvg, 0)
      InsertGraphBar(graphBarsMin, 1)
    end

    numberOfCreatedBars = numberOfRequiredBars
  end

  -- Make visible as many bars as we need and hide the others.
  if config.framesPerGraphBar == 1 then
    ShowGraphBars(graphBarsAvg, config.avgColor, numberOfRequiredBars)
  else
    if config.showMax then ShowGraphBars(graphBarsMax, config.maxColor, numberOfRequiredBars) end
    if config.showAvg then ShowGraphBars(graphBarsAvg, config.avgColor, numberOfRequiredBars) end
    if config.showMin then ShowGraphBars(graphBarsMin, config.minColor, numberOfRequiredBars) end
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












local function AddSlider(parentFrame, anchor, offsetX, offsetY, sliderTitle, variableName, minValue, maxValue, valueStep)
  parentFrame.widthSlider = CreateFrame("Slider", "fpsGraph_"..variableName.."Slider", parentFrame, "OptionsSliderTemplate")
  parentFrame.widthSlider:SetPoint(anchor, offsetX, offsetY)
  parentFrame.widthSlider:SetWidth(240)
  parentFrame.widthSlider:SetHeight(17)
  parentFrame.widthSlider:SetMinMaxValues(minValue, maxValue)
  parentFrame.widthSlider:SetValueStep(valueStep)
  parentFrame.widthSlider:SetObeyStepOnDrag(true)
  parentFrame.widthSlider:SetValue(config[variableName])
   _G[parentFrame.widthSlider:GetName() .. 'Low']:SetText(minValue)
   _G[parentFrame.widthSlider:GetName() .. 'High']:SetText(maxValue)
   _G[parentFrame.widthSlider:GetName() .. 'Text']:SetText(sliderTitle)
  parentFrame.widthSlider:SetScript("OnValueChanged", function(self, value)
      config[variableName] = value
      RefreshGraph()
    end)
end






local cf = nil

function DrawConfigFrame()

  if cf then return end

  cf = CreateFrame("Frame", "fpsGraph_configFrame", UIParent, "ButtonFrameTemplate")

  cf:SetPoint("TOPLEFT")
  ButtonFrameTemplate_HidePortrait(cf)
  -- SetPortraitToTexture(...)
  -- ButtonFrameTemplate_HideAttic(cf)
  -- ButtonFrameTemplate_HideButtonBar(cf)

  cf:SetFrameStrata("HIGH")
  cf:SetWidth(300)
  cf:SetHeight(500)
  cf:SetMovable(true)
  cf:EnableMouse(true)
  cf:RegisterForDrag("LeftButton")
  cf:SetScript("OnDragStart", cf.StartMoving)
  cf:SetScript("OnDragStop", cf.StopMovingOrSizing)
  cf:SetClampedToScreen(true)


  _G[cf:GetName().."TitleText"]:SetText("FPS Graph - Config")
  _G[cf:GetName().."TitleText"]:ClearAllPoints()
  _G[cf:GetName().."TitleText"]:SetPoint("TOPLEFT", 10, -6)




  AddSlider(cf.Inset, "TOP", 3, -20, "Graph width", "graphWidth", graphWidthMin, graphWidthMax, 1)

  AddSlider(cf.Inset, "TOP", 3, -60, "Graph height", "graphHeight", graphHeightMin, graphHeightMax, 1)

  AddSlider(cf.Inset, "TOP", 3, -100, "Graph bar thickness", "graphBarThickness", graphBarThicknessMin, graphBarThicknessMax, 1)

  AddSlider(cf.Inset, "TOP", 3, -140, "Frames per graph bar", "framesPerGraphBar", framesPerGraphBarMin, framesPerGraphBarMax, 1)

  AddSlider(cf.Inset, "TOP", 3, -180, "Graph line thickness", "graphLineThickness", graphLineThicknessMin, graphLineThicknessMax, 1)





  -- tinsert(UISpecialFrames, "fpsGraph_configFrame")
  cf:Show()

end











local addonLoadedFrame = CreateFrame("Frame")
addonLoadedFrame:RegisterEvent("ADDON_LOADED")

addonLoadedFrame:SetScript("OnEvent", function(self, event, arg1, ...)
  if arg1 == folderName then

    if not config then
      config = configDefaults
    else

      -- Remove obsolete values from saved variables.
      for k in pairs (config) do
        if not configDefaults[k] then
          config[k] = nil
        end
      end

      -- Fill missing values.
      for k, v in pairs (configDefaults) do
        if not config[k] then
          config[k] = v
        end
      end


    end


  DrawConfigFrame()

  CreateGraph()


  end
end)






-- https://wow.gamepedia.com/Using_the_ColorPickerFrame
function ShowColorPicker(r, g, b, a, changedCallback)
  ColorPickerFrame.hasOpacity, ColorPickerFrame.opacity = (a ~= nil), a

  ColorPickerFrame.previousValues = {r,g,b,a}

  ColorPickerFrame.func = changedCallback
  ColorPickerFrame.opacityFunc = changedCallback
  ColorPickerFrame.cancelFunc = changedCallback

  ColorPickerFrame:SetColorRGB(r,g,b);

  ColorPickerFrame:Hide(); -- Need to run the OnShow handler.
  ColorPickerFrame:Show();
end


local function myColorCallback(restore)
 local newR, newG, newB, newA;
 if restore then
  -- The user bailed, we extract the old color from the table created by ShowColorPicker.
  newR, newG, newB, newA = unpack(restore);
 else
  -- Something changed
  newA, newR, newG, newB = OpacitySliderFrame:GetValue(), ColorPickerFrame:GetColorRGB();
 end
 
 -- Update our internal storage.
 r, g, b, a = newR, newG, newB, newA;
 -- And update any UI elements that use this color...
end


ShowColorPicker(r, g, b, a, myColorCallback);








-- Texture:SetGradientAlpha(orientation, minR, minG, minB, minA, maxR, maxG, maxB, maxA)
