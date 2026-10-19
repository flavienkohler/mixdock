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
local accent, accentText, accentHover -- the highlight color, the text color on it, and a lighter shade for hover
local settings = {} -- user choices kept in Settings.inc: AccentMode, AccentCustom, BgAlpha
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

-- ---- Settings and accent color ----

local PRESETS = { blue = '60A5FA', violet = 'A78BFA', green = '4ADE80', orange = 'FB923C', pink = 'F472B6', red = 'F87171' }
local SETTING_KEYS = { 'AccentMode', 'AccentCustom', 'BgAlpha' }
local OPACITIES = { 100, 90, 80, 70, 60, 50 } -- percent, the choices of the menu

-- Panel opacity in percent -> the alpha value (0-255) used in the background color.
local function alphaOf(percent)
  return math.floor(percent * 2.55 + 0.5)
end

-- 'RRGGBB', '#RRGGBB' or 'r,g,b' -> r, g, b (or nil)
local function parseColor(text)
  text = tostring(text or ''):gsub('%s', '')
  local r, g, b = text:match('^(%d+),(%d+),(%d+)')
  if r then return tonumber(r), tonumber(g), tonumber(b) end
  local hex = text:gsub('^#', '')
  if #hex == 6 and hex:match('^%x+$') then
    return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
  end
end

-- The Windows accent color: a DWORD in the registry holding alpha, blue, green, red (one byte each).
local function windowsAccent()
  local measure = SKIN:GetMeasure('WinAccent')
  local n = measure and measure:GetValue() or 0
  if n <= 0 then return nil end
  return n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256
end

-- Works out the accent color from the settings. Returns true when it changed.
local function updateAccent()
  local r, g, b
  if settings.AccentMode == 'custom' then r, g, b = parseColor(settings.AccentCustom) else r, g, b = windowsAccent() end
  if not r then r, g, b = parseColor(PRESETS.blue) end

  local color = string.format('%d,%d,%d,255', r, g, b)
  if color == accent then return false end
  accent = color
  local luminance = 0.299 * r + 0.587 * g + 0.114 * b
  accentText = luminance > 150 and '14,18,26,255' or '255,255,255,255'
  -- lighter shade for hover: a third of the way to white
  accentHover = string.format('%d,%d,%d,255', math.floor(r + (255 - r) / 3), math.floor(g + (255 - g) / 3), math.floor(b + (255 - b) / 3))
  return true
end

local function saveSettings()
  local file = io.open(SKIN:ReplaceVariables('#CURRENTPATH#Settings.inc'), 'wb')
  if not file then return end
  file:write('; AppMixer settings. The skin\'s right-click menu writes this file; you can also edit it by hand.\r\n')
  file:write('; AccentMode: auto (Windows accent color) or custom. AccentCustom: RRGGBB (for example 3B82F6) or r,g,b.\r\n')
  file:write('; BgAlpha: opacity of the panel, 110 (see-through) to 255 (solid).\r\n\r\n[Variables]\r\n')
  for _, key in ipairs(SETTING_KEYS) do file:write(key .. '=' .. tostring(settings[key]) .. '\r\n') end
  file:close()
end

-- Puts a check mark (">") in front of the current accent and opacity choices in the right-click menu.
local function updateMenuMarks()
  local custom = settings.AccentMode == 'custom'
  local chosen = custom and tostring(settings.AccentCustom):upper():gsub('^#', '') or nil
  local marks = { Auto = not custom, Custom = custom }
  for name, hex in pairs(PRESETS) do
    local isPreset = custom and chosen == hex
    marks[name:sub(1, 1):upper() .. name:sub(2)] = isPreset
    if isPreset then marks.Custom = false end
  end
  for _, percent in ipairs(OPACITIES) do marks['Op' .. percent] = settings.BgAlpha == alphaOf(percent) end
  for name, on in pairs(marks) do SKIN:Bang('!SetVariable', 'Mark' .. name, on and '> ' or '') end
end

local function loadSettings()
  settings.AccentMode = theme('AccentMode') == 'custom' and 'custom' or 'auto'
  settings.AccentCustom = theme('AccentCustom')
  settings.BgAlpha = tonumber(theme('BgAlpha')) or 238
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
    color = pinHover[i] and accentHover or accent
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
    fill, thumb = withAlpha(accent, 105), '255,255,255,140'
  else
    fill, thumb = accent, '255,255,255,255'
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
        fill, text = accent, accentText
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
  setVariable('MasterFill', masterMuted and theme('MutedColor') or accent)

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

-- ---- Right-click menu actions ----

-- Works out the accent again; when it changed, publishes it and forces a repaint from the state file.
local function refreshAccent()
  if not updateAccent() then return false end
  SKIN:Bang('!SetVariable', 'Accent', accent)
  SKIN:Bang('!SetVariable', 'AccentText', accentText)
  lastRaw = nil
  return true
end

function SetAccent(name)
  if name == 'auto' then
    settings.AccentMode = 'auto'
  elseif name == 'custom' then
    settings.AccentMode = 'custom'
  else
    settings.AccentMode = 'custom'
    settings.AccentCustom = PRESETS[name] or settings.AccentCustom
  end
  saveSettings()
  refreshAccent()
  updateMenuMarks()
  readState()
  if name == 'custom' then EditSettings() end
end

-- Sets the panel opacity (a percentage) and keeps it.
function SetOpacity(percent)
  settings.BgAlpha = alphaOf(tonumber(percent) or 100)
  local color = theme('BgRGB') .. ',' .. settings.BgAlpha
  SKIN:Bang('!SetVariable', 'BgAlpha', settings.BgAlpha)
  SKIN:Bang('!SetVariable', 'BgColor', color)
  SKIN:Bang('!UpdateMeter', 'Background')
  SKIN:Bang('!Redraw')
  saveSettings()
  updateMenuMarks()
end
-- Opens the settings file for editing (a custom accent color is typed there).
function EditSettings()
  saveSettings()
  SKIN:Bang('["notepad.exe" "' .. SKIN:ReplaceVariables('#CURRENTPATH#Settings.inc') .. '"]')
end
function Initialize()
  Json = dofile(SKIN:ReplaceVariables('#CURRENTPATH#Scripts\\Json.lua'))
  statePath = SKIN:ReplaceVariables('#@#State\\state.json')
  math.randomseed(os.time())
  loadSettings()
  updateAccent()
  SKIN:Bang('!SetVariable', 'Accent', accent)
  SKIN:Bang('!SetVariable', 'AccentText', accentText)
  updateMenuMarks()
end

-- Called by the helper right after it wrote the state.
function Refresh()
  readState()
end

-- Slow fallback in case a notification was missed.
function Update()
  if refreshAccent() then updateMenuMarks() end -- follows a change of the Windows accent color
  readState()
  return 0
end
