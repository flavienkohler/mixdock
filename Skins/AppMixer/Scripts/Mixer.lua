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
local pinnedShown, otherShown = 0, 0 -- number of listed apps in each group
local pinHover = {} -- slot number -> true while the cursor is on its pin button
local lastVolume = {} -- process name -> last volume (0-100) seen while the app had a session
-- Button that is currently pressed (e.g. 'mute:2'); see Click().
local pressedButton
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

-- Same color with another opacity: 'r,g,b,a' -> 'r,g,b,alpha'.
local function withAlpha(color, alpha)
  return (color:gsub(',%d+$', ',' .. alpha))
end

local function hideRow(i)
  rows[i] = nil
  for _, group in ipairs({ 'R' .. i, 'R' .. i .. 'Img', 'R' .. i .. 'Tile', 'R' .. i .. 'Hit',
                           'R' .. i .. 'Pin', 'R' .. i .. 'Grab' }) do
    setVisible(group, false)
  end
end

-- The pin button is grey and translucent when the app is not pinned, bright (accent colored) when it is,
-- and a little brighter while the cursor is on it.
local function paintPin(i)
  local app = rows[i]
  if not app then return end
  local color
  if app.pinned then
    color = pinHover[i] and theme('PinOnHoverColor') or theme('Accent')
  else
    color = pinHover[i] and theme('PinOffHoverColor') or theme('PinOffColor')
  end
  setOption('R' .. i .. 'PinGlyph', 'FontColor', color)
end

-- Icon glyphs are passed as variable names ('#IconMute#'): Rainmeter expands them, whereas a glyph read
-- through Lua would be mangled by the codepage.
local function renderRow(i, app)
  rows[i] = app
  local prefix = 'R' .. i
  local idle = app.idle == true -- pinned and running, but no audio session yet: dimmed, nothing to control
  local muted = app.muted == true
  local silent = app.active ~= true -- has a session but nothing is playing (e.g. Discord after a call): dimmed, still adjustable
  local name = app.name or app.process or '?'

  setOption(prefix .. 'Name', 'Text', name)
  setOption(prefix .. 'Name', 'FontColor',
    (muted or idle) and theme('MutedColor') or (silent and theme('TextDimColor') or theme('TextColor')))
  -- An app without a session has no volume to read, so its slider shows the last volume seen for it, if any.
  local volume
  if idle then
    volume = lastVolume[app.process]
  else
    volume = clampPercent(app.volume)
    lastVolume[app.process] = volume
  end
  local dimmed = idle or silent -- not playing: the slider keeps its place but is drawn faded

  setOption(prefix .. 'Percent', 'Text', volume and (volume .. '%') or '')
  setOption(prefix .. 'Percent', 'FontColor', muted and theme('MutedColor') or theme('TextDimColor'))
  setOption(prefix .. 'Mute', 'Text', idle and '' or (muted and '#IconMute#' or '#IconVolume#'))
  setOption(prefix .. 'Mute', 'FontColor', muted and theme('MutedColor') or theme('TextColor'))
  setVariable(prefix .. 'Vol', volume or 0)
  setVariable(prefix .. 'Track', theme('TrackColor'))
  local fill, thumb
  if volume == nil then
    fill, thumb = TRANSPARENT, TRANSPARENT -- nothing known yet: just the empty track
  elseif muted then
    fill, thumb = theme('MutedColor'), '160,160,168,255'
  elseif dimmed then
    fill, thumb = withAlpha(theme('Accent'), 105), '255,255,255,140'
  else
    fill, thumb = theme('Accent'), '255,255,255,255'
  end
  setVariable(prefix .. 'Fill', fill)
  setVariable(prefix .. 'Thumb', thumb)

  setVariable(prefix .. 'Tile', idle and DIM_TILE or tileColor(app.process or name))
  setOption(prefix .. 'Letter', 'Text', name:sub(1, 1):upper())
  setOption(prefix .. 'Img', 'ImageAlpha', idle and '110' or (silent and '150' or '255'))

  local hasIcon = app.icon ~= nil
  if hasIcon then setOption(prefix .. 'Img', 'ImageName', SKIN:ReplaceVariables('#@#') .. app.icon) end
  setVisible(prefix, true)
  setVisible(prefix .. 'Img', hasIcon)
  setVisible(prefix .. 'Tile', not hasIcon)
  setVisible(prefix .. 'Hit', not idle)

  -- Gutter: the pin button is always there, the reorder grip only when the app's group (pinned or other apps)
  -- has at least two apps to reorder.
  local pinned = app.pinned == true
  paintPin(i)
  setVisible(prefix .. 'Pin', true)
  setVisible(prefix .. 'Grab', (pinned and pinnedShown or otherShown) >= 2)
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
  pinnedShown, otherShown = 0, 0
  for i = 1, shown do
    if apps[i].pinned then pinnedShown = pinnedShown + 1 else otherShown = otherShown + 1 end
  end

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
  pressedButton = nil
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

-- The cursor entered (on = 1) or left (on = 0) the pin button of a row: brighten it.
function PinHover(i, on)
  if not rows[i] then return end
  pinHover[i] = on == 1
  if on == 0 then pressedButton = nil end -- moving off the button cancels a click in progress
  paintPin(i)
  SKIN:Bang('!UpdateMeter', 'R' .. i .. 'PinGlyph')
  SKIN:Bang('!Redraw')
end

-- The cursor is on (on = 1) or left (on = 0) the reorder handle of a row: make it a little more visible.
function GrabHover(i, on)
  setVariable('R' .. i .. 'Grab', on == 1 and theme('GrabHoverColor') or theme('GrabColor'))
  SKIN:Bang('!UpdateMeter', 'R' .. i .. 'Grab')
  SKIN:Bang('!Redraw')
end

-- Press on the reorder handle: the helper moves the app inside its group as the cursor moves, one place per row height.
function Reorder(i)
  pressedButton = nil
  local app = rows[i]
  if not app then return end
  local scale = tonumber(SKIN:GetVariable('Scale')) or 1
  send('reorder', app.process, tostring(ROW_H * scale))
end

-- Click on the pin button of a row: pin the app, or unpin it if it is pinned.
function Pin(i)
  local app = rows[i]
  if app then send('pin', app.process) end
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

-- Clickable buttons call Down() when the mouse goes down on them and Click() when it comes up. Rainmeter fires the
-- mouse-up action of whatever button is under the cursor, even after a drag that started elsewhere, so a slider or
-- reorder drag released over a pin or mute button would click it. A click only counts if the press began on that button.
function Down(kind, i)
  pressedButton = kind .. ':' .. i
end

function Cancel()
  pressedButton = nil
end

function Click(kind, i)
  local pressed = pressedButton == kind .. ':' .. i
  pressedButton = nil
  if not pressed then return end
  if kind == 'pin' then Pin(i) elseif kind == 'mute' then Mute(i) elseif kind == 'output' then Output(i) end
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
