; Theme.inc - colors, fonts and icons shared by both layouts. Positions and sizes are in Layout-full.inc and
; Layout-compact.inc (design pixels; the skin multiplies them by Scale).

[Variables]
; Global scale. Raise it on a screen that looks too small (125% screen: try 1.25).
Scale=1
; Which layout file is used: full or compact (the right-click menu changes it in Settings.inc).
Layout=full
Radius=12

; Colors (R,G,B,A)
BgRGB=24,24,28
BgAlpha=230
BgColor=#BgRGB#,#BgAlpha#
BorderColor=255,255,255,40
TrackColor=255,255,255,40
TextColor=255,255,255,235
TextDimColor=255,255,255,140
DividerColor=255,255,255,25
ButtonColor=255,255,255,18
; Highlight color. AccentMode=auto follows the Windows accent color, custom uses AccentCustom (RRGGBB or r,g,b).
AccentMode=auto
AccentCustom=60A5FA
Accent=96,165,250,255
AccentText=14,18,26,255
MutedColor=255,255,255,90
PinOffColor=255,255,255,55
PinOffHoverColor=255,255,255,150
GrabColor=255,255,255,42
GrabHoverColor=255,255,255,150

; Fonts
Font=Segoe UI Variable Text
IconFont=Segoe Fluent Icons

; Icon glyphs (Segoe Fluent Icons, Windows 11). Literal characters: this file must stay UTF-16 LE (Rainmeter reads it as such).
; The output icons can be chosen per output with "icon" in the helper's config.json (headset, speakers, monitor, jack, gamepad).
IconClose=
IconVolume=
IconMute=
IconPin=
IconHeadset=
IconSpeakers=
IconMonitor=
IconJack=
IconGamepad=