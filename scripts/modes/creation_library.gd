class_name CreationLibrary
extends RefCounted

## Saved creations only. Results contain why on failure and path on success.
## Reading keeps the original data, so names can change without losing fields.

const COPY_NAME_LENGTH := 32


static func entries(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not kind in Sharing.KINDS or _folder_problem(kind) != "":
		return out
	for path in Sharing.saved_paths(kind):
		var found := read(kind, path)
		var entry := {"kind": kind, "path": path, "name": path.get_file().get_basename(), "readable": not found.has("why"), "problem": str(found.get("why", ""))}
		if not found.has("why"):
			entry.name = found.name
			entry["data"] = found.data
		out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var order := str(a.name).to_lower().casecmp_to(str(b.name).to_lower())
		return a.path < b.path if order == 0 else order < 0)
	return out


## Returns {kind, path, name, data}, or {why}. Empty drafts are readable.
static func read(kind: String, path: String) -> Dictionary:
	var problem := _path_problem(kind, path)
	if problem != "":
		return {"why": problem}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"why": "I couldn't read that file (%s)." % error_string(FileAccess.get_open_error())}
	var text := file.get_as_text()
	var error := file.get_error()
	file.close()
	if error != OK:
		return {"why": "I couldn't read that file (%s)." % error_string(error)}
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {"why": "That file isn't a saved creation."}
	var data: Dictionary = json.data
	if Sharing.kind_of(data) != kind or Sharing.data_of(data) != data:
		return {"why": "That file isn't a saved %s." % _noun(kind)}
	var checked := Sharing.validate_saved(kind, data)
	if checked.has("why"):
		return {"why": str(checked.why)}
	var name: String = str(data.get("name", "")).strip_edges()
	return {"kind": kind, "path": path, "name": name if name != "" else path.get_file().get_basename(), "data": data}


## Returns {path, name}, or {why}. Only the top-level name changes.
static func rename(kind: String, path: String, new_name: String) -> Dictionary:
	var found := read(kind, path)
	if found.has("why"):
		return found
	var name := new_name.strip_edges()
	if name == "" or name.length() > Sharing.MOST_NAME or name.contains("\n") or name.contains("\r") or name.contains("\t"):
		return {"why": "Use a name from 1 to %d characters on one line." % Sharing.MOST_NAME}
	var target := Sharing.path_for(kind, name)
	var problem := _path_problem(kind, target)
	if problem != "":
		return {"why": problem}
	if _collision(kind, path, target, name):
		return {"why": "You've already got a %s with that name." % _noun(kind)}
	var data: Dictionary = found.data.duplicate(true)
	data.name = name
	var directory := DirAccess.open(path.get_base_dir())
	if directory == null:
		return {"why": "I couldn't open that folder."}
	# A private directory keeps the temporary file away from library scans.
	var scratch := ".rename_%s_%s" % [Time.get_ticks_usec(), randi()]
	var error := directory.make_dir(scratch)
	if error != OK:
		return {"why": "I couldn't save that name (%s)." % error_string(error)}
	var temp := path.get_base_dir().path_join(scratch).path_join("design.json")
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		directory.remove(scratch)
		return {"why": "I couldn't save that name (%s)." % error_string(FileAccess.get_open_error())}
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error == OK:
		problem = _path_problem(kind, path)
		if problem == "":
			problem = _path_problem(kind, target)
		if problem != "" or _collision(kind, path, target, name):
			error = ERR_ALREADY_EXISTS
		else:
			error = DirAccess.rename_absolute(temp, target)
	if error != OK:
		DirAccess.remove_absolute(temp)
		directory.remove(scratch)
		return {"why": "I couldn't save that name (%s)." % error_string(error)}
	directory.remove(scratch)
	if target != path:
		error = DirAccess.remove_absolute(path)
		if error != OK:
			var rollback := DirAccess.remove_absolute(target)
			return {"why": "I couldn't remove the old file (%s).%s" % [error_string(error), " The new copy couldn't be removed either." if rollback != OK else ""]}
	return {"path": target, "name": name}


## Proposes a free display name and filename within the editor's name limit.
static func copy_name(kind: String, path: String) -> Dictionary:
	var found := read(kind, path)
	if found.has("why"):
		return found
	var base: String = found.name.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges()
	var number := 1
	while true:
		var suffix := " copy" if number == 1 else " copy %d" % number
		var name := base.left(COPY_NAME_LENGTH - suffix.length()).strip_edges() + suffix
		if not _collision(kind, "", Sharing.path_for(kind, name), name):
			return {"name": name}
		number += 1
	return {}


