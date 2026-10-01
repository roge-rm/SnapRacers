class_name CupBuilder
extends Control

## Make a Grand Prix cup of your own or change one, with a name and its races
## in order, from the game's courses and the ones you've built.

var path := ""
var cup: CupDesign
var _name: LineEdit
var _list: VBoxContainer
var _problem: Label
var _save: Button
var _delete_dialog: ConfirmationDialog


func _init(from := "") -> void:
	path = from


func _ready() -> void:
	cup = CupDesign.load_file(path) if path != "" else null
	if cup == null:
		cup = CupDesign.new()
		cup.made_by = Game.player_name()
		path = ""
	var column := MenuStyle.page(self, "Change a cup" if path != "" else "Make a cup", go_back, 760.0)

	column.add_child(MenuStyle.heading("Name"))
	_name = LineEdit.new()
	_name.max_length = 32
	_name.text = cup.name
	_name.text_changed.connect(func(text: String) -> void:
		cup.name = text.strip_edges()
		_show())
	column.add_child(_name)

	column.add_child(MenuStyle.heading("Races", "%d to %d, raced in order" % [CupDesign.FEWEST, CupDesign.MOST]))
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	column.add_child(_list)
	_problem = Label.new()
	_problem.add_theme_color_override("font_color", BuilderStyle.DANGER)
	_problem.add_theme_font_size_override("font_size", 18)
	column.add_child(_problem)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	_save = MenuStyle.button("Save the cup", save)
	_save.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(_save)
	if path != "":
		row.add_child(MenuStyle.link("Delete it", func() -> void: _delete_dialog.popup_centered()))

	column.add_child(MenuStyle.heading("Add a race"))
	for game_cup in GrandPrix.cups():
		for id in game_cup.tracks:
			column.add_child(_course_button(Tracks.path_of(id)))
	var yours := CourseDesign.saved().filter(func(p): return CourseDesign.load_file(p) != null and CourseDesign.load_file(p).problems().is_empty())
	if not yours.is_empty():
		column.add_child(MenuStyle.heading("Your courses"))
		for p in yours:
			column.add_child(_course_button(p))
	MenuStyle.back_at_bottom(column, go_back)

	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.theme = MenuStyle.theme()
	_delete_dialog.title = "Delete this cup?"
	_delete_dialog.dialog_text = "The courses in it stay where they are."
	_delete_dialog.ok_button_text = "Delete"
	_delete_dialog.confirmed.connect(func() -> void:
		DirAccess.remove_absolute(path)
		Game.show_your_cups())
	add_child(_delete_dialog)
	_show()


func _course_button(course_path: String) -> Button:
	var track := TrackPath.load_file(course_path)
	var button := MenuStyle.button(track.name, func() -> void:
		if cup.add(course_path):
			_show()
		else:
			Sounds.play("fx/nope"), CourseOutline.describe(track))
	button.custom_minimum_size.y = 76.0
	button.set_meta("track", course_path)
	return button


## The races so far and whether it can be saved.
func _show() -> void:
	for child in _list.get_children():
		child.queue_free()
	for i in cup.races.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var label := Label.new()
		label.text = "%d.  %s" % [i + 1, cup.course_names()[i]]
		label.add_theme_font_size_override("font_size", 22)
		label.size_flags_horizontal = SIZE_EXPAND_FILL
		row.add_child(label)
		if i > 0:
			row.add_child(MenuStyle.link("Earlier", func() -> void:
				var race = cup.races.pop_at(i)
				cup.races.insert(i - 1, race)
				_show()))
		row.add_child(MenuStyle.link("Take out", func() -> void:
			cup.races.remove_at(i)
			_show()))
		_list.add_child(row)
	var problem := cup.problem()
	if problem == "" and cup.name == "":
		problem = "It needs a name."
	_problem.text = problem
	_problem.visible = problem != ""
	_save.disabled = problem != ""


func save() -> void:
	if cup.problem() != "" or cup.name == "":
		return
	var old := path
	path = cup.save()
	# When it's renamed the old file goes, so there aren't two.
	if old != "" and old != path:
		DirAccess.remove_absolute(old)
	Game.show_your_cups()


func go_back() -> void:
	Game.show_your_cups()
