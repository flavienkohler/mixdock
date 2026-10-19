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

local SLIDER_W = 208 -- design width of a slider track, see Rows.inc
local HIT_PAD = 8    -- the hit area extends this far past each end of the track (the thumb's radius plus a little)
local WHEEL_STEP = 5

local Json
local statePath
local rows = {}   -- slot number -> app shown in it
local outputs = {} -- the footer buttons, from the state's device list
local master = { volume = 0 }
local commandSeq = 0
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
local function hideRow(i)
  rows[i] = nil
  for _, group in ipairs({ 'R' .. i, 'R' .. i .. 'Img', 'R' .. i .. 'Tile', 'R' .. i .. 'Hit' }) do
    setVisible(group, false)
  end
end

local function renderRow(i, app)
  rows[i] = app
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
  setVisible(prefix .. 'Hit', not idle)
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
  master.volume = clampPercent(output.volume)
  setVariable('MasterVol', master.volume)
  setVariable('MasterFill', masterMuted and theme('MutedColor') or theme('Accent'))

  for i = 1, MAX_ROWS do
    if i <= shown then
      renderRow(i, apps[i])
    else
      hideRow(i)
    end
  end

  if shown == 0 then renderMessage('No app is playing audio') else setVisible('Empty', false) end

  outputs = state.devices or {}
  renderFooter(outputs)

  -- The panel grows and shrinks with the number of rows (at least one slot for the empty message).
  local dividerY = ROWS_TOP + math.max(shown, 1) * ROW_H + 4
  setVariable('DividerY', dividerY)
  setVariable('FooterY', dividerY + 14)
  setVariable('PanelH', dividerY + 64)

  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
end

-- Reads the state file and redraws if it changed.
local function readState()
  local file = io.open(statePath, 'rb')
  if not file then
    if lastRaw ~= false then
      lastRaw = false
      for i = 1, MAX_ROWS do hideRow(i) end
      renderMessage('Waiting for the helper (build it with helper\\build.ps1)')
      SKIN:Bang('!UpdateMeter', '*')
      SKIN:Bang('!Redraw')
    end
    return
  end
  local raw = file:read('*a')
  file:close()
  if raw == lastRaw then return end

  local ok, state = pcall(Json.decode, raw)
  if not ok or type(state) ~= 'table' then return end -- half-written or invalid: keep the last picture
  lastRaw = raw
  render(state)
end

-- ---- Commands to the helper: small files that the helper picks up as soon as they appear ----

local function send(...)
  commandSeq = commandSeq + 1
  local base = string.format('%s%d-%06d-%04d', SKIN:ReplaceVariables('#@#Commands\\'), os.time(), commandSeq, math.random(0, 9999))
  local file = io.open(base .. '.tmp', 'wb')
  if not file then return end -- the helper creates the folder when it starts
  file:write(table.concat({ ... }, '\t'))
  file:close()
  os.rename(base .. '.tmp', base .. '.cmd') -- renamed only when complete
end

local function target(i)
  if i == 0 then return '@master' end
  local app = rows[i]
  if app and not app.idle then return app.process end
end

-- Mouse press on a slider (0 = master). The hit area is wider than the track so the thumb can be grabbed at
-- both ends, so the press position is converted to a track percentage. The helper then follows the cursor
-- until the button is released.
function Press(i, percentOfHitArea)
  local who = target(i)
  if not who then return end
  local scale = tonumber(SKIN:GetVariable('Scale')) or 1
  local hitW = SLIDER_W + 2 * HIT_PAD
  local value = ((tonumber(percentOfHitArea) or 0) / 100 * hitW - HIT_PAD) / SLIDER_W * 100
  send('drag', who, tostring(math.floor(clampPercent(value) + 0.5)), tostring(SLIDER_W * scale))
end

-- During a drag the helper sends the new value here: only that slider and its percentage are redrawn.
function Preview(who, value)
  value = clampPercent(value)
  if who == '@master' then
    master.volume = value
    setVariable('MasterVol', value)
    SKIN:Bang('!SetOption', 'MasterPercent', 'Text', value .. '%')
    SKIN:Bang('!UpdateMeter', 'MasterSlider')
    SKIN:Bang('!UpdateMeter', 'MasterPercent')
  else
    for i = 1, MAX_ROWS do
      local app = rows[i]
      if app and app.process == who then
        app.volume = value
        setVariable('R' .. i .. 'Vol', value)
        SKIN:Bang('!SetOption', 'R' .. i .. 'Percent', 'Text', value .. '%')
        SKIN:Bang('!UpdateMeter', 'R' .. i .. 'Slider')
        SKIN:Bang('!UpdateMeter', 'R' .. i .. 'Percent')
        break
      end
    end
  end
  SKIN:Bang('!Redraw')
end

-- Mouse wheel over a row (0 = master): direction 1 up, -1 down.
function Wheel(i, direction)
  local who = target(i)
  if not who then return end
  local current = (i == 0) and master.volume or clampPercent(rows[i].volume)
  local value = clampPercent(current + direction * WHEEL_STEP)
  if i == 0 then
    master.volume = value
    send('master', tostring(value))
  else
    rows[i].volume = value -- remembered right away, so quick successive notches add up
    send('volume', who, tostring(value))
  end
end

-- Output button k (1 to 3) in the footer: make that device the default playback device.
function Output(k)
  local device = outputs[k]
  if device and device.available and not device.active then send('output', device.alias) end
end

-- Mute button of a row (0 = master).
function Mute(i)
  local who = target(i)
  if not who then return end
  if i == 0 then send('master-mute') else send('mute', who, 'toggle') end
end

function Initialize()
  Json = dofile(SKIN:ReplaceVariables('#CURRENTPATH#Scripts\\Json.lua'))
  statePath = SKIN:ReplaceVariables('#@#State\\state.json')
  math.randomseed(os.time())
end

-- Called by the helper right after it wrote the state.
function Refresh()
  readState()
end

-- Slow fallback in case a notification was missed.
function Update()
  readState()
  return 0
end
