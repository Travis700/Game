class_name KeyText
## For scripts that can't name the Controls autoload directly (class_name scripts): fills in
## "{use}", "{item}"... with the player's own keys.


static func fill(text: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var controls: Node = tree.root.get_node_or_null("/root/Controls") if tree else null
	return controls.fill(text) if controls else text


static func key(action: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var controls: Node = tree.root.get_node_or_null("/root/Controls") if tree else null
	return controls.key_name(action) if controls else "?"
