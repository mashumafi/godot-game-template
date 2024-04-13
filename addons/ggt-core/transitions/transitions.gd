# Transitions.
# You can tweak transition speed and appearance, just make sure to
# update `is_displayed`.
extends CanvasLayer

signal progress_bar_filled
signal transition_started(anim_name: String)
signal transition_finished(anim_name: String)
signal transition_covered_screen


@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var progress: Control = $ColorRect/MarginContainer/Progress

var target_progress: float = 0.0
var config := preload("res://addons/ggt-core/config.tres")


func _ready():
	set_process(false)


# Tells if transition is currently displayed/active
func is_displayed() -> bool:
	var is_screen_black = $ColorRect.modulate.a == 1
	return anim.is_playing() or is_screen_black


func is_transition_in_playing():
	return anim.current_animation == "transition-in" and anim.is_playing()


# appear
func fade_in(params := {}):
	progress.hide()
	if params.get("show_progress_bar") == true:
		progress.show()
	anim.play("transition-in")


# disappear
func fade_out():
	if progress.visible and not progress.is_completed():
		await self.progress_bar_filled
	anim.animation_finished.connect(_on_fade_out_finished, CONNECT_ONE_SHOT)
	anim.play("transition-out")


func _on_fade_out_finished(cur_anim: String):
	if cur_anim == "transition-out":
		progress.bar.value = 0


# progress_ratio: value between 0 and 1
func _update_progress_bar(progress_ratio: float):
	set_process(true)
	target_progress = progress_ratio


func _process(delta: float):
	progress.bar.value = move_toward(progress.bar.value, target_progress, delta)
	if target_progress > 0.0 and is_equal_approx(progress.bar.value, target_progress):
		await get_tree().create_timer(.4).timeout
		progress_bar_filled.emit()
		set_process(false)


# called by the scene loader
func _on_resource_stage_loaded(progress_percentage: float):
	if progress.visible:
		_update_progress_bar(progress_percentage)


func _on_AnimationPlayer_animation_finished(anim_name: String):
	if anim_name == "transition-out":
		transition_finished.emit(anim_name)
		if config.pause_scenes_on_transitions:
			get_tree().paused = false
	elif anim_name == "transition-in":
		transition_covered_screen.emit()


func _on_AnimationPlayer_animation_started(anim_name: String):
	if anim_name == "transition-in":
		transition_started.emit(anim_name)
		if config.pause_scenes_on_transitions:
			get_tree().paused = true


# Prevents all inputs while a graphic transition is playing.
func _input(_event: InputEvent):
	if config.prevent_input_on_transitions and is_displayed():
		# prevent all input events
		get_viewport().set_input_as_handled()
