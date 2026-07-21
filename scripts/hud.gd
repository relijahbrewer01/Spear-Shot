extends CanvasLayer
class_name HUD

const TEXT_COLOR := Color8(237, 238, 225)
const ACCENT_COLOR := Color8(255, 241, 186)
const COUNTDOWN_STEP_COUNT := 3

@export var resume_countdown_step_duration := 0.7
@export var multikill_feedback_duration := 0.75

signal restart_requested
signal pause_toggle_requested
signal pause_resume_click_requested
signal resume_countdown_finished

@onready var score_label: Label = $ScoreLabel
@onready var time_label: Label = $TimeLabel
@onready var multikill_label: Label = $MultikillLabel
@onready var pause_backdrop: ColorRect = $PauseBackdrop
@onready var pause_label: Label = $PauseLabel
@onready var game_over_backdrop: ColorRect = $GameOverBackdrop
@onready var game_over_panel: Panel = $GameOverPanel
@onready var title_label: Label = $GameOverPanel/TitleLabel
@onready var final_score_label: Label = $GameOverPanel/FinalScoreLabel
@onready var final_time_label: Label = $GameOverPanel/FinalTimeLabel
@onready var final_high_score_label: Label = $GameOverPanel/FinalHighScoreLabel
@onready var new_high_score_label: Label = $GameOverPanel/NewHighScoreLabel
@onready var restart_button: Button = $GameOverPanel/RestartButton

var countdown_active := false
var countdown_left := 0.0
var countdown_started_msec := 0
var countdown_end_time_msec := 0
var multikill_feedback_time_left := 0.0


func _ready() -> void:
	_configure_mouse_filters()
	_apply_static_colors()
	restart_button.pressed.connect(_on_restart_button_pressed)
	clear_multikill_feedback()
	hide_pause()
	hide_game_over()


func _process(_delta: float) -> void:
	_update_multikill_feedback(_delta)

	if not countdown_active:
		return

	countdown_left = maxf(float(countdown_end_time_msec - Time.get_ticks_msec()) / 1000.0, 0.0)
	if countdown_left == 0.0:
		countdown_active = false
		resume_countdown_finished.emit()
		return

	_update_countdown_label()


func _unhandled_input(event: InputEvent) -> void:
	if game_over_panel.visible:
		return

	if event.is_action_pressed("pause_game"):
		get_viewport().set_input_as_handled()
		pause_toggle_requested.emit()
		return

	if pause_backdrop.visible and event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and (
			mouse_event.button_index == MOUSE_BUTTON_LEFT
			or mouse_event.button_index == MOUSE_BUTTON_RIGHT
		):
			get_viewport().set_input_as_handled()
			pause_resume_click_requested.emit()


func set_score(score: int) -> void:
	score_label.text = "SCORE %d" % score


func set_health(_health: int) -> void:
	pass


func set_spear_status(_status_text: String) -> void:
	pass


func set_survival_time(survival_time: float) -> void:
	time_label.text = _format_time(survival_time)


func set_high_score(_high_score: int) -> void:
	pass


func show_multikill_feedback(message: String) -> void:
	if multikill_label == null:
		return

	multikill_label.text = message
	multikill_feedback_time_left = multikill_feedback_duration
	multikill_label.visible = true
	multikill_label.scale = Vector2(1.16, 1.16)
	multikill_label.modulate = ACCENT_COLOR


func clear_multikill_feedback() -> void:
	multikill_feedback_time_left = 0.0
	if multikill_label == null:
		return

	multikill_label.visible = false
	multikill_label.scale = Vector2.ONE
	multikill_label.modulate = ACCENT_COLOR


func show_game_over(final_score: int, final_time: float, high_score: int, is_new_high_score: bool) -> void:
	final_score_label.text = "Final Score: %d" % final_score
	final_time_label.text = "Survived: %s" % _format_time(final_time)
	final_high_score_label.text = "High Score: %d" % max(high_score, 0)
	new_high_score_label.visible = is_new_high_score
	game_over_backdrop.visible = true
	game_over_panel.visible = true
	restart_button.grab_focus()


