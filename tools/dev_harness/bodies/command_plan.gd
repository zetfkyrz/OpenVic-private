	# The plan of a field marshal (B3): a group, a front against an enemy, the plan, the check mark; what the bridge gives
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(1.0).timeout
	print("DEVCHECK create group=", PlayerSingleton.create_army_group(), " create front=", PlayerSingleton.create_front(-1))
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(2.0).timeout
	PlayerSingleton.toggle_paused()
	var groups: Array = PlayerSingleton.get_army_groups()
	var fronts: Array = PlayerSingleton.get_front_summaries()
	print("DEVCHECK groups=", groups.size(), " fronts=", fronts.size())
	if groups.is_empty() or fronts.is_empty():
		return
	var group_id: int = int(groups[0][&"id"])
	var front_id: int = int(fronts[0][&"id"])
	print("DEVCHECK hold=", PlayerSingleton.set_army_group_front(group_id, front_id, true), " plan=", PlayerSingleton.set_army_group_plan(group_id, front_id, 1))
	PlayerSingleton.toggle_paused()
	await get_tree().create_timer(2.0).timeout
	PlayerSingleton.toggle_paused()
	for group: Dictionary in PlayerSingleton.get_army_groups():
		print("DEVCHECK group ", group[&"id"], " front_ids=", group[&"front_ids"], " plan_front_id=", group[&"plan_front_id"], " plan_mode=", group[&"plan_mode"], " plan_active=", group[&"plan_active"])
	for front: Dictionary in PlayerSingleton.get_front_summaries():
		print("DEVCHECK front ", front[&"id"], " group_id=", front[&"group_id"], " commanded=", front[&"commanded"])
	print("DEVCHECK start without marshal=", PlayerSingleton.set_army_group_plan_active(group_id, true))
