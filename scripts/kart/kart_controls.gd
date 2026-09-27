class_name KartControls
extends RefCounted

## What the driver is asking the kart to do right now. A person, the AI or a
## network peer all fill in the same four things.

var throttle := 0.0 # 0 to 1
var brake := 0.0 # 0 to 1, and it reverses once the kart has stopped
var steer := 0.0 # -1 is full left, 1 is full right
var reset := false
