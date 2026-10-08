class_name PlaceholderArt
extends RefCounted
## Procedural placeholder sprites, generated at runtime, never saved (D-087).
## Bottom-centre pivot: feet on the bottom edge of the cell; facing right.


static func type_color(type_id: int) -> Color:
	return Color.from_hsv(fmod(type_id * 0.618, 1.0), 0.6, 0.95)


## One horizontal strip of `frames` cells of `cell` px: a bobbing body, alternating
## feet and an eye on the right side (so facing and flip are visible).
static func enemy_strip(color: Color, frames: int, cell: int) -> Image:
	var img := Image.create_empty(frames * cell, cell, false, Image.FORMAT_RGBA8)
	var r := cell * 0.3
	for f in frames:
		var ox := f * cell
		var phase := TAU * f / frames
		var bob := absf(sin(phase)) * cell * 0.06
		var cy := cell - r - cell * 0.12 - bob
		_disc(img, ox + cell * 0.5, cy, r, color)
		_disc(img, ox + cell * 0.62, cy - r * 0.25, r * 0.22, Color.WHITE)
		_disc(img, ox + cell * 0.66, cy - r * 0.25, r * 0.1, Color.BLACK)
		var step := sin(phase) * cell * 0.08
		var foot := color.darkened(0.4)
		_disc(img, ox + cell * 0.38 + step, cell - cell * 0.07, cell * 0.07, foot)
		_disc(img, ox + cell * 0.62 - step, cell - cell * 0.07, cell * 0.07, foot)
	return img


## A single taller shape (body + head), `cell` px wide and tall.
static func tower_image(color: Color, cell: int) -> Image:
	var img := Image.create_empty(cell, cell, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(int(cell * 0.3), int(cell * 0.4), int(cell * 0.4), int(cell * 0.6)), color)
	_disc(img, cell * 0.5, cell * 0.25, cell * 0.18, color.lightened(0.3))
	return img


static func _disc(img: Image, cx: float, cy: float, r: float, color: Color) -> void:
	for y in range(maxi(0, floori(cy - r)), mini(img.get_height(), ceili(cy + r) + 1)):
		for x in range(maxi(0, floori(cx - r)), mini(img.get_width(), ceili(cx + r) + 1)):
			if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
				img.set_pixel(x, y, color)
