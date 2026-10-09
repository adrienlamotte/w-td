class_name PlaceholderArt
extends RefCounted
## Procedural placeholder sprites, generated at runtime, never saved (D-087).
## Bottom-centre pivot: feet on the bottom edge of the cell; facing right.


## One horizontal strip of `frames` cells of `cell` px: a bobbing body, alternating
## feet and an eye on the right side (so facing and flip are visible).
## shape (D-120): blob, brute (wide square body), ranged (blob + staff), crown (blob + crown).
static func enemy_strip(color: Color, frames: int, cell: int, shape: String = "blob") -> Image:
	var img := Image.create_empty(frames * cell, cell, false, Image.FORMAT_RGBA8)
	var r := cell * 0.3
	for f in frames:
		var ox := f * cell
		var phase := TAU * f / frames
		var bob := absf(sin(phase)) * cell * 0.06
		var cy := cell - r - cell * 0.12 - bob
		if shape == "brute":
			img.fill_rect(Rect2i(ox + int(cell * 0.12), int(cy - r), int(cell * 0.76), int(r * 2.0)), color)
		else:
			_disc(img, ox + cell * 0.5, cy, r, color)
		if shape == "ranged":
			img.fill_rect(Rect2i(ox + int(cell * 0.12), int(cy - r * 1.4), int(cell * 0.06), int(r * 2.4)), color.darkened(0.5))
			_disc(img, ox + cell * 0.15, cy - r * 1.4, cell * 0.07, Color.WHITE)
		elif shape == "crown":
			var top := int(cy - r * 0.95)
			img.fill_rect(Rect2i(ox + int(cell * 0.34), top - int(cell * 0.06), int(cell * 0.32), int(cell * 0.08)), Color.GOLD)
			for k in 3:
				img.fill_rect(Rect2i(ox + int(cell * (0.34 + 0.13 * k)), top - int(cell * 0.14), int(cell * 0.06), int(cell * 0.1)), Color.GOLD)
		_disc(img, ox + cell * 0.62, cy - r * 0.25, r * 0.22, Color.WHITE)
		_disc(img, ox + cell * 0.66, cy - r * 0.25, r * 0.1, Color.BLACK)
		var step := sin(phase) * cell * 0.08
		var foot := color.darkened(0.4)
		_disc(img, ox + cell * 0.38 + step, cell - cell * 0.07, cell * 0.07, foot)
		_disc(img, ox + cell * 0.62 - step, cell - cell * 0.07, cell * 0.07, foot)
	return img


## A single shape `cell` px wide and tall. shape (D-120): bare (body + head), single (tall),
## splash (wide), slow (orb on top), husk (low broken block).
static func tower_image(color: Color, cell: int, shape: String = "bare") -> Image:
	var img := Image.create_empty(cell, cell, false, Image.FORMAT_RGBA8)
	match shape:
		"single":
			img.fill_rect(Rect2i(int(cell * 0.38), int(cell * 0.2), int(cell * 0.24), int(cell * 0.8)), color)
			_disc(img, cell * 0.5, cell * 0.15, cell * 0.12, color.lightened(0.3))
		"splash":
			img.fill_rect(Rect2i(int(cell * 0.15), int(cell * 0.55), int(cell * 0.7), int(cell * 0.45)), color)
			_disc(img, cell * 0.5, cell * 0.5, cell * 0.24, color.lightened(0.3))
		"slow":
			img.fill_rect(Rect2i(int(cell * 0.32), int(cell * 0.45), int(cell * 0.36), int(cell * 0.55)), color.darkened(0.3))
			_disc(img, cell * 0.5, cell * 0.28, cell * 0.2, color.lightened(0.4))
		"husk":
			img.fill_rect(Rect2i(int(cell * 0.2), int(cell * 0.7), int(cell * 0.6), int(cell * 0.3)), color)
			img.fill_rect(Rect2i(int(cell * 0.45), int(cell * 0.7), int(cell * 0.1), int(cell * 0.12)), Color.TRANSPARENT)
		_:
			img.fill_rect(Rect2i(int(cell * 0.3), int(cell * 0.4), int(cell * 0.4), int(cell * 0.6)), color)
			_disc(img, cell * 0.5, cell * 0.25, cell * 0.18, color.lightened(0.3))
	return img


static func _disc(img: Image, cx: float, cy: float, r: float, color: Color) -> void:
	for y in range(maxi(0, floori(cy - r)), mini(img.get_height(), ceili(cy + r) + 1)):
		for x in range(maxi(0, floori(cx - r)), mini(img.get_width(), ceili(cx + r) + 1)):
			if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
				img.set_pixel(x, y, color)
