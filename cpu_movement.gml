/// @description			Builds a path (cpu_path) to the previously chosen target tile, then decides the next input to get there.
/// @param {Bool}			_bomb						If CPU is trying to get out of an exploding bomb's range.
/// @param {Bool}			_is_volleybomb				Tf CPU is trying to serve the Volleybomb back.
/// @param {Bool}			_on_top_of_volleybomb		Tf CPU is inside the Volleybomb landing spot.
/// @param {Id.Instance}	_volleybomb					The instance ID of the Volleybomb object.
/// @returns {Bool}
function cpu_movement(_bomb, _is_volleybomb, _on_top_of_volleybomb, _volleybomb) {
	var _target;
	var _tx;
	var _ty;
	
	if (_bomb) { // drop our target if we're trying to avoid an exploding bomb
		_target = noone;
		_tx = -1;
		_ty = -1;
	} else {
		_target = chosen_tile[3]; // instance ID
		_tx = chosen_tile[0]; // gridx
		_ty = chosen_tile[1]; // gridy
	}
	
	#macro BLOCK	-100 // to mark tiles we can't move through
	cpu_path_grid = ds_grid_create(GRID_WIDTH, GRID_HEIGHT);
	ds_grid_clear(cpu_path_grid, 1000);
	
	var _bomb_resist = has_blessing(blessings, blessing.bombvest) or has_blessing(blessings, blessing.bomb_resistance);
	
	// mark impassible tiles for further pathfinding
	for (var i= 0; i < GRID_WIDTH; i++) {
		for (var e = 0; e < GRID_HEIGHT; e++) {
			// top of the Grid (where enemies spawn)
			if (e == 0) { 
				cpu_path_grid[# i, e] = BLOCK; 
				continue; 
			}
			// range of exploding bombs
			if (!_bomb and !_bomb_resist and !cpu_bomb_grid[# i, e]) { 
				cpu_path_grid[# i, e] = BLOCK; 
				continue; 
			}
			var _here = grid[# i, e];
			if (unit_instance_is_valid(_here) and !_here.is_corpse and !_here.is_clone and _here.player == 0) {
				//  ignore hidden units
				if (_here.hidden and (cpu_level < 3 or (cpu_level <= 6 and irandom(100) >= 10 + cpu_level * 10))) continue;
				// mark as occupied
				if (!cpu_mole_b and !has_behavior(player, "active_burrow") and !_here.is_heal) cpu_path_grid[# i, e] = BLOCK;
				// avoid charging blitzsteed:
				if (has_behavior(_here, "chase_run")
				and _here.attack_timer == 1 
				and i + _here.image_xscale >= 0 
				and i + _here.image_xscale < GRID_WIDTH) {
					cpu_path_grid[# i + _here.image_xscale, e] = BLOCK;
				}
			}
		}
	}
	
	// try to also avoid traps, unless we have Nimbus Balloon
	if (!has_blessing(blessings, blessing.hazard_resistance) and !_bomb) {
		var _gm = id;
		with (oTrap) {
			if (grid_master != _gm or offscreen) continue;
			// we can step on burners if they are inactive
			if (tile_type == stile.burner and burner_time <= 1) continue;
			// try to avoid all traps, except for movement-based traps
			if ((tile_type != stile.water
			and tile_type != stile.wind
			and tile_type != stile.cbelt
			and tile_type != stile.smoke
			and tile_type != stile.fire
			and other.player_hp <= 3)
			or tile_type == stile.poison) {
				other.cpu_path_grid[# gridx, gridy] = BLOCK;
			}
		}
	}
	// if target is shielded, block the tile in front of them
	if (!cpu_mole_b and instance_is_valid(_target)) {
		if (_target.invincible_side[0] != 0) cpu_path_grid[# _target.gridx + sign(_target.invincible_side[0]), _target.gridy] = BLOCK;
		if (_target.invincible_side[1] != 0) cpu_path_grid[# _target.gridx, _target.gridy + sign(_target.invincible_side[1])] = BLOCK;
	}
	// clear target's cell
	if (!_bomb) {
		cpu_path_grid[# _tx, _ty] = 1000;
	}
	
	if (player.is_modded) {
		cpu_target = _target;
		cpu_target_x = _tx;
		cpu_target_y = _ty;
		mod_run_program(player.program, player.program_folder, "cpu_mark_path_obstacles");
	}
	
	// find path
	taken_positions = ds_list_create();
	parent_positions = ds_grid_create(GRID_WIDTH, GRID_HEIGHT);
	var _pos = cpu_pathfind(_bomb, _is_volleybomb, _on_top_of_volleybomb, _volleybomb);
	if (_pos == -1 and _bomb) { // if target can't be reached
		ds_grid_clear(cpu_bomb_grid, true);
		cpu_bomb_is_exploding = false;
		current_step = 3; // choose another target
		return true;
	}
	path_clear_points(cpu_path);
	
	if (is_array(_pos)) {
		var _x	 = _pos[0];
		var _y   = _pos[1];
		path_add_point(cpu_path, _x, _y, 1);
		// rebuild our path:
		while (_x != player_gridx or _y != player_gridy) {
			var _parent = parent_positions[# _x, _y];
			_x = _parent[0];
			_y = _parent[1];
			path_add_point(cpu_path, _x, _y, 1);
		}
		path_reverse(cpu_path); // reverse it since if was tracked from the target
	}
	ds_list_destroy(taken_positions);
	ds_grid_destroy(parent_positions);
	
	var _nx = floor(path_get_point_x(cpu_path, 1));
	var _ny = floor(path_get_point_y(cpu_path, 1));
	var _px = player_gridx;
	var _py = player_gridy;
	
	if (player.is_modded) {
		cpu_moved = false;
		cpu_target = _target;
		cpu_target_x = _tx;
		cpu_target_y = _ty;
		mod_run_program(player.program, player.program_folder, "cpu_move");
		if (cpu_moved) {
			ds_grid_destroy(cpu_path_grid);
			return false;
		}
	}
	
	// only move down after being teleported by Magic Floor:
	if (player_gridy == 0) {
		ds_list_add(cpu_moves, eInput.Down);
		return false;
	}
	
	// Beefto: if the next cell is to the right or to the bottom, ignore it and pick the next point from the path
	if (player.is_big) {
		var i = 2;
		while ((_nx == player_gridx + 1 and _ny == player_gridy) 
		or (_nx == player_gridx and _ny == player_gridy + 1)
		or (_nx == player_gridx + 1 and _ny == player_gridy + 1)) {
			_px = _nx;
			_py = _ny;
			_nx = floor(path_get_point_x(cpu_path, i));
			_ny = floor(path_get_point_y(cpu_path, i));
			i++;
		}
	}
	
	// Beefto's ability
	if (cpu_beefto) {
		if (grid[# _nx, _ny] == _target and _target.is_door) {
			if (player.is_big) { // become small to enter doors
				ds_list_add(cpu_moves, eInput.Special);
				return false;
			}
		} else if (--cpu_beefto_delay == 0) {
			cpu_beefto_delay = irandom_range(5, 15);
			if (player.is_big) cpu_beefto_delay = clamp(cpu_beefto_delay - cpu_level, 2, 15);
			ds_list_add(cpu_moves, eInput.Special);
			return false;
		}
	}
	
	// queue Thorny Tambourine use if we can kill the target with just one more damage
	if (unit_instance_is_valid(_target) and _target.cpu_survives_with_hp > 0) {
		if (_target.cpu_survives_with_hp == 1 or _target.hpmax > 3) and !player.extra_damage_tambourine and has_blessing(blessings, blessing.tambourine) {
			ds_list_add(cpu_moves, eInput.Speed);
		}
	}
	
	var _unit = grid[# _nx, _ny];
	var _target_is_valid = _unit == _target 
		or !instance_is_valid(_unit)
		or cpu_mole_b
		or _unit.is_clone
		or _unit.is_heal;
	var _used_portal = false;
	var _target_not_on_top_of_player = false;
	
	if (_target_is_valid) {
		_target_not_on_top_of_player = !instance_is_valid(_target) or !(player_gridx == _target.gridx and player_gridy == _target.gridy);
	}
	
	// first, check if we shall use Pocket Portal:
	if (pocket_portal and _target_is_valid and _target_not_on_top_of_player) {
		if (_px == 0 and _nx == 7) {
			ds_list_add(cpu_moves, eInput.Left);
			_used_portal = true;
		} else if (_px == 7 and _nx == 0) {
			ds_list_add(cpu_moves, eInput.Right);
			_used_portal = true;
		} else if (_py == 1 and _ny == 8) {
			ds_list_add(cpu_moves, eInput.Up);
			_used_portal = true;
		} else if (_py == 8 and _ny == 1) {
			ds_list_add(cpu_moves, eInput.Down);
			_used_portal = true;
		}
	}
	
	if (_used_portal) {
		ds_grid_destroy(cpu_path_grid);
		return false;
	}
	
	if DEBUG_BUILD
	{
		if (instance_is_valid(_target)) trace("Target is: ", _target.name, " at ", _target.gridx, " , ", _target.gridy);
		trace("Player is: ", player_gridx, " , ", player_gridy);
		trace("Trying to move to ", _nx, " , ", _ny);
		trace("Path is:");
		for(var i = 0; i < path_get_number(cpu_path); i++)
		{
			trace( path_get_point_x(cpu_path, i), " , ", path_get_point_y(cpu_path, i));
		}
		trace("Values are:")
		for (var j = 0; j < GRID_HEIGHT; j++) {
			var _s = "";
			for (var i = 0; i < GRID_WIDTH; i++) {
				var _v = cpu_grid[# i, j];
				if (is_array(_v)) _v = _v[2];
				_s += string(_v) + " ";
			}
			trace(_s);
		}
		//show_message(".")
	}
	
	
		
	// some characters might have an easier time moving with their abilities
	if (cpu_ability_move(cpu_path, _bomb)) {
		ds_grid_destroy(cpu_path_grid);
		return false;
	}

	// move us to the next point
	if (_target_is_valid) {
		// Mole Knight B attacks if on top of the target
		if (cpu_mole_b and unit_instance_is_valid(_target) and player_gridx == _target.gridx and player_gridy == _target.gridy) { 
			ds_list_add( cpu_moves, eInput.Special);
			ds_grid_destroy(cpu_path_grid);
			return false; 
		}
		
		if (_nx - _px < 0) {
			ds_list_add(cpu_moves, eInput.Left);
		} else if (_nx - _px > 0) {
			ds_list_add(cpu_moves, eInput.Right);
		} else if (_ny - _py < 0) {
			ds_list_add(cpu_moves, eInput.Up);
		} else if (_ny - _py > 0) {
			ds_list_add(cpu_moves, eInput.Down);
		}
	}
	ds_grid_destroy(cpu_path_grid);
	
	// give the previously chosen tile higher priority
	if (chosen_tile != noone) {
		if (unit_instance_is_valid(_target)) {
			// Terrorpin exception, we don't want to be stuck hitting it
			if (_target.unit_type == unit.terrorpin) {
				_target.cpu_added_value -= 15;
				cpu_terrorpin_value -= 15; 
			} else if (ds_list_empty(cpu_moves)) {
				_target.cpu_added_value = -15;  // we couldn't reach this tile, so lower its priority instead
			} else {
				_target.cpu_added_value += 2; 
			}
		}
		chosen_tile = noone;
	}
	// restart CPU if we couldn't make a move
	if (ds_list_empty(cpu_moves)) {
		couldnt_move = true;
		if (cpu_ignore_bomb_check) {
			current_step = 3; // choose another target
		} else if (cpu_level < 5) {
			current_step = 0; // restart the whole step logic
		} else { // skip the turn if CPU is smart
			ds_list_add(cpu_moves, eInput.Speed);
			return false; 
		}
		return true;
	}
	couldnt_move = false;
	return false;
}


/// @description			Basically DFS with some Pocket Portal hacks.
/// @param {Bool}			_bomb						If CPU is trying to get out of an exploding bomb's range.
/// @param {Bool}			_is_volleybomb				Tf CPU is trying to serve the Volleybomb back.
/// @param {Bool}			_on_top_of_volleybomb		Tf CPU is inside the Volleybomb landing spot.
/// @param {Id.Instance}	_volleybomb					The instance ID of the Volleybomb object.
/// @returns {Array}			
function cpu_pathfind(_bomb, _is_volleybomb, _on_top_of_volleybomb, _volleybomb) {
	// add starting position to the list
	ds_list_add(taken_positions, { xpos : player_gridx, ypos : player_gridy });
	cpu_path_grid[# player_gridx, player_gridy] = 0;
	
	for (var i = 0; i < ds_list_size(taken_positions); i++) {
		var _cell = taken_positions[| i];
		var _x	  = _cell.xpos;
		var _y	  = _cell.ypos;
		var _v	  = cpu_path_grid[# _x, _y];
		
		// if we're just trying to get out of the bomb range, quit as soon as we find the first empty tile outside of it
		if (_bomb and cpu_bomb_grid[# _x, _y]) {
			var _return = true;
			
			if (_is_volleybomb and _on_top_of_volleybomb and cpu_chase_volleybomb and (_x < _volleybomb.left or _x > _volleybomb.right or _y > _volleybomb.down or _y < _volleybomb.up)) {
				_return = false; // don't move out of volleybomb bounds
			}
			
			if (player.is_big) { // big units need to account for bomb explosion areas differently
				if (_x < 7  and !cpu_bomb_grid[# _x + 1, _y]) _return = false;
				if (_x == 7 and !cpu_bomb_grid[# _x - 1, _y]) _return = false;
				if (_y < 8  and !cpu_bomb_grid[# _x, _y + 1]) _return = false;
				if (_y == 8 and !cpu_bomb_grid[# _x, _y - 1]) _return = false;
				if (_x < 7  and _y < 8  and !cpu_bomb_grid[# _x + 1, _y + 1]) _return = false;
				if (_x == 7 and _y == 8 and !cpu_bomb_grid[# _x - 1, _y - 1]) _return = false;
			}
			if (_return) return [_x, _y];
		}
		
		if (!_bomb and _x == chosen_tile[0] and _y == chosen_tile[1]) {
			return [_x, _y]; // we reached the target, return
		}
		// add all neighbours to the list
		var _dir = ds_list_create();
		ds_list_add(_dir, 0, 1, 2, 3);
		// randomize the order in which directions are parced, so that if we get stuck we'll be able to get out
		ds_list_shuffle(_dir);
		
		for (var j = 0; j < 4; j++) {
			
			var _d = 1;
			// we need to handle pathfinding differently for knights that mvove two tiles per turn
			if (has_two_step and !prefab_is_shop(specific_prefab_loaded)) { 
				switch (_dir[| j]) {
					case 0: if (_x > 1 and unit_counts_as_empty(grid[# _x - _d, _y]) and !unit_pathfind_valid(grid[# _x - _d * 2, _y]) and cpu_path_grid[# _x - _d, _y] > 0) _d++; break;
					case 1: if (_x < 6 and unit_counts_as_empty(grid[# _x + _d, _y]) and !unit_pathfind_valid(grid[# _x + _d * 2, _y]) and cpu_path_grid[# _x + _d, _y] > 0) _d++; break;
					case 2: if (_y > 2 and unit_counts_as_empty(grid[# _x, _y - _d]) and !unit_pathfind_valid(grid[# _x, _y - _d * 2]) and cpu_path_grid[# _x, _y - _d] > 0) _d++; break;
					case 3: if (_y < 7 and unit_counts_as_empty(grid[# _x, _y + _d]) and !unit_pathfind_valid(grid[# _x, _y + _d * 2]) and cpu_path_grid[# _x, _y + _d] > 0) _d++; break;
				}
			}
			
			switch (_dir[| j]) {
				case 0: if (_x > 0) cpu_make_path_to(_x - _d, _y, _v, _x, _y); else if (pocket_portal) cpu_make_path_to(7, _y, _v, _x, _y); break;
				case 1: if (_x < 7) cpu_make_path_to(_x + _d, _y, _v, _x, _y); else if (pocket_portal) cpu_make_path_to(0, _y, _v, _x, _y); break;
				case 2: if (_y > 1) cpu_make_path_to(_x, _y - _d, _v, _x, _y); else if (pocket_portal and ceiling_crusher == noone) cpu_make_path_to(_x, 8, _v, _x, _y); break;
				case 3: if (_y < 8) cpu_make_path_to(_x, _y + _d, _v, _x, _y); else if (pocket_portal and ceiling_crusher == noone) cpu_make_path_to(_x, 1, _v, _x, _y); break;
			}
		}
		ds_list_destroy(_dir);
	}
	return -1;
}

/// @description			DFS step function used inside cpu_pathfind().
/// @param {Real}			_x							Target x position.
/// @param {Real}			_y							Target y position.
/// @param {Real}			_v							Current path length.
/// @param {Real}			_parent_x					Previous x position.
/// @param {Real}			_parent_y					Previous y position.
function cpu_make_path_to(_x, _y, _v, _parent_x, _parent_y) {
	if (cpu_path_grid[# _x, _y] > _v) {
		ds_list_add(taken_positions, { xpos : _x, ypos : _y }); // add cell to the list to be parced later
		parent_positions[# _x, _y] = [_parent_x, _parent_y]; // save where me moved from (to rebuild our path later)
		cpu_path_grid[# _x, _y] = _v + 1; // update the distance traveled
	}
}

/// @description			Checks if we can move through this unit ir not, used for knights that move two tiles at once.
/// @param {Id.Instance}	_unit						The instance ID of the unit to check.
/// @returns {Bool}	
function unit_pathfind_valid(_unit) {
	if (unit_instance_is_valid(_unit)) {
		// ignore corpses and itself
		if (_unit.is_corpse) return false;
		return !_unit.player;
	}
	return false;
}
