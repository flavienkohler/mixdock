; Theme.inc - all colors, sizes and fonts of the AppMixer panel.
; Sizes are design pixels; the skin multiplies them by Scale.

[Variables]
; Global scale. Raise it on a screen that looks too small (125% screen: try 1.25).
Scale=1

; Panel
PanelW=340
; Width of the gutter left of the app icons (pin button and reorder grip)
Gutter=20
PanelH=336
Radius=12
Pad=16

; Colors (R,G,B,A)
BgColor=24,24,28,238
BorderColor=255,255,255,40
TrackColor=255,255,255,40
TextColor=255,255,255,235
TextDimColor=255,255,255,140
DividerColor=255,255,255,25
ButtonColor=255,255,255,18
Accent=96,165,250,255
AccentText=14,18,26,255
MutedColor=255,255,255,90
PinOffColor=255,255,255,55
PinOffHoverColor=255,255,255,150
PinOnHoverColor=160,205,255,255
GrabColor=255,255,255,42
GrabHoverColor=255,255,255,150

; Fonts
Font=Segoe UI Variable Text
IconFont=Segoe Fluent Icons
FontSize=9
SmallFontSize=8
TitleFontSize=11
IconSize=11

; Icon glyphs (Segoe Fluent Icons, Windows 11). Literal characters: this file must stay UTF-16 LE (Rainmeter reads it as such).
IconClose=
IconVolume=
IconMute=
IconPin=
IconUnpin=
