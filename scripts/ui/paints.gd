class_name Paints
extends RefCounted

## The colours the garage and the driver screen share: the More colours grid,
## the Recent list and reading a saved colour. It doesn't use Game, so
## KartDesign and CharacterDesign can use it in tests run with -s.
##
## Karts and drivers save each colour as an HTML code ("#c4281c"), so any
## colour saves, shares and goes online exactly, and older games read it too.

## The More colours grid, a column per hue, light at the top to dark at the
## bottom, with a grey column last. Laid out row by row.
const MORE_COLUMNS := 10
const MORE := [
	"#f4a6a0", "#fbd2a8", "#fbeaa0", "#dcef9c", "#b6e3b9", "#b4e7ea", "#8fd3f4", "#d3c0f0", "#f8d0e4", "#f2f3f2",
	"#e5534b", "#f39a4c", "#f2cd37", "#a5ca18", "#4fb35f", "#36aebf", "#3a8dde", "#9a6fd6", "#d86cb0", "#a3a2a4",
	"#c4281c", "#e36a1a", "#d4a82a", "#7a9a24", "#237841", "#1f7f8c", "#0d69ab", "#6c3fb5", "#b0307e", "#635f61",
	"#7b2e2f", "#8a5a2b", "#8a6d1c", "#4d6118", "#1d4a2b", "#144c55", "#143044", "#3d2266", "#6b1d4c", "#1b1b1b",
]
## How many colours the Recent row keeps.
const RECENT_MOST := 6


## The colour saved as `value`, or `fallback` when it isn't a colour code.
static func read(value: Variant, fallback: Variant = null) -> Variant:
	if value is String and value.length() <= 32 and Color.html_is_valid(value):
		return Color.html(value)
	return fallback


## The code a colour is saved as.
static func code(colour: Color) -> String:
	return "#" + colour.to_html(false)


static func more() -> Array[Color]:
	var out: Array[Color] = []
	for hex in MORE:
		out.append(Color(hex))
	return out


## `recent` with `colour` put first, without it twice, at most RECENT_MOST long.
static func with_recent(recent: Array, colour: Color) -> Array[String]:
	var hex := code(colour)
	var out: Array[String] = [hex]
	for entry in recent:
		if out.size() >= RECENT_MOST:
			break
		var known: Variant = read(entry)
		if known != null and code(known) != hex and not code(known) in out:
			out.append(code(known))
	return out

