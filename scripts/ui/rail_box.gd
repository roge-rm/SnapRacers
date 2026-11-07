class_name RailBox
extends VBoxContainer

## The column of tabs down a drawer's left side. The drawer's backing draws a
## darker band behind it (see BuilderStyle.dress_drawer()), and this draws
## the tab that's on as a yellow block across the whole band, joined to a
## thin yellow line along the band's inner side. A gap SafeArea leaves for a camera hole gets a
## thin line across the band.

## The drawer it's in, whose backing has the band.
var drawer: Control


func _ready() -> void:
	sort_children.connect(queue_redraw)
	item_rect_changed.connect(queue_redraw)
	if drawer != null:
		drawer.resized.connect(queue_redraw)
		drawer.item_rect_changed.connect(queue_redraw)


## The lower half's first tab, if both end-aligned groups clear the cutouts.
func cutout_split(holes: Array[Rect2]) -> Control:
	var tabs: Array[Control] = []
	for child in get_children():
		if child is IconButton and child.visible:
			tabs.append(child)
	if tabs.size() < 2:
		return null
	var rect := get_global_rect()
	var touches := false
	for hole in holes:
		touches = touches or rect.intersects(hole)
	if not touches:
		return null
	var split := ceili(tabs.size() * 0.5)
	var between := float(get_theme_constant("separation"))
	var heights: Array[float] = [0.0, 0.0]
	for i in tabs.size():
		heights[0 if i < split else 1] += tabs[i].get_combined_minimum_size().y
	heights[0] += between * (split - 1)
	heights[1] += between * (tabs.size() - split - 1)
	if heights[0] + heights[1] + between * 2.0 > size.y:
		return null
	var along := rect.position.y
	for i in tabs.size():
		if i == split:
			along = rect.end.y - heights[1]
		var tab := Rect2(Vector2(tabs[i].global_position.x, along), Vector2(tabs[i].size.x, tabs[i].get_combined_minimum_size().y))
		for hole in holes:
			if tab.intersects(hole):
				return null
		along = tab.end.y + between
	return tabs[split]


func _draw() -> void:
	if drawer == null:
		return
	var box := drawer.get_theme_stylebox("panel") as SlantBox
	if box == null:
		return
	var offset := global_position - drawer.global_position
	# A thin accent line down the band's inner side, which the block for the
	# tab that's on runs into, like a tab joined to its page.
	var edge_top := box.left_at(drawer.size, offset.y) - offset.x + box.band_width
	var edge_bottom := box.left_at(drawer.size, offset.y + size.y) - offset.x + box.band_width
	draw_line(Vector2(edge_top - 1.0, 0.0), Vector2(edge_bottom - 1.0, size.y), Color(UiKit.ACCENT, 0.7), 2.0, true)
	for child in get_children():
		var control := child as Control
		if control == null or not control.visible:
			continue
		var top := control.position.y
		var bottom := top + control.size.y
		var tab := control as IconButton
		if tab != null:
			tab.rail_lean = box.tilt_for(drawer.size.y)
			if not tab.on:
				continue
			var left_top := box.left_at(drawer.size, top + offset.y) - offset.x
			var left_bottom := box.left_at(drawer.size, bottom + offset.y) - offset.x
			draw_colored_polygon(PackedVector2Array([
				Vector2(left_top, top),
				Vector2(left_top + box.band_width, top),
				Vector2(left_bottom + box.band_width, bottom),
				Vector2(left_bottom, bottom),
			]), UiKit.ACCENT)
		elif control.size.y > 0.0:
			var middle := (top + bottom) * 0.5
			var left := box.left_at(drawer.size, middle + offset.y) - offset.x
			draw_line(Vector2(left + 8.0, middle), Vector2(left + box.band_width - 8.0, middle), BuilderStyle.DIVIDER, 2.0)
