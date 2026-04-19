extends Node

# A simple object pool to recycle scenes instead of instantiate/queue_free
var pools: Dictionary = {}

# Tracks nodes that have been handed to _detach_and_pool but not yet pushed.
# Key = instance_id (int), value = true.
# Prevents double-return: if a node is killed by a bullet AND distance-culled
# in the same frame, the second return_node_to_pool call is a no-op.
var _pending: Dictionary = {}

func get_node_from_pool(scene: PackedScene) -> Node:
	var path = scene.resource_path
	if not pools.has(path):
		pools[path] = []

	# Drain the pool until we find a node that has already been fully detached,
	# or until the pool is empty. Stale entries (node still has a parent) can
	# occur if _detach_and_pool hasn't fired yet for that node; skipping them
	# here prevents "already has a parent" errors downstream. The stale node
	# stays in the scene tree and will be returned to the pool normally later.
	while pools[path].size() > 0:
		var node = pools[path].pop_back()
		if node.get_parent() != null:
			continue  # stale — skip, let it live out its life in the tree
		node.process_mode = Node.PROCESS_MODE_INHERIT
		if node is Node2D:
			node.visible = true
		# Let the node reset its own state (health, timers, signals, etc.)
		if node.has_method("_on_pool_retrieved"):
			node._on_pool_retrieved()
		return node

	return scene.instantiate()

func return_node_to_pool(node: Node, scene_path: String) -> void:
	# Guard against double-return in the same frame (e.g. bullet kill +
	# distance cull firing simultaneously). Second call is silently dropped.
	var id = node.get_instance_id()
	if _pending.has(id):
		return
	_pending[id] = true

	# Disable logic and render immediately so the node stops ticking
	# while it waits for the deferred tree removal.
	node.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)
	if node is Node2D:
		node.visible = false

	if not pools.has(scene_path):
		pools[scene_path] = []

	# Defer BOTH the remove_child and the pool push in one call so the node
	# is never in the pool while it still has a parent.
	call_deferred("_detach_and_pool", node, scene_path)

func _detach_and_pool(node: Node, scene_path: String) -> void:
	_pending.erase(node.get_instance_id())
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	pools[scene_path].push_back(node)