func hide_game_over() -> void:
	game_over_backdrop.visible = false
	game_over_panel.visible = false


func show_pause() -> void:
	countdown_active = false
	countdown_started_msec = 0
	countdown_end_time_msec = 0
	pause_backdrop.visible = true
	pause_label.visible = true
	pause_backdrop.color = Color(0, 0, 0, 0.33)
	pause_label.text = "PAUSED"


func hide_pause() -> void:
	countdown_active = false
	countdown_started_msec = 0
	countdown_end_time_msec = 0
	pause_backdrop.visible = false
	pause_label.visible = false


func start_resume_countdown() -> void:
	countdown_active = true
	countdown_left = resume_countdown_step_duration * float(COUNTDOWN_STEP_COUNT)
	countdown_started_msec = Time.get_ticks_msec()
	countdown_end_time_msec = countdown_started_msec + int(countdown_left * 1000.0)
	pause_backdrop.visible = true
	pause_label.visible = true
	pause_backdrop.color = Color(0, 0, 0, 0.24)
	_update_countdown_label()


func cancel_resume_countdown() -> void:
	show_pause()


func _format_time(time_seconds: float) -> String:
	var total_seconds := int(floor(time_seconds))
	var minutes := total_seconds / 60
	var seconds := total_seconds % 60
	return "%d:%02d" % [minutes, seconds]


func _on_restart_button_pressed() -> void:
	restart_requested.emit()


func _update_countdown_label() -> void:
	var elapsed_msec := maxi(Time.get_ticks_msec() - countdown_started_msec, 0)
	var elapsed_seconds := float(elapsed_msec) / 1000.0
	var step_index := int(floor(elapsed_seconds / maxf(resume_countdown_step_duration, 0.01)))
	var countdown_value := maxi(COUNTDOWN_STEP_COUNT - step_index, 1)
	pause_label.text = str(countdown_value)


func _update_multikill_feedback(delta: float) -> void:
	if multikill_feedback_time_left <= 0.0 or multikill_label == null:
		return
	if get_tree().paused:
		return

	multikill_feedback_time_left = maxf(multikill_feedback_time_left - delta, 0.0)
	if multikill_feedback_time_left == 0.0:
		clear_multikill_feedback()
		return

	var elapsed := multikill_feedback_duration - multikill_feedback_time_left
	var entrance := clampf(elapsed / 0.10, 0.0, 1.0)
	var fade := clampf(multikill_feedback_time_left / 0.18, 0.0, 1.0)
	multikill_label.scale = Vector2.ONE * lerpf(1.16, 1.0, entrance)
	var feedback_color := ACCENT_COLOR
	feedback_color.a = fade
	multikill_label.modulate = feedback_color


func _apply_static_colors() -> void:
	time_label.add_theme_color_override("font_color", TEXT_COLOR)
	score_label.add_theme_color_override("font_color", TEXT_COLOR)
	multikill_label.add_theme_color_override("font_color", ACCENT_COLOR)
	pause_label.add_theme_color_override("font_color", ACCENT_COLOR)
	title_label.add_theme_color_override("font_color", ACCENT_COLOR)
	final_score_label.add_theme_color_override("font_color", TEXT_COLOR)
	final_time_label.add_theme_color_override("font_color", TEXT_COLOR)
	final_high_score_label.add_theme_color_override("font_color", ACCENT_COLOR)
	new_high_score_label.add_theme_color_override("font_color", ACCENT_COLOR)
	restart_button.add_theme_color_override("font_color", TEXT_COLOR)


func _configure_mouse_filters() -> void:
	for control in [
		time_label,
		score_label,
		multikill_label,
		pause_backdrop,
		pause_label,
		game_over_backdrop,
		title_label,
		final_score_label,
		final_time_label,
		final_high_score_label,
		new_high_score_label,
	]:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.focus_mode = Control.FOCUS_NONE

	game_over_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	restart_button.mouse_filter = Control.MOUSE_FILTER_STOP
