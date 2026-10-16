class_name BoneTweak
extends SkeletonModifier3D
## Bends one bone of a rigged model on top of whatever it's animating, e.g. the Other
## Cleaner's head leaning too far, or the Crossing Guard's arm raising the STOP sign.
## `axis` is in the skeleton's space (the model faces +Z); `amount` blends it in and out.

var bone := ""
var axis := Vector3.FORWARD
var angle := 0.0
var amount := 1.0


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null or amount <= 0.001:
		return
	var index := skeleton.find_bone(bone)
	if index < 0:
		return
	var pose := skeleton.get_bone_global_pose(index)
	var turn := Basis(axis.normalized(), angle * amount)
	skeleton.set_bone_global_pose(index, Transform3D(turn * pose.basis, pose.origin))