## Writes an independent saved copy, changing only its top-level name.
static func duplicate_creation(kind: String, path: String, new_name: String) -> Dictionary:
	var found := read(kind, path)
	if found.has("why"):
		return found
	var name := new_name.strip_edges()
	if name == "" or name.length() > COPY_NAME_LENGTH or name.contains("\n") or name.contains("\r") or name.contains("\t"):
		return {"why": "Use a name from 1 to %d characters on one line." % COPY_NAME_LENGTH}
	var target := Sharing.path_for(kind, name)
	if _collision(kind, "", target, name):
		return {"why": "You've already got a %s with that name." % _noun(kind)}
	var data: Dictionary = found.data.duplicate(true)
	data.name = name
	var saved := save(kind, target, data)
	if not saved.has("why"):
		saved["name"] = name
	return saved


## Corrupt files can be deleted. Current editor drafts and cup copies stay as is.
static func delete(kind: String, path: String) -> Dictionary:
	var problem := _path_problem(kind, path)
	if problem != "":
		return {"why": problem}
	if not FileAccess.file_exists(path):
		return {"why": "That file is no longer there."}
	var error := DirAccess.remove_absolute(path)
	if error != OK:
		return {"why": "I couldn't delete that file (%s)." % error_string(error)}
	return {"path": path}


## Returns {path, envelope}, or {why}. Sharing still applies its own checks.
static func envelope(kind: String, path: String) -> Dictionary:
	var found := read(kind, path)
	if found.has("why"):
		return found
	var payload := Sharing.envelope_for(kind, found.data)
	var checked := Sharing.read(JSON.stringify(payload))
	if checked.has("why"):
		return checked
	return {"path": path, "envelope": Sharing.envelope_for(kind, checked.data)}


## Replaces only a selected saved identity; new names cannot overwrite a file.
static func save(kind: String, path: String, data: Dictionary, replace_existing := false) -> Dictionary:
	var problem := _path_problem(kind, path)
	if problem != "":
		return {"why": problem}
	if Sharing.kind_of(data) != kind:
		return {"why": "That isn't a saved %s." % _noun(kind)}
	var checked := Sharing.validate_saved(kind, data)
	if checked.has("why"):
		return checked
	if FileAccess.file_exists(path) and not replace_existing:
		return {"why": "You've already got a %s with that name." % _noun(kind)}
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return {"why": "I couldn't open that folder (%s)." % error_string(error)}
	var scratch := path.get_base_dir().path_join(".save_%s_%s" % [Time.get_ticks_usec(), randi()])
	error = DirAccess.make_dir_absolute(scratch)
	if error != OK:
		return {"why": "I couldn't save that creation (%s)." % error_string(error)}
	var temp := scratch.path_join("design.json")
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		error = FileAccess.get_open_error()
	else:
		file.store_string(JSON.stringify(data, "\t"))
		file.flush()
		error = file.get_error()
		file.close()
	if error == OK:
		if _path_problem(kind, path) != "" or (FileAccess.file_exists(path) and not replace_existing):
			error = ERR_ALREADY_EXISTS
		else:
			error = DirAccess.rename_absolute(temp, path)
	if error != OK:
		DirAccess.remove_absolute(temp)
	DirAccess.remove_absolute(scratch)
	return {"path": path} if error == OK else {"why": "I couldn't save that creation (%s)." % error_string(error)}


static func _noun(kind: String) -> String:
	return "racer" if kind == Sharing.DRIVER else kind


static func _folder(kind: String) -> String:
	return Sharing.path_for(kind, "creation").get_base_dir()


static func _folder_problem(kind: String) -> String:
	if not kind in Sharing.KINDS:
		return "That creation kind isn't supported."
	if _has_link(ProjectSettings.globalize_path(_folder(kind))):
		return "That folder is a link. Open creations from your own library folder."
	return ""


static func _path_problem(kind: String, path: String) -> String:
	var problem := _folder_problem(kind)
	if problem != "":
		return problem
	var folder := _folder(kind)
	var file := path.trim_prefix(folder + "/")
	if not path.begins_with(folder + "/") or file == "" or file.contains("/") or file.contains("\\") or file.contains(":") or file in [".", ".."] or not file.ends_with(".json"):
		return "Choose a JSON file from your own %s folder." % _noun(kind)
	if _has_link(ProjectSettings.globalize_path(path)):
		return "That file is a link. Open creations from your own library folder."
	if DirAccess.dir_exists_absolute(path):
		return "That path is a folder."
	return ""


static func _has_link(path: String) -> bool:
	var current := path
	while current != current.get_base_dir():
		var parent := DirAccess.open(current.get_base_dir())
		if parent != null and parent.is_link(current.get_file()):
			return true
		current = current.get_base_dir()
	return false


static func _collision(kind: String, original: String, target: String, name: String) -> bool:
	if target != original and (FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target)):
		return true
	for other in Sharing.saved_paths(kind):
		if other == original:
			continue
		if other.to_lower() == target.to_lower():
			return true
		var found := read(kind, other)
		if not found.has("why") and (str(found.name).to_lower() == name.to_lower() or Sharing.path_for(kind, found.name).to_lower() == target.to_lower()):
			return true
	return false
