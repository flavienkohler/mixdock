-- Mixer.lua: reads the helper's state file and updates the panel.
-- Rainmeter cannot create meters at runtime, so the skin has a fixed pool of row slots (see Rows.inc)
-- that this script fills and shows or hides.

local MAX_ROWS = 6
local ROWS_TOP, ROW_H = 112, 52
local TILE_COLORS = {
  '124,92,230,255', '20,150,120,255', '220,110,40,255',
  '205,60,130,255', '40,130,210,255', '150,130,30,255',
}

local TRANSPARENT = '0,0,0,0'
local DIM_TILE = '120,120,130,110'

local Json
local statePath
local lastRaw
local cache = {} -- last value sent per target, so unchanged values cost no bang

local function setOption(meter, option, value)
  local key = meter .. '/' .. option
  if cache[key] ~= value then
    cache[key] = value
    SKIN:Bang('!SetOption', meter, option, value)
  end
end

local function setVariable(name, value)
  value = tostring(value)
  local key = '$' .. name
  if cache[key] ~= value then
    cache[key] = value
    SKIN:Bang('!SetVariable', name, value)
  end
end

local function setVisible(group, visible)
  local key = '#' .. group
  if cache[key] ~= visible then
    cache[key] = visible
    SKIN:Bang(visible and '!ShowMeterGroup' or '!HideMeterGroup', group)
  end
end

local function theme(name)
  return SKIN:GetVariable(name)
end

local function tileColor(process)
  local sum = 0
  for i = 1, #process do sum = sum + process:byte(i) end
  return TILE_COLORS[sum % #TILE_COLORS + 1]
end

local function clampPercent(v)
  v = tonumber(v) or 0
  if v < 0 then return 0 elseif v > 100 then return 100 end
  return v
end

-- Icon glyphs are passed as variable names ('#IconMute#'): Rainmeter expands them, whereas a glyph read
-- through Lua would be mangled by the codepage.
local function renderRow(i, app)
  local prefix = 'R' .. i
  local idle = app.idle == true -- pinned and running, but no audio session yet: dimmed, nothing to control
  local muted = app.muted == true
  local name = app.name or app.process or '?'

  setOption(prefix .. 'Name', 'Text', name)
  setOption(prefix .. 'Name', 'FontColor', (muted or idle) and theme('MutedColor') or theme('TextColor'))
  setOption(prefix .. 'Percent', 'Text', idle and '' or (clampPercent(app.volume) .. '%'))
  setOption(prefix .. 'Percent', 'FontColor', muted and theme('MutedColor') or theme('TextDimColor'))
  setOption(prefix .. 'Mute', 'Text', idle and '' or (muted and '#IconMute#' or '#IconVolume#'))
  setOption(prefix .. 'Mute', 'FontColor', muted and theme('MutedColor') or theme('TextColor'))
  setVariable(prefix .. 'Vol', idle and 0 or clampPercent(app.volume))
  setVariable(prefix .. 'Track', idle and TRANSPARENT or theme('TrackColor'))
  setVariable(prefix .. 'Fill', idle and TRANSPARENT or (muted and theme('MutedColor') or theme('Accent')))
  setVariable(prefix .. 'Thumb', idle and TRANSPARENT or (muted and '160,160,168,255' or '255,255,255,255'))

  setVariable(prefix .. 'Tile', idle and DIM_TILE or tileColor(app.process or name))
  setOption(prefix .. 'Letter', 'Text', name:sub(1, 1):upper())
  setOption(prefix .. 'Img', 'ImageAlpha', idle and '110' or '255')

  local hasIcon = app.icon ~= nil
  if hasIcon then setOption(prefix .. 'Img', 'ImageName', SKIN:ReplaceVariables('#@#') .. app.icon) end
  setVisible(prefix, true)
  setVisible(prefix .. 'Img', hasIcon)
  setVisible(prefix .. 'Tile', not hasIcon)
end

local function renderFooter(devices)
  for k = 1, 3 do
    local device = devices[k]
    local meter = 'Out' .. k
    if device then
      local fill, text = theme('ButtonColor'), theme('TextColor')
      if device.active then
        fill, text = theme('Accent'), theme('AccentText')
      elseif not device.available then
        text = theme('MutedColor')
      end
      setVariable(meter .. 'Fill', fill)
      setOption(meter .. 'Label', 'Text', device.name or device.alias or '')
      setOption(meter .. 'Label', 'FontColor', text)
    end
    setVisible(meter, device ~= nil)
  end
end

local function renderMessage(text)
  setOption('EmptyText', 'Text', text)
  setVisible('Empty', true)
end

local function render(state)
  local apps = state.apps or {}
  local shown = math.min(#apps, MAX_ROWS)

  local output = state.output or {}
  local masterMuted = output.muted == true
  setOption('MasterName', 'Text', output.name or 'No output device')
  setOption('MasterPercent', 'Text', clampPercent(output.volume) .. '%')
  setOption('MasterIcon', 'Text', masterMuted and '#IconMute#' or '#IconVolume#')
  setVariable('MasterVol', clampPercent(output.volume))
  setVariable('MasterFill', masterMuted and theme('MutedColor') or theme('Accent'))

  for i = 1, MAX_ROWS do
    if i <= shown then
      renderRow(i, apps[i])
    else
      for _, group in ipairs({ 'R' .. i, 'R' .. i .. 'Img', 'R' .. i .. 'Tile' }) do setVisible(group, false) end
    end
  end

  if shown == 0 then renderMessage('No app is playing audio') else setVisible('Empty', false) end

  renderFooter(state.devices or {})

  -- The panel grows and shrinks with the number of rows (at least one slot for the empty message).
  local dividerY = ROWS_TOP + math.max(shown, 1) * ROW_H + 4
  setVariable('DividerY', dividerY)
  setVariable('FooterY', dividerY + 14)
  setVariable('PanelH', dividerY + 64)

  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
end

function Initialize()
  Json = dofile(SKIN:ReplaceVariables('#CURRENTPATH#Scripts\\Json.lua'))
  statePath = SKIN:ReplaceVariables('#@#State\\state.json')
end

function Update()
  local file = io.open(statePath, 'rb')
  if not file then
    if lastRaw ~= false then
      lastRaw = false
      for i = 1, MAX_ROWS do
        for _, group in ipairs({ 'R' .. i, 'R' .. i .. 'Img', 'R' .. i .. 'Tile' }) do setVisible(group, false) end
      end
      renderMessage('Waiting for the helper (build it with helper\\build.ps1)')
      SKIN:Bang('!UpdateMeter', '*')
      SKIN:Bang('!Redraw')
    end
    return 0
  end
  local raw = file:read('*a')
  file:close()
  if raw == lastRaw then return 0 end

  local ok, state = pcall(Json.decode, raw)
  if not ok or type(state) ~= 'table' then return 0 end -- half-written or invalid: keep the last picture
  lastRaw = raw
  render(state)
  return 1
end
