class_name LobbyCard
extends MenuCard

## One place in an online race, on the lobby: a racer with their driver's
## picture, name, driver and kart, an AI driver, or a place left open. A
## racer on this phone gets a stripe and a tag in their colour.

## What it shows now, so it's only built again when that changes.
var _shown := {}
var _picture: TextureRect
var _driver: Label
var _person: Control


## A racer. `player` is 1 or 2 for one on this phone, 0 for anyone else.
## `ready` puts a Ready tag on someone else's card.
func show_racer(who: String, design: CharacterDesign, kart: String, player: int, ready: bool) -> void:
	var wanted := {"who": who, "driver": design.to_dict(), "kart": kart, "player": player, "ready": ready}
	if wanted == _shown:
		return
	_shown = wanted
	_clear()
	modulate = Color.WHITE
	content.alignment = BoxContainer.ALIGNMENT_BEGIN
	set_stripe(UiKit.PLAYERS[player - 1] if player > 0 else Color.TRANSPARENT)
	if player > 0 or ready:
		var tag := MenuStyle.tag("P%d" % player if player > 0 else "Ready", UiKit.PLAYERS[player - 1] if player > 0 else UiKit.GREEN, 22 if player > 0 else 18)
		tag.size_flags_horizontal = SIZE_SHRINK_END
		content.add_child(tag)
	else:
		var room := Control.new()
		room.custom_minimum_size.y = 34
		room.mouse_filter = MOUSE_FILTER_IGNORE
		content.add_child(room)
	_picture = picture(null, 60)
	_picture.size_flags_vertical = SIZE_EXPAND_FILL
	_one_line(line(who))
	_driver = line("", false)
	_driver.theme_type_variation = "LeadLabel"
	_driver.add_theme_font_size_override("font_size", 20)
	_one_line(_driver)
	_one_line(line(kart, false))
	show_driver(design)


## Changes the driver on a racer's card.
func show_driver(design: CharacterDesign) -> void:
	if _driver == null:
		return
	_shown["driver"] = design.to_dict()
	_driver.text = design.name
	_picture.texture = DriverPortraits.picture(design)
	_picture.set_meta("look", DriverPortraits.key_of(design))


## The driver's picture, when it's been taken.
func show_portrait(look: String, texture: Texture2D) -> void:
	if _picture != null and _picture.get_meta("look", "") == look:
		_picture.texture = texture


## Whether this card is waiting for its driver's picture.
func wants_portrait() -> bool:
	return _picture != null and _picture.texture == null


## An AI driver at this level, dimmed.
func show_ai(level: String) -> void:
	var wanted := {"ai": level}
	if wanted == _shown:
		return
	_shown = wanted
	_clear()
	set_stripe(Color.TRANSPARENT)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	_person = Person.new()
	content.add_child(_person)
	line("AI")
	line(Difficulty.name_of(level), false)
	modulate = Color(1, 1, 1, 0.45)


## A place nobody's in yet.
func show_open() -> void:
	var wanted := {"open": true}
	if wanted == _shown:
		return
	_shown = wanted
	_clear()
	set_stripe(Color.TRANSPARENT)
	modulate = Color.WHITE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	plus()
	line("Open")
	line("Waiting for someone", false)


## The words on the card, all of them, for tests.
func words() -> String:
	var out: PackedStringArray = []
	for child in content.get_children():
		if child is Label:
			out.append(child.text)
	return "\n".join(out)


func _clear() -> void:
	_title = null
	_picture = null
	_driver = null
	_person = null
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()


## Keeps a name on one line, cut short with dots if the card's narrow.
func _one_line(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size.x = 40.0


## A grey person, for an AI place.
class Person extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(0, 90)
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		UiKit.draw_icon(self, "person", size * 0.5, 64.0, UiKit.FADED)
