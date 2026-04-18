extends Node

# A simple object pool to recycle scenes instead of instantiate/queue_free
var pools: Dictionary = {}

func get_node_from_pool(scene: PackedScene) -> Node:
	var path = scene.resource_path
	if not pools.has(path):
		pools[path] = []
	
	if pools[path].size() > 0:
		var node = pools[path].pop_back()
		node.process_mode = Node.PROCESS_MODE_INHERIT
		if node is Node2D:
			node.visible = true
		return node
	else:
		var node = scene.instantiate()
		return node

func return_node_to_pool(node: Node, scene_path: String) -> void:
	# Disable logic and render
	node.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	if node is Node2D:
		node.visible = false
	
	# Remove from tree hierarchy
	if node.get_parent():
		node.get_parent().call_deferred("remove_child", node)
	
	if not pools.has(scene_path):
		pools[scene_path] = []
	
	pools[scene_path].push_back(node)
