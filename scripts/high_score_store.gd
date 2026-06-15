extends RefCounted
class_name HighScoreStore

const SAVE_PATH := "user://highscore.save"
const SECTION_NAME := "scores"
const KEY_HIGH_SCORE := "high_score"


static func load_high_score() -> int:
	var config := ConfigFile.new()
	var load_result := config.load(SAVE_PATH)
	if load_result != OK:
		return 0

	return _normalize_high_score(config.get_value(SECTION_NAME, KEY_HIGH_SCORE, 0))


static func save_high_score(high_score: int) -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_NAME, KEY_HIGH_SCORE, max(high_score, 0))
	config.save(SAVE_PATH)


static func _normalize_high_score(value: Variant) -> int:
	match typeof(value):
		TYPE_INT:
			return max(value, 0)
		TYPE_FLOAT:
			return max(int(value), 0)
		_:
			return 0
