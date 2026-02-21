extends "res://addons/godot_rl_agents/sync.gd"

class_name RLSync

func _ready() -> void:
	pass


func setup() -> bool:
	return _initialize()


func _initialize() -> bool:
	_get_agents()
	args = _get_args()

	_set_heuristic("human", all_agents)

	_initialize_training_agents()

	if not connected:
		return false

	_set_seed()
	action_repeat = RLConstants.RL_ACTION_REPEAT_FRAMES
	print("action_repeat set to: ", action_repeat)
	initialized = true

	return connected


func connect_to_server():
	print("trying to connect to server")
	stream = StreamPeerTCP.new()

	var ip = "127.0.0.1"
	var port = _get_port()
	stream.connect_to_host(ip, port)

	stream.poll()
	while stream.get_status() < 2:
		stream.poll()

	return stream.get_status() == 2


func _reset_agents(agents = all_agents) -> void:
	for agent in agents:
		agent.needs_reset = true
		agent.reset()
