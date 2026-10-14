class_name Interactable
extends StaticBody3D
## Something a guard can look at and press E on, such as the clock machine or the vending machine.

signal used(by: Node)

## Physics layer for things guards can press E on without bumping into them, like a monster
## you can talk to. Guards' use ray checks it along with the normal layer.
const TALK_LAYER := 1 << 5

## Shown on screen as "[E] <prompt>" while the guard looks at it.
@export var prompt := "Use"
## Optional message shown to the guard after using it.
@export var message := ""
## When above 0, the guard has to hold E for this many seconds (while looking at it) to use it.
@export var hold_seconds := 0.0


func interact(by: Node) -> void:
	used.emit(by)
	if message != "" and by.has_method("show_message"):
		by.show_message(message)
