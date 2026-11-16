class_name WindowMode
extends Node

## Fullscreen or a window on computers (Linux, Windows, macOS), picked in
## Settings. A window's size and place are saved and put back at the next
## start, pulled back onto a screen if the monitor it was on has gone.
##
## The project starts windowed on computers and goes fullscreen a couple of
## frames in. Starting in fullscreen made Windows lay the picture out for a
## window with a title bar before the bar went away, so everything sat about
## 60 px low until the next start.

const FULLSCREEN := "fullscreen"
const WINDOW := "window"
const MODES := {FULLSCREEN: "Fullscreen", WINDOW: "Window"}
const DEFAULT_SIZE := Vector2i(1280, 720)
const MIN_SIZE := Vector2i(320, 240)
## Frames to wait before going fullscreen.
const SETTLE_FRAMES := 2
## Seconds the window has to stay put before its place is saved.
const SAVE_AFTER := 0.5

var _last := Rect2i()
var _still := 0.0
var _fullscreen_pending := false


## Whether the Display choice applies: computers with a screen, not phones or the web.
static func available() -> bool:
	return OS.has_feature("pc") and not OS.has_feature("web") and DisplayServer.get_name() != "headless"


## "fullscreen" or "window". The Deck's desktop starts in a window.
static func mode() -> String:
	var fallback := WINDOW if SteamDeck.is_deck() and not SteamDeck.game_mode() else FULLSCREEN
	var pick: String = Game.settings.get_value("display", "window_mode", fallback)
	return pick if MODES.has(pick) else fallback


## The saved window, or an empty rect when there isn't one.
static func saved_rect() -> Rect2i:
	var value: Variant = Game.settings.get_value("display", "window_rect", Rect2i())
	return value if value is Rect2i else Rect2i()


## RECT moved and shrunk to sit on one of SCREENS (usable areas). A window
## that is on none of them goes to the middle of the first.
static func fit_rect(rect: Rect2i, screens: Array) -> Rect2i:
	if screens.is_empty():
		return rect
	var size := Vector2i(maxi(rect.size.x, MIN_SIZE.x), maxi(rect.size.y, MIN_SIZE.y))
	var home: Rect2i = screens[0]
	var best := 0
	for screen: Rect2i in screens:
		var overlap := screen.intersection(Rect2i(rect.position, size))
		if overlap.get_area() > best:
			best = overlap.get_area()
			home = screen
	size = Vector2i(mini(size.x, home.size.x), mini(size.y, home.size.y))
	var position := rect.position
	if best == 0:
		position = home.position + (home.size - size) / 2
	position.x = clampi(position.x, home.position.x, home.end.x - size.x)
	position.y = clampi(position.y, home.position.y, home.end.y - size.y)
	return Rect2i(position, size)


func _ready() -> void:
	set_process(false)
	if available():
		apply()


## Puts the window the way Settings says. Fullscreen waits a few frames at
## the start; a change from Settings goes straight away.
func apply(soon := true) -> void:
	if not available():
		return
	var window := get_window()
	if SteamDeck.game_mode() or mode() == FULLSCREEN:
		if _fullscreen_pending:
			return
		set_process(false)
		if soon and Engine.get_process_frames() < 30:
			_fullscreen_pending = true
			for i in SETTLE_FRAMES:
				await get_tree().process_frame
			_fullscreen_pending = false
			if not (SteamDeck.game_mode() or mode() == FULLSCREEN):
				return
		window.mode = Window.MODE_FULLSCREEN
		return
	_fullscreen_pending = false
	if window.mode != Window.MODE_WINDOWED:
		window.mode = Window.MODE_WINDOWED
	window.unresizable = false
	window.borderless = false
	var rect := saved_rect()
	if rect.size == Vector2i.ZERO:
		var screen := DisplayServer.screen_get_usable_rect(window.current_screen)
		var size := default_size()
		rect = Rect2i(screen.position + (screen.size - size) / 2, size)
	rect = fit_rect(rect, _screens())
	window.size = rect.size
	window.position = rect.position
	_last = Rect2i(window.position, window.size)
	_still = 0.0
	set_process(true)


static func default_size() -> Vector2i:
	return SteamDeck.DECK_SCREEN if SteamDeck.is_deck() else DEFAULT_SIZE


func set_mode(pick: String) -> void:
	if not MODES.has(pick):
		return
	Game.set_setting("display", "window_mode", pick)
	apply(false)


func _screens() -> Array:
	var out := []
	for i in DisplayServer.get_screen_count():
		out.append(DisplayServer.screen_get_usable_rect(i))
	return out


## While in a window, saves its size and place once they've stopped changing.
func _process(delta: float) -> void:
	var window := get_window()
	if window.mode != Window.MODE_WINDOWED:
		return
	var now := Rect2i(window.position, window.size)
	if now != _last:
		_last = now
		_still = 0.0
		return
	if _still < 0.0:
		return
	_still += delta
	if _still >= SAVE_AFTER:
		_still = -1.0
		if saved_rect() != now:
			Game.set_setting("display", "window_rect", now)
