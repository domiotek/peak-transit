extends Node2D

class_name GameWindow

@onready var main_menu_ui: Control = $UI/MainMenu

@onready var config_manager: ConfigManager = GDInjector.inject("ConfigManager") as ConfigManager
@onready var game_manager: GameManager = GDInjector.inject("GameManager") as GameManager
@onready var world_manager: WorldManager = GDInjector.inject("WorldManager") as WorldManager
@onready var ui_manager: UIManager = GDInjector.inject("UIManager") as UIManager

@onready var rl_sync: RLSync = $RLSync

var _args: Dictionary


func _ready() -> void:
	game_manager.game_controller_registration.connect(Callable(self, "_on_game_registration_requested"))
	game_manager.game_initialized.connect(Callable(self, "_on_game_loaded"))

	ui_manager.initialize(main_menu_ui)

	_args = Utils.get_args()

	_handle_autoload()


func _on_game_registration_requested(game_controller: BaseGameController) -> void:
	self.add_child(game_controller)


func _on_game_loaded(success: bool) -> void:
	if not success:
		return

	var is_rl_session = _args.has("rl")

	if is_rl_session:
		_setup_rl_session()


func _handle_autoload() -> void:
	var game_mode = _args.get("mode", "").to_lower()
	var world_name = _args.get("world", "")

	if game_mode == "" or world_name == "":
		if config_manager.AutoQuickLoad:
			game_manager.initialize_game(Enums.GameMode.CHALLENGE)

		return

	var game_mode_names = Enums.GameMode.keys().map(
		func(m):
			return m.to_lower().replace("_", "")
	)

	var world_def = world_manager.FindWorldByName(world_name)

	if world_def == null:
		print("World specified in arguments not found. Ignoring.")
		return

	var world = SlimWorldDefinition.deserialize(world_def)

	if game_mode == game_mode_names[Enums.GameMode.CHALLENGE]:
		game_manager.initialize_game(Enums.GameMode.CHALLENGE, world.file_path)
	elif game_mode == game_mode_names[Enums.GameMode.MAP_EDITOR]:
		game_manager.initialize_game(Enums.GameMode.MAP_EDITOR, world.file_path)
	else:
		prints("Invalid game mode specified in arguments. Ignoring.")


func _setup_rl_session() -> void:
	print("Starting RL session...")

	var agents = get_tree().get_nodes_in_group("AGENT")

	if agents.size() == 0:
		push_error("This game mode doesn't have any agents to train. Cannot start RL session.")
		_quit()
		return

	ui_manager.show_ui_view(
		LoadingProgressView.VIEW_NAME,
		{
			"title": "Starting RL Session",
			"action": "Connecting with RL framework...",
			"show_progress_bar": false,
		},
	)

	await game_manager.wait_frame()

	var connected = rl_sync.setup()

	await game_manager.wait_frame()

	ui_manager.hide_ui_view(LoadingProgressView.VIEW_NAME)

	if not connected:
		push_error("Failed to connect with RL framework. Cannot start RL session.")
		_quit()
		return

	game_manager.set_rl_mode()
	game_manager.set_game_speed(Enums.GameSpeed.TURBO)


func _quit() -> void:
	get_tree().quit()
