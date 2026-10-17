extends CanvasLayer
## The menu's "Credits" page: who made the game, and the licences of the software it's built
## on (Godot Engine and the libraries inside it, and GodotSteam). Shipping a Godot game
## requires showing Godot's licence somewhere like this.

signal closed

const CREDITS := """NIGHT SHIFT

A game by %s.

Made with Godot Engine.
Textures from Poly Haven (polyhaven.com, CC0) by Charlotte Baglioni, Dimitrios Savva, Rob Tuytel and Dario Barresi.
School furniture and yard models from Sketchfab (sketchfab.com), CC BY 4.0, changed for the game: School chair by N-Gon, School Cafeteria Table by Avot, Vending Machine by Emanuel Silva, Trash Can by Yury Misiyuk, School Chair by heloisebelisle, Teachers Desk by cig3d, Drinking Fountain by FLUXIUM3D, Fire Extinguisher by Loïc, Bulletin Board by lydia.la, Whiteboard by Darren McNerney 3D, Projector by GokouFG, Realistic Tree by Daniel, Park Bench by RBG_illustrations, Wooden Picnic Table by Mark Peters, Bike Rack by Igrium, Dumpster by Chenchanchong, Fire Hydrant by Denko, School Bus by Macaroni, Old Computer, Mouse and Keyboard Low Poly by lucasalic00, Simple Stack Of Books (Game Assets) by Skyler, Coffee Mug (School Project) by Ole Gunnar Isager, Radiator by KurtSteiner, Water Cooler by Glitching Light, CC0 - Pencil Holder by plaggy, Small Officer Desk Printer by Replexx, Carton of Milk 4K PBR by GooPy, Free Pack - Cobwebs by PolyOne Studio, Low-poly Duffel Bag by Station_09_studios, Paper Towel Dispenser by Carolyn Wong, Dirty Crumpled Pieces of Paper - 6 Piece Set by Sunbox Games, Tissue Box - Household Props Challenge by zhixson, School wall mount speaker by Zixel, Toolbox Photoscan LOWPOLY by EFX, animal company - box fan by Romeo rios vr, Folded Towel by Nicothin, First Person hands rigged by David Fischer, Flashlight Swiss Arms by TheSolomon. Other models from Poly Haven (CC0).
Sound effects from Kenney (kenney.nl, CC0), and made with ElevenLabs.
Fonts from Google Fonts: Bebas Neue by Dharma Type (SIL Open Font License), Special Elite by Astigmatic and Permanent Marker by Font Diner (Apache License 2.0).
Field guide sketches made with SpriteCook and Nano Banana.
Steam features use GodotSteam (MIT licence) and the Steamworks SDK (Valve Corporation)."""

const GODOTSTEAM_LICENSE := """GodotSteam
Copyright (c) 2015-present Gramps and GodotSteam contributors.
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE."""


func _ready() -> void:
	layer = 15
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 1.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(820, 0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	var title := Label.new()
	title.text = "CREDITS"
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	_text(body, CREDITS % ProjectSettings.get_setting("night_shift/credits/author", "Travis700"), 18, 1.0)
	_text(body, "Version %s" % ProjectSettings.get_setting("application/config/version", "dev"), 15, 0.6)
	_text(body, "Licences", 24, 1.0, Color(1.0, 0.9, 0.6))
	_text(body, "Godot Engine\n" + Engine.get_license_text(), 14, 0.8)
	_text(body, GODOTSTEAM_LICENSE, 14, 0.8)
	# Every third-party library inside Godot Engine, with its copyright and licence.
	var licenses := Engine.get_license_info()
	for entry: Dictionary in Engine.get_copyright_info():
		var lines: Array[String] = [str(entry["name"])]
		for part: Dictionary in entry["parts"]:
			for holder in part["copyright"]:
				lines.append("Copyright " + str(holder))
			lines.append("Licence: " + str(part["license"]))
		_text(body, "\n".join(lines), 13, 0.65)
	for license_name: String in licenses:
		_text(body, "%s\n%s" % [license_name, licenses[license_name]], 12, 0.55)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 48)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(close)
	column.add_child(back)


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _text(parent: Control, text: String, size: int, alpha: float, color := Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(780, 0)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.modulate.a = alpha
	parent.add_child(label)
