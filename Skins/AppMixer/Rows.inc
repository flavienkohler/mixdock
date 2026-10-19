; Rows.inc - the pool of 6 app row slots. Mixer.lua fills and shows or hides them.
; The six rows are identical except for their number and vertical position.

; ---------- Row 1 ----------

[R1Tile]
Meter=Shape
MeterStyle=StTile
Y=(120*#Scale#)
Shape=Rectangle 0,0,(28*#Scale#),(28*#Scale#),(7*#Scale#) | Fill Color #R1Tile# | StrokeWidth 0
Group=R1Tile

[R1Letter]
Meter=String
MeterStyle=StLetter
Y=(124*#Scale#)
Group=R1Tile

[R1Img]
Meter=Image
MeterStyle=StImg
Y=(122*#Scale#)
Group=R1Img

[R1Name]
Meter=String
MeterStyle=StName
Y=(116*#Scale#)
Group=R1

[R1Percent]
Meter=String
MeterStyle=StPercent
Y=(116*#Scale#)
Group=R1

[R1Slider]
Meter=Shape
MeterStyle=StSlider
Y=(144*#Scale#)
Shape=Rectangle 0,0,(208*#Scale#),(6*#Scale#),(3*#Scale#) | Fill Color #R1Track# | StrokeWidth 0
Shape2=Rectangle 0,0,(208*#Scale#*#R1Vol#/100),(6*#Scale#),(3*#Scale#) | Fill Color #R1Fill# | StrokeWidth 0
Shape3=Ellipse (208*#Scale#*#R1Vol#/100),(3*#Scale#),(7*#Scale#) | Fill Color #R1Thumb# | StrokeWidth 0
Group=R1

[R1Mute]
Meter=String
MeterStyle=StMute
Y=(119*#Scale#)
Group=R1

; ---------- Row 2 ----------

[R2Tile]
Meter=Shape
MeterStyle=StTile
Y=(172*#Scale#)
Shape=Rectangle 0,0,(28*#Scale#),(28*#Scale#),(7*#Scale#) | Fill Color #R2Tile# | StrokeWidth 0
Group=R2Tile

[R2Letter]
Meter=String
MeterStyle=StLetter
Y=(176*#Scale#)
Group=R2Tile

[R2Img]
Meter=Image
MeterStyle=StImg
Y=(174*#Scale#)
Group=R2Img

[R2Name]
Meter=String
MeterStyle=StName
Y=(168*#Scale#)
Group=R2

[R2Percent]
Meter=String
MeterStyle=StPercent
Y=(168*#Scale#)
Group=R2

[R2Slider]
Meter=Shape
MeterStyle=StSlider
Y=(196*#Scale#)
Shape=Rectangle 0,0,(208*#Scale#),(6*#Scale#),(3*#Scale#) | Fill Color #R2Track# | StrokeWidth 0
Shape2=Rectangle 0,0,(208*#Scale#*#R2Vol#/100),(6*#Scale#),(3*#Scale#) | Fill Color #R2Fill# | StrokeWidth 0
Shape3=Ellipse (208*#Scale#*#R2Vol#/100),(3*#Scale#),(7*#Scale#) | Fill Color #R2Thumb# | StrokeWidth 0
Group=R2

[R2Mute]
Meter=String
MeterStyle=StMute
Y=(171*#Scale#)
Group=R2

; ---------- Row 3 ----------

[R3Tile]
Meter=Shape
MeterStyle=StTile
Y=(224*#Scale#)
Shape=Rectangle 0,0,(28*#Scale#),(28*#Scale#),(7*#Scale#) | Fill Color #R3Tile# | StrokeWidth 0
Group=R3Tile

[R3Letter]
Meter=String
MeterStyle=StLetter
Y=(228*#Scale#)
Group=R3Tile

[R3Img]
Meter=Image
MeterStyle=StImg
Y=(226*#Scale#)
Group=R3Img

[R3Name]
Meter=String
MeterStyle=StName
Y=(220*#Scale#)
Group=R3

[R3Percent]
Meter=String
MeterStyle=StPercent
Y=(220*#Scale#)
Group=R3

[R3Slider]
Meter=Shape
MeterStyle=StSlider
Y=(248*#Scale#)
Shape=Rectangle 0,0,(208*#Scale#),(6*#Scale#),(3*#Scale#) | Fill Color #R3Track# | StrokeWidth 0
Shape2=Rectangle 0,0,(208*#Scale#*#R3Vol#/100),(6*#Scale#),(3*#Scale#) | Fill Color #R3Fill# | StrokeWidth 0
Shape3=Ellipse (208*#Scale#*#R3Vol#/100),(3*#Scale#),(7*#Scale#) | Fill Color #R3Thumb# | StrokeWidth 0
Group=R3

[R3Mute]
Meter=String
MeterStyle=StMute
Y=(223*#Scale#)
Group=R3

; ---------- Row 4 ----------

[R4Tile]
Meter=Shape
MeterStyle=StTile
Y=(276*#Scale#)
Shape=Rectangle 0,0,(28*#Scale#),(28*#Scale#),(7*#Scale#) | Fill Color #R4Tile# | StrokeWidth 0
Group=R4Tile

[R4Letter]
Meter=String
MeterStyle=StLetter
Y=(280*#Scale#)
Group=R4Tile

[R4Img]
Meter=Image
MeterStyle=StImg
Y=(278*#Scale#)
Group=R4Img

[R4Name]
Meter=String
MeterStyle=StName
Y=(272*#Scale#)
Group=R4

[R4Percent]
Meter=String
MeterStyle=StPercent
Y=(272*#Scale#)
Group=R4

[R4Slider]
Meter=Shape
MeterStyle=StSlider
Y=(300*#Scale#)
Shape=Rectangle 0,0,(208*#Scale#),(6*#Scale#),(3*#Scale#) | Fill Color #R4Track# | StrokeWidth 0
Shape2=Rectangle 0,0,(208*#Scale#*#R4Vol#/100),(6*#Scale#),(3*#Scale#) | Fill Color #R4Fill# | StrokeWidth 0
Shape3=Ellipse (208*#Scale#*#R4Vol#/100),(3*#Scale#),(7*#Scale#) | Fill Color #R4Thumb# | StrokeWidth 0
Group=R4

[R4Mute]
Meter=String
MeterStyle=StMute
Y=(275*#Scale#)
Group=R4

; ---------- Row 5 ----------

[R5Tile]
Meter=Shape
MeterStyle=StTile
Y=(328*#Scale#)
Shape=Rectangle 0,0,(28*#Scale#),(28*#Scale#),(7*#Scale#) | Fill Color #R5Tile# | StrokeWidth 0
Group=R5Tile

[R5Letter]
Meter=String
MeterStyle=StLetter
Y=(332*#Scale#)
Group=R5Tile

[R5Img]
Meter=Image
MeterStyle=StImg
Y=(330*#Scale#)
Group=R5Img

[R5Name]
Meter=String
MeterStyle=StName
Y=(324*#Scale#)
Group=R5

[R5Percent]
Meter=String
MeterStyle=StPercent
Y=(324*#Scale#)
Group=R5

[R5Slider]
Meter=Shape
MeterStyle=StSlider
Y=(352*#Scale#)
Shape=Rectangle 0,0,(208*#Scale#),(6*#Scale#),(3*#Scale#) | Fill Color #R5Track# | StrokeWidth 0
Shape2=Rectangle 0,0,(208*#Scale#*#R5Vol#/100),(6*#Scale#),(3*#Scale#) | Fill Color #R5Fill# | StrokeWidth 0
Shape3=Ellipse (208*#Scale#*#R5Vol#/100),(3*#Scale#),(7*#Scale#) | Fill Color #R5Thumb# | StrokeWidth 0
Group=R5

[R5Mute]
Meter=String
MeterStyle=StMute
Y=(327*#Scale#)
Group=R5

; ---------- Row 6 ----------

[R6Tile]
Meter=Shape
MeterStyle=StTile
Y=(380*#Scale#)
Shape=Rectangle 0,0,(28*#Scale#),(28*#Scale#),(7*#Scale#) | Fill Color #R6Tile# | StrokeWidth 0
Group=R6Tile

[R6Letter]
Meter=String
MeterStyle=StLetter
Y=(384*#Scale#)
Group=R6Tile

[R6Img]
Meter=Image
MeterStyle=StImg
Y=(382*#Scale#)
Group=R6Img

[R6Name]
Meter=String
MeterStyle=StName
Y=(376*#Scale#)
Group=R6

[R6Percent]
Meter=String
MeterStyle=StPercent
Y=(376*#Scale#)
Group=R6

[R6Slider]
Meter=Shape
MeterStyle=StSlider
Y=(404*#Scale#)
Shape=Rectangle 0,0,(208*#Scale#),(6*#Scale#),(3*#Scale#) | Fill Color #R6Track# | StrokeWidth 0
Shape2=Rectangle 0,0,(208*#Scale#*#R6Vol#/100),(6*#Scale#),(3*#Scale#) | Fill Color #R6Fill# | StrokeWidth 0
Shape3=Ellipse (208*#Scale#*#R6Vol#/100),(3*#Scale#),(7*#Scale#) | Fill Color #R6Thumb# | StrokeWidth 0
Group=R6

[R6Mute]
Meter=String
MeterStyle=StMute
Y=(379*#Scale#)
Group=R6
