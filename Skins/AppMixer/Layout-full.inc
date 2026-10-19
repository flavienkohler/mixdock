; Layout-full.inc - the full layout: app names, percentages and labelled output buttons.
; Design pixels; the skin multiplies them by Scale. Rows.inc is generated from the row values (tools\generate-rows.ps1).

[Variables]
; Panel
PanelW=340
PanelH=336
Pad=16
Gutter=20

; Fonts
FontSize=9
SmallFontSize=8
TitleFontSize=11
IconSize=11
PinSize=10

; Header
TitleText=Volume
GripY=13
GripHitX=8
GripHitY=4
GripHitW=28
GripHitH=34
CloseY=14

; Master row
MasterNameY=50
MasterNameW=186
MasterIconY=76
MasterIconSize=14
MasterSliderY=82
MasterHitY=74
MasterPercentY=50
Divider1Y=104

; App rows (the first row starts at RowsTop, every row is RowH high; the Y values are relative to the row)
RowsTop=112
RowH=52
TileSize=28
TileY=8
ImgSize=24
ImgY=10
LetterY=12
NameY=4
NameW=180
PercentY=4
SliderGap=40
SliderW=208
SliderY=32
HitY=24
HitH=22
HitPad=8
MuteY=17
PinGlyphY=12
PinHitY=2
PinHitH=20
GrabY=24
GrabHitH=16
GrabBarW=10
GrabBarH=12
; Where the percentage and the mute button are drawn (right aligned, design x)
PercentX=292
MuteX=320
EmptyY=128

; Footer: the output buttons (the divider sits DividerGap under the last row)
DividerGap=4
FooterGap=14
FooterH=36
BottomPad=14
ButtonW=96
ButtonGap=10
ButtonRadius=8
ButtonTextY=9