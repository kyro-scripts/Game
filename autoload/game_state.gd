extends Node
## Session-wide state that is not tied to a single run (autoload "GameState").
##
## Holds player settings and developer/debug flags, plus a registry other
## systems use to add buttons to the F1 debug menu without the menu knowing
## about them. Persistence of settings/unlocks arrives in Phase G.

signal settings_changed
signal debug_flags_changed

# --- Settings (implementation defaults) --------------------------------------
## Radians of view rotation per pixel of mouse motion.
var mouse_sensitivity: float = 0.0022
var invert_y: bool = false
## Base camera FOV in degrees (speed adds on top).
var base_fov: float = 96.0
## Viewmodel camera FOV (kept fixed so hands don't warp at speed).
var viewmodel_fov: float = 68.0
## Borrow Time input: hold (default) or toggle.
var borrow_time_toggle_mode: bool = false

# --- Debug flags -------------------------------------------------------------
var god_mode: bool = false
var infinite_timer: bool = false
var show_fps: bool = true
## Prototype default: on, because movement feel is being tuned (Phase A).
var show_speed: bool = true

## Registered debug actions: Array of {section, label, callable}.
var _debug_actions: Array[Dictionary] = []


func set_flag(flag: StringName, value: bool) -> void:
	set(flag, value)
	debug_flags_changed.emit()


func notify_settings_changed() -> void:
	settings_changed.emit()


## Add a button to the debug menu. Re-registering the same section+label
## replaces the previous callable (scenes re-register on reload).
func register_debug_action(section: String, label: String, action: Callable) -> void:
	for entry in _debug_actions:
		if entry["section"] == section and entry["label"] == label:
			entry["callable"] = action
			return
	_debug_actions.append({"section": section, "label": label, "callable": action})


func get_debug_actions() -> Array[Dictionary]:
	# Drop actions whose target object has been freed.
	var alive := _debug_actions.filter(
		func(entry: Dictionary) -> bool: return (entry["callable"] as Callable).is_valid()
	)
	_debug_actions.assign(alive)
	return _debug_actions
