class_name StopwatchModuleData
extends Resource
## Base description for any stopwatch power. Borrow Time is the first module;
## future modules subclass this so unlocks can swap the starting module
## without the player controller caring which one is equipped.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
