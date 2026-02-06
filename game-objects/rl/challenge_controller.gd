extends "res://addons/godot_rl_agents/controller/ai_controller_2d.gd"

class_name ChallengeAiController

func get_obs() -> Dictionary:
	var obs = []

	print("getting obs")

	return { "obs": obs }


func get_reward() -> float:
	print("getting reward")
	return reward


func get_action_space() -> Dictionary:
	print("getting action space")
	return {
		"pass_action": {
			"size": 1,
			"action_type": "discrete",
		},
	}


func set_action(action) -> void:
	print("setting action", action)
