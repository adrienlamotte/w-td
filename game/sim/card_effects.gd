class_name CardEffects
extends RefCounted
## Applies one card effect object (10_M3_CONTENT.md 2.5) to the world (D-147 rule 6).


static func apply(w: SimWorld, e: Dictionary) -> void:
	match String(e.stat):
		"gold":  # instant (card_purse)
			w.gold += int(e.value)
		"unlock_tower":
			var type := w.tower_catalog.type_of(String(e.target).trim_prefix("tower:"))
			if type >= 0 and not w.tower_types.has(type):
				w.tower_types.append(type)
		_:  # stored unfiltered (D-144); read by the tower stats, the run caches, skills and 045
			w.add_modifier(e.stat, SimModifiers.Op.MULT if e.op == "mult" else SimModifiers.Op.ADD, e.value, e.target)
