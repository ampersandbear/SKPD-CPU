/// @description			Checks to see if it's more benefical to reach the destination using an active ability.
/// @param {Asset.GMPath}	_path						The path we're trying to move along, generated in cpu_movement().
/// @param {Bool}			_bomb						If CPU is trying to get out of an exploding bomb's range.
/// @returns {Bool}
function cpu_ability_move(_path, _bomb) {
	// ignopre the check inside the shop
	if (specific_prefab_loaded != "game") return false;
	if (cpu_ability_cooldown > 0 and cpu_use_ability_cooldown) { 
		cpu_ability_cooldown -= 1;
		return false; 
	}
	var _path_len = path_get_number(_path);
	// floor points in path
	for (var i = _path_len - 1; i >= 0; i--) {
		var _x = floor(path_get_point_x(_path, i));
		var _y = floor(path_get_point_y(_path, i));
		path_delete_point(_path, i);
		path_insert_point(_path, i, _x, _y, 100);
	}
	
	#region Mole Knight A
	if (_path_len > 2 and has_behavior(player, "active_burrow")) {
		var _here = grid[# path_get_point_x(_path, 1), path_get_point_y(_path, 1)];
		// almost always swap, with rare exceptions
		if (unit_instance_is_valid(_here) and !_here.is_corpse and !_here.is_clone 
		and _here.is_moveable and !_here.is_big and !_here.is_grapps) {
			ds_list_add(cpu_moves, eInput.Special);
			if (_here.gridx < player.gridx) ds_list_add(cpu_moves, eInput.Left);
			if (_here.gridx > player.gridx) ds_list_add(cpu_moves, eInput.Right);
			if (_here.gridy < player.gridy) ds_list_add(cpu_moves, eInput.Up);
			if (_here.gridy > player.gridy) ds_list_add(cpu_moves, eInput.Down);
			return true;
		}
	}
	#endregion
	
	#region Prism Knight B's clones
	if (_path_len > 2 and has_behavior(player, "active_clone")) {
		var _here = grid[# path_get_point_x(_path, 1), path_get_point_y(_path, 1)];
		if (unit_instance_is_valid(_here) and _here.is_clone) {
			var _next = grid[# path_get_point_x(_path, 2), path_get_point_y(_path, 2)];
			if (_path_len <= 3 and instance_is_valid(_next) 
			and ((_next.gridx == _here.gridx and _here.gridx == player.gridx) or (_next.gridy == _here.gridy and _here.gridy == player.gridy))
			and !_next.is_door and !_next.is_item) {
				// attack instead of swapping
				return false;
			} else { // swap!
				ds_list_add(cpu_moves, eInput.Special);
				if (pocket_portal) {
					if (player.gridx == 0 and _here.gridx == 7) {
						ds_list_add(cpu_moves, eInput.Left);
						return true;
					} else if (player.gridx == 7 and _here.gridx == 0) {
						ds_list_add(cpu_moves, eInput.Right);
						return true;
					} else if (player.gridy == 1 and _here.gridy == 8) {
						ds_list_add(cpu_moves, eInput.Up);
						return true;
					} else if (player.gridy == 8 and _here.gridy == 1) {
						ds_list_add(cpu_moves, eInput.Down);
						return true;
					}
				}
				if (_here.gridx < player.gridx) { ds_list_add(cpu_moves, eInput.Left);  return true; }
				if (_here.gridx > player.gridx) { ds_list_add(cpu_moves, eInput.Right); return true; }
				if (_here.gridy < player.gridy) { ds_list_add(cpu_moves, eInput.Up);    return true; }
				if (_here.gridy > player.gridy) { ds_list_add(cpu_moves, eInput.Down);  return true; }
				return true;
			}
		}
	}
	#endregion
	#region Treasure Knight B
	if (has_behavior(player, "active_hook")) {
		for (var pt = _path_len - 2; pt > 0; pt--) {
			// we can hook to walls to get to the destination faster
			var _endx = path_get_point_x(_path, pt);
			var _endy = path_get_point_y(_path, pt);
			if (_endx == player.gridx) { // if the endpoint matches our x
				var _distance_to_end = abs(_endy - player.gridy);
				// check if we really save time by hooking to a wall
				if (_endy < player.gridy) { // aiming up
					var _distance_to_wall = _endy - 1;
					// verify there's nothing in the way
					for (var i = 1; i < player.gridy; i++) {
						var _unit = grid[# _endx, i];
						if (unit_instance_is_valid(_unit)) {
							_distance_to_end = 0;
							break;
						}
					}
					// make sure the wall isn't further than the end point
					if (_distance_to_end > 1 and abs(_distance_to_end - _distance_to_wall) < _distance_to_end) {
						ds_list_add(cpu_moves, eInput.Special);
						ds_list_add(cpu_moves, eInput.Up);
						cpu_ability_cooldown = 2; // don't overuse the ability
						return true;
					}
				} else { // aiming down
					var _distance_to_wall = 8 - _endy;
					// verify there's nothing in the way
					for (var i = 8; i > player.gridy; i--) {
						var _unit = grid[# _endx, i];
						if (unit_instance_is_valid(_unit)) {
							_distance_to_end = 0;
							break;
						}
					}
					// make sure the wall isn't further than the end point
					if (_distance_to_end > 1 and abs(_distance_to_end - _distance_to_wall) < _distance_to_end) {
						ds_list_add(cpu_moves, eInput.Special);
						ds_list_add(cpu_moves, eInput.Down);
						cpu_ability_cooldown = 2; // don't overuse the ability
						return true;
					}
				}
			} else if (_endy == player.gridy) { // if the endpoint matches our y
				var _distance_to_end = abs(_endx - player.gridx);
				// check if we really save time by hooking to a wall
				if (_endx < player.gridx) {	// aiming left
					var _distance_to_wall = _endx;
					// verify there's nothing in the way
					for (var i = 0; i < player.gridx; i++) {
						var _unit = grid[# i, _endy];
						if (unit_instance_is_valid(_unit)) {
							_distance_to_end = 0;
							break;
						}
					}
					// make sure the wall isn't further than the end point
					if (_distance_to_end > 1 and abs(_distance_to_end - _distance_to_wall) < _distance_to_end) {
						ds_list_add(cpu_moves, eInput.Special);
						ds_list_add(cpu_moves, eInput.Left);
						cpu_ability_cooldown = 2; // don't overuse the ability
						return true;
					}
				} else { // aiming right
					var _distance_to_wall = 7 - _endx;
					// verify there's nothing in the way
					for (var i = 7; i > player.gridx; i--) {
						var _unit = grid[# i, _endy];
						if (unit_instance_is_valid(_unit)) {
							_distance_to_end = 0;
							break;
						}
					}
					// make sure the wall isn't further than the end point
					if (_distance_to_end > 1 and abs(_distance_to_end - _distance_to_wall) < _distance_to_end) {
						ds_list_add(cpu_moves, eInput.Special);
						ds_list_add(cpu_moves, eInput.Right);
						cpu_ability_cooldown = 2; // don't overuse the ability
						return true;
					}
				}
			}
		}
		if (_bomb) return false;
		// try to bring our target closer to us
		var _target = chosen_tile[3];
		if (unit_instance_is_valid( _target) and _target.is_moveable and !_target.is_big and !_target.is_grapps) {
			if (_target.gridy == player.gridy) { // horizontal
				if (abs(_target.gridx - player.gridx) > 2 and (_target.is_heal or _target.cpu_chain_size < 3)) { // don't break large chains
					// verify nothing is in the way
					var _dir = (_target.gridx < player.gridx) ? - 1 : 1;
					for (var i = player.gridx + _dir; i != _target.gridx; i += _dir) {
						var uu = grid[# i, _target.gridy];
						if (unit_instance_is_valid(uu) and uu != _target) return false;
					}
					ds_list_add(cpu_moves, eInput.Special);
					ds_list_add(cpu_moves, (_dir < 0) ? eInput.Left : eInput.Right);
					return true;
				}
			} else if (_target.gridx == player.gridx) { // vertical
				if (abs(_target.gridy - player.gridy) > 2 and (_target.is_heal or _target.cpu_chain_size < 3)) { // don't break large chains
					// verify nothing is in the way
					var _dir = _target.gridy < player.gridy ? -1 : 1;
					for (var i = player.gridy + _dir; i != _target.gridy; i += _dir) {
						var uu = grid[# _target.gridx, i];
						if (unit_instance_is_valid(uu) and uu != _target) return false;
					}
					ds_list_add(cpu_moves, eInput.Special);
					ds_list_add(cpu_moves, (_dir < 0) ? eInput.Up : eInput.Down);
					return true;
				}
			}
		}
	}
	#endregion
	
	
	if (player.is_modded) with (player) {
		cpu_path = _path;
		cpu_inside_exploding_bomb_range = _bomb;
		cpu_ability_used_to_move = false;
		mod_run_program(program, program_folder, "cpu_ability_move");
		if (cpu_ability_used_to_move) return true;
	}
}
