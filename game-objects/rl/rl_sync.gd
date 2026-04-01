extends "res://addons/godot_rl_agents/sync.gd"

class_name RLSync

var _agent_mode: RLEnums.AgentMode

func _ready() -> void:
	pass


func setup(agent_mode: RLEnums.AgentMode) -> bool:
	_agent_mode = agent_mode
	return _initialize()


func _initialize() -> bool:
	_get_agents()
	args = _get_args()

	_set_heuristic("human", all_agents)

	if _agent_mode == RLEnums.AgentMode.TRAIN:
		_initialize_training_agents()

		if not connected:
			return false
	elif _agent_mode == RLEnums.AgentMode.INFERENCE:
		_initialize_inference_agents()
	else:
		push_error("Unknown agent mode: %s" % str(_agent_mode))
		return false

	_set_seed()
	action_repeat = RLConstants.RL_ACTION_REPEAT_FRAMES
	print("action_repeat set to: ", action_repeat)
	initialized = true

	return connected || _agent_mode == RLEnums.AgentMode.INFERENCE


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


func _initialize_inference_agents():
	super._initialize_inference_agents()
	_reset_agents(agents_inference)


func _inference_process():
	if agents_inference.size() > 0:
		_get_reward_from_agents(agents_inference)
		var obs: Array = _get_obs_from_agents(agents_inference)
		var actions = []

		for agent_id in range(0, agents_inference.size()):
			var model: ONNXModel = agents_inference[agent_id].onnx_model
			var action = model.run_inference(obs[agent_id]["obs"], 1)
			var action_dict = _extract_action_dict(
				action["output"],
				_action_space_inference[agent_id],
				model.action_means_only,
			)
			
			actions.append(action_dict)

		_set_agent_actions(actions, agents_inference)
		_reset_agents_if_done(agents_inference)
		get_tree().set_pause(false)
