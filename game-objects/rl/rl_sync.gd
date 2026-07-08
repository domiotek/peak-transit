extends "res://addons/godot_rl_agents/sync.gd"

class_name RLSync

var _agent_mode: RLEnums.AgentMode
var _apply_mask: bool = false

func _ready() -> void:
	pass


func setup(agent_mode: RLEnums.AgentMode, apply_mask: bool = false) -> bool:
	_agent_mode = agent_mode
	_apply_mask = apply_mask
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
			var agent = agents_inference[agent_id]
			var model: ONNXModel = agent.onnx_model
			var action = model.run_inference(obs[agent_id]["obs"], 1)
			var output: Array = action["output"]

			var action_dict
			if _is_flat_action_output(output, _action_space_inference[agent_id]):
				action_dict = agent.pick_flat_action(output, _apply_mask)
			else:
				action_dict = _extract_action_dict(
					output,
					_action_space_inference[agent_id],
					model.action_means_only,
				)

			actions.append(action_dict)

		_set_agent_actions(actions, agents_inference)
		_reset_agents_if_done(agents_inference)
		get_tree().set_pause(false)


## A flat (single-head) model outputs one value per legal action; the native composite
## policy outputs one logit block per action component. Tell them apart by comparing the
## ONNX output length against the summed size of the composite action space.
func _is_flat_action_output(output: Array, action_space: Dictionary) -> bool:
	var composite_size := 0
	for key in action_space.keys():
		composite_size += action_space[key]["size"]
	return output.size() != composite_size


func _call_method_on_agents(method):
	if method == "get_action_mask":
		var target_agents = agents_training if agents_training.size() > 0 else all_agents
		var returns = []
		for agent in target_agents:
			returns.append(agent.call(method))
		return returns

	return super._call_method_on_agents(method)


func handle_message() -> bool:
	var message = _get_dict_json_message()
	if message["type"] == "close":
		print("received close message, closing game")
		get_tree().quit()
		get_tree().set_pause(false)
		return true

	if message["type"] == "reset":
		print("resetting all agents")
		_reset_agents()
		just_reset = true
		get_tree().set_pause(false)
		return true

	if message["type"] == "call":
		var method = message["method"]
		var returns = _call_method_on_agents(method)
		var reply = { "type": "call", "returns": returns }
		if method != "get_action_mask":
			print("calling method from Python")
		_send_dict_as_json_message(reply)
		return handle_message()

	if message["type"] == "action":
		var action = message["action"]
		_set_agent_actions(action, agents_training)
		need_to_send_obs = true
		get_tree().set_pause(false)
		return true

	print("message was not handled")
	return false
