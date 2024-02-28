class_name LoadingScreen
extends CanvasLayer

const LOADING_COMPLETE_TEXT = "Loading Complete!"
const LOADING_COMPLETE_TEXT_WAITING = "Any Moment Now..."
const LOADING_TEXT = "Loading..."
const LOADING_TEXT_WAITING = "Still Loading..."

enum StallStage{STARTED, WAITING, GIVE_UP}
var _stall_stage : StallStage = StallStage.STARTED
var _scene_loading_complete : bool = false
var _scene_loading_progress : float = 0.0 :
	set(value):
		if value <= _scene_loading_progress:
			return
		_scene_loading_progress = value
		update_total_loading_progress()
		_reset_loading_stage()

var _changing_to_next_scene : bool = false
var _total_loading_progress : float = 0.0 :
	set(value):
		if value <= _total_loading_progress:
			return
		_total_loading_progress = value
		%ProgressBar.value = _total_loading_progress

func update_total_loading_progress():
	_total_loading_progress = _scene_loading_progress

func _reset_loading_stage():
	_stall_stage = StallStage.STARTED
	%LoadingTimer.start()

func _try_loading_next_scene():
	if not _scene_loading_complete:
		return
	_load_next_scene()

func _load_next_scene():
	if _changing_to_next_scene:
		return
	_changing_to_next_scene = true
	SceneLoader.call_deferred("change_scene_to_resource")

func _process(_delta):
	_try_loading_next_scene()
	var status = SceneLoader.get_status()
	match(status):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_scene_loading_progress = SceneLoader.get_progress()
			match _stall_stage:
				StallStage.STARTED:
					%ErrorMessage.hide()
					%Title.text = LOADING_TEXT
				StallStage.WAITING:
					%ErrorMessage.hide()
					%Title.text = LOADING_TEXT_WAITING
				StallStage.GIVE_UP:
					if %ErrorMessage.visible:
						return
					if _scene_loading_progress == 0:
						%ErrorMessage.dialog_text = "Loading Error: Failed to start."
						if OS.has_feature("web"):
							%ErrorMessage.dialog_text += "\nTry refreshing the page."
					else:
						%ErrorMessage.dialog_text = "Loading Error: Failed at %d%%." % (_scene_loading_progress * 100.0)
					%ErrorMessage.popup_centered()
		ResourceLoader.THREAD_LOAD_LOADED:
			_scene_loading_progress = 1.0
			_scene_loading_complete = true
			match _stall_stage:
				StallStage.STARTED:
					%ErrorMessage.hide()
					%Title.text = LOADING_COMPLETE_TEXT
				StallStage.WAITING:
					%ErrorMessage.hide()
					%Title.text = LOADING_COMPLETE_TEXT_WAITING
				StallStage.GIVE_UP:
					if %ErrorMessage.visible:
						return
					%ErrorMessage.dialog_text = "Loading Error: Failed to switch scenes."
					%ErrorMessage.popup_centered()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			%ErrorMessage.dialog_text = "Loading Error: %d" % status
			%ErrorMessage.popup_centered()
			set_process(false)

func _on_loading_timer_timeout():
	var prev_stage : StallStage = _stall_stage
	match prev_stage:
		StallStage.STARTED:
			_stall_stage = StallStage.WAITING
			%LoadingTimer.start()
		StallStage.WAITING:
			_stall_stage = StallStage.GIVE_UP

func _on_error_message_confirmed():
	var err = get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	if err:
		print("failed to load main scene: %d" % err)
		get_tree().quit()
