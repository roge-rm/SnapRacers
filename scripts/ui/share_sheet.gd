class_name ShareSheet
extends RefCounted

## Sending text and files to other apps, and opening a file from somewhere
## else, however this device does it. On a phone it's Android's share sheet
## and file picker (through the game's plugin, see NetPlugin), on the web
## it's a download and the browser's file picker, and on a computer it's the
## clipboard and the system's file windows.

## The most of a file that's read, so a huge one can't fill memory.
const MOST_BYTES := 1 << 20

## Kept so the browser can still call back once a file is picked.
static var _web_picked = null


## Whether text goes to another app here, or only to the clipboard.
static func can_send_text() -> bool:
	return Game.plugin.has()


## Sends text to another app, or copies it where there's no way to send it.
## Returns what to tell the player.
static func send_text(text: String, title: String) -> String:
	if Game.plugin.has():
		Game.plugin.android.share_text(text, title)
		return ""
	DisplayServer.clipboard_set(text)
	return "Copied"


static func copy(text: String) -> String:
	DisplayServer.clipboard_set(text)
	return "Copied"


## Sends a file to another app (a phone), downloads it (the web) or saves it
## where the player picks (a computer). Returns what to tell the player.
static func send_file(file_name: String, contents: String, title: String, parent: Node) -> String:
	if Game.plugin.has():
		Game.plugin.android.share_file(file_name, contents, title)
		return ""
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(contents.to_utf8_buffer(), file_name, "application/json")
		return "Downloaded"
	var dialog := _dialog(FileDialog.FILE_MODE_SAVE_FILE, parent)
	dialog.current_file = file_name
	dialog.file_selected.connect(func(path: String) -> void:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(contents))
	dialog.popup_centered_ratio(0.7)
	return ""


## Lets the player pick a file, and calls back with what's in it, or with ""
## and why not.
static func open_file(parent: Node, done: Callable) -> void:
	if Game.plugin.has():
		# The window that asked may have gone by the time the picker's done.
		var once := func(text: String, why: String) -> void:
			if done.is_valid():
				done.call(text, why)
		Game.plugin.picked.connect(once, CONNECT_ONE_SHOT)
		Game.plugin.android.pick_file()
		return
	if OS.has_feature("web"):
		_web_picked = JavaScriptBridge.create_callback(func(args: Array) -> void:
			if done.is_valid():
				done.call(str(args[0]) if not args.is_empty() else "", ""))
		JavaScriptBridge.get_interface("window").snapracersPicked = _web_picked
		JavaScriptBridge.eval("""
			(function () {
				var input = document.createElement('input');
				input.type = 'file';
				input.accept = '.json,application/json,text/plain';
				input.onchange = function () {
					var file = input.files[0];
					if (file && file.size <= %d) { file.text().then(function (t) { window.snapracersPicked(t); }); }
					else if (file) { window.snapracersPicked(''); }
				};
				input.click();
			})();
		""" % MOST_BYTES)
		return
	var dialog := _dialog(FileDialog.FILE_MODE_OPEN_FILE, parent)
	dialog.file_selected.connect(func(path: String) -> void:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > MOST_BYTES:
			done.call("", "I couldn't open that file.")
		else:
			done.call(file.get_as_text(), ""))
	dialog.popup_centered_ratio(0.7)


static func _dialog(mode: FileDialog.FileMode, parent: Node) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.json ; Courses and cups"])
	dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	parent.add_child(dialog)
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free.call_deferred())
	return dialog
