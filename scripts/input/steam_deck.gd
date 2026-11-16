class_name SteamDeck
extends RefCounted

## Tells whether the game's on a Steam Deck, and whether it's in SteamOS's
## Game Mode, and sizes the window to match: full screen in Game Mode, and a
## 1280x800 window, the Deck's own screen size, on the Deck's desktop.
##
## SNAPRACERS_DECK=1 and SNAPRACERS_GAMEMODE=1 pretend on another computer,
## and =0 turns either off.

## The Deck's product names in its firmware: Jupiter for the LCD one,
## Galileo for the OLED one.
const PRODUCTS := ["Jupiter", "Galileo"]
const DECK_SCREEN := Vector2i(1280, 800)


static func is_deck() -> bool:
	var fake := OS.get_environment("SNAPRACERS_DECK")
	if fake != "":
		return fake == "1"
	if OS.get_name() != "Linux":
		return false
	return deck_from(_read("/sys/class/dmi/id/sys_vendor"), _read("/sys/class/dmi/id/product_name"), OS.get_environment("SteamDeck"))


static func game_mode() -> bool:
	var fake := OS.get_environment("SNAPRACERS_GAMEMODE")
	if fake != "":
		return fake == "1"
	var env := {}
	for name in ["XDG_CURRENT_DESKTOP", "GAMESCOPE_WAYLAND_DISPLAY", "SteamGamepadUI"]:
		env[name] = OS.get_environment(name)
	return game_mode_from(env)


## Whether the firmware's vendor and product names are a Deck's, or Steam's
## SteamDeck variable says so. Steam sets that to 1 for what it starts on a
## Deck, in Game Mode or on the desktop.
static func deck_from(vendor: String, product: String, steam_deck := "") -> bool:
	return (vendor.strip_edges() == "Valve" and PRODUCTS.has(product.strip_edges())) or steam_deck == "1"


## Whether these environment variables mean Game Mode: gamescope is Game
## Mode's compositor, and Steam sets SteamGamepadUI for what it starts from
## its big screen view.
static func game_mode_from(env: Dictionary) -> bool:
	var ui: String = env.get("SteamGamepadUI", "")
	return env.get("XDG_CURRENT_DESKTOP", "") == "gamescope" or env.get("GAMESCOPE_WAYLAND_DISPLAY", "") != "" or (ui != "" and ui != "0")


static func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
