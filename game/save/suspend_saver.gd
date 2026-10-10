class_name SuspendSaver
extends RefCounted
## Writes the suspend save at card and wave boundaries (D-167 rule 2). Installed only by
## game_view in demo mode: never by the bench or the balance bot.

var dir: String
## A boundary was seen and its save is not written yet.
var pending: bool = false


func _init(p_dir := "user://") -> void:
	dir = p_dir


## After every step: a draft opened or a wave started marks a save pending; it is written at
## the first RUNNING step with a settled flow field (a rebuilt field equals the live one only then).
func on_step(w: SimWorld) -> void:
	if w.run_state != SimWorld.RunState.RUNNING:
		return
	var ev := w.events
	for e in ev.count:
		var k := ev.kind[e]
		if k == SimEvents.Kind.WAVE_STARTED or (w.draft.drafting
				and (k == SimEvents.Kind.LEVEL_UP or k == SimEvents.Kind.CARD_PICKED)):
			pending = true
			break
	if pending and w.field != null and w.field.settled():
		pending = false
		# ponytail: synchronous write on the main thread; move the stringify and write to a
		# WorkerThreadPool task (dict captured here) if 043 shows a wave-start hitch.
		SuspendStore.save(w, dir)
