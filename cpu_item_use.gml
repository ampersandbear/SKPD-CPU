/// @description See if we should use our active item. Passive items are processed in cpu_scan_tile() with attack_next_hit or counter_next_hit.
function cpu_item_use() {
	// don't use any inside the shop
	if (specific_prefab_loaded != "game") return false;
	// don't, if we are transmogrified
	if (player.transmog_turns) return false;
	// don't, if item usage is on cooldown
	if (cpu_item_cooldown > 0 && cpu_use_item_cooldown) {
		cpu_item_cooldown -= 1;
		return false;
	}
	
	if (player.is_modded) { 
		cpu_item_used = false;
		mod_run_program(player.program, player.program_folder, "cpu_item_use");
		if (cpu_item_used) return true;
	}
	
	switch (player.item) {
		#region Throwing Anchor & Smoke Bomb
		case unit.phase_locket:
		case unit.anchor:
			var _dx = [-2, 2, 0, 0];
			var _dy = [0, 0, -2, 2];
			if (player.item == unit.phase_locket) {
				_dx = [-1, 1, 0, 0];
				_dy = [0, 0, -1, 1];
			}
			var _highest = noone;
			var _highest_idx = noone;
			
			for (var i = 0; i < 4; i++) {
				var _val = 0;
				var _tx = player_gridx + _dx[i];
				var _ty = player_gridy + _dy[i];
				// check all the directions
				for (var xx = _tx - 1; xx <= _tx + 1; xx++) {
					for (var yy = _ty - 1; yy <= _ty + 1; yy++) {
						var _here = grid[# xx, yy];
						if (unit_instance_is_valid(_here)) {
							if		(_here.is_big)   _val += 3;
							else if (_here.is_enemy) _val += 2;
							else if (_here.is_block) _val += 1;
							else if (_here.is_heal)  _val -= 1;
						}
					}
				}
				if (_val > _highest) {
					_highest_idx = i;
					_highest = _val;
				}
			}
			// if there is a direction that has a certain amount of value, use the item
			if (_highest >= 8) { // 4 enemies at least (half of 3x3 area)
				ds_list_add(cpu_moves, eInput.Item);
				// direction
				if (_dx[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Left);
				if (_dx[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Right);
				if (_dy[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Up);
				if (_dy[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Down);
				// increase/lower the value of units in this area
				var _tx = player_gridx + _dx[_highest_idx];
				var _ty = player_gridy + _dy[_highest_idx];
				var _added_value = (player.item == unit.anchor) ? -10 : 10;
				for (var xx = _tx - 1; xx <= _tx + 1; xx++) {
					for (var yy = _ty - 1; yy <= _ty + 1; yy++) {
						var _here = grid[# xx, yy];
						if (unit_instance_is_valid(_here)) {
							if		(_here.is_enemy) _here.cpu_added_value += _added_value;
							else if (_here.is_block and player.item == unit.anchor) _here.cpu_added_value += _added_value;
						}
					}
				}
				// don't use it again for a bit
				cpu_item_cooldown = 5 + (player.item == unit.phase_locket) * 5;
				// skip to movement step
				current_step = 4;
				return true;
			}
		break;
		#endregion
		#region War Horn
		case unit.war_horn:
			var _value = 0;
			for (var xx = player_gridx - 2; xx <= player_gridx + 2; xx++) {
				for (var yy = player_gridy - 2; yy <= player_gridy + 2; yy++) {
					var _here = grid[# xx, yy];
					if (unit_instance_is_valid(_here)) {
						if		(_here.is_big)   _value += 3;
						else if (_here.is_enemy) _value += 2;
						else if (_here.is_block) _value += 1;
						else if (_here.is_heal)  _value -= 1;
					}
				}
			}
			if (_value >= 22) { // around 11 enemies
				ds_list_add(cpu_moves, eInput.Item);
				cpu_item_cooldown = 2; // don't rapid fire
				current_step = 4; // skip to movement step
				return true;
			}
		break;
		#endregion
		#region Zap Wand
		case unit.flare_wand:
			var _dx = [-1, 1, 0, 0];
			var _dy = [0, 0, -1, 1];
			var _highest = noone;
			var _highest_idx = noone;
			
			for (var i = 0; i < 4; i++) {
				var _val = 0;
				var _tx = player_gridx + _dx[i];
				var _ty = player_gridy + _dy[i];
				while (_tx >= 0 and _tx <= 7 and _ty >= 1 and _ty <= 8) {
					var _here = grid[# _tx, _ty];
					if (unit_instance_is_valid(_here)) {
						if		(_here.is_big)   _val += 3;
						else if (_here.is_enemy) _val += 2;
						else if (_here.is_block) _val += 1;
						else if (_here.is_heal)  _val -= 1;
					}
					_tx += _dx[i];
					_ty += _dy[i];
				}
				if (_val > _highest) {
					_highest_idx = i;
					_highest = _val;
				}
			}
			if (_highest >= 8) { // 4 enemies at least
				ds_list_add(cpu_moves, eInput.Item);
				if (_dx[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Left);
				if (_dx[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Right);
				if (_dy[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Up);
				if (_dy[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Down);
				cpu_item_cooldown = 2; // don't rapid fire
				current_step = 4; // skip to movement step
				return true;
			}
		break;
		#endregion
		#region Flip Wand
		case unit.flipwand:
			var _dx = [-1, 1, 0, 0];
			var _dy = [0, 0, -1, 1];
			var _highest = noone;
			var _highest_idx = noone;
			
			for (var i = 0; i < 4; i++) {
				var _val = 0;
				var _tx = player_gridx + _dx[i];
				var _ty = player_gridy + _dy[i];
				while (_tx >= 0 and _tx <= 7 and _ty >= 1 and _ty <= 8) {
					var _here = grid[# _tx, _ty];
					if (unit_instance_is_valid(_here)) {
						if		(_here.is_flipped)	_val -= 2;
						else if (_here.is_big)		_val += 3;
						else if (_here.is_enemy)	_val += 2;
					}
					_tx += _dx[i];
					_ty += _dy[i];
				}
				if (_val > _highest) {
					_highest_idx = i;
					_highest = _val;
				}
			}
			if (_highest >= 8) { // 4 enemies at least
				ds_list_add(cpu_moves, eInput.Item);
				if (_dx[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Left);
				if (_dx[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Right);
				if (_dy[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Up);
				if (_dy[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Down);
				cpu_item_cooldown = 2; // don't rapid fire
				current_step = 4; // skip to movement step
				return true;
			}
		break;
		#endregion
		#region Chronos Coin
		case unit.chrono_coin:
			if (!time_frozen) {
				var _cells = find_empty_cells(id);
				var _free_spots = ds_list_size(_cells);
				ds_list_destroy(_cells);
				// Freeze the stage if we are getting overwhelmed
				if (_free_spots < 64 - 48) { // 75% full
					ds_list_add(cpu_moves, eInput.Item);
					current_step = 4; // skip to movement step
					return true;
				}
			}
		break;
		#endregion
		#region Chalices
		case unit.ichor_chalice:
		case unit.ichor_chalice2:
			// just use it right away
			ds_list_add(cpu_moves, eInput.Item);
			current_step = 4; // skip to movement step
			return true;
		break;
		#endregion
		#region Copy Card
		case unit.copycard:
			var _dx = [-1, 1, 0, 0];
			var _dy = [0, 0, -1, 1];
			var _highest = noone;
			var _highest_idx = noone;
			
			for (var i = 0; i < 4; i++) {
				var _val = 0;
				var _tx = player_gridx + _dx[i];
				var _ty = player_gridy + _dy[i];
				var _here = grid[# _tx, _ty];
				if (unit_instance_is_valid(_here)) {
					// only attempt to transform strong units
					if (_here.is_enemy and _here.hp >= 3 and !_here.is_big) {
						_val += _here.hp + _here.atk * 2 + _here.cpu_chain_size;
					}
				}
				if (_val > _highest) {
					_highest_idx = i;
					_highest = _val;
				}
			}
			if (_highest >= 15) {
				ds_list_add(cpu_moves, eInput.Item);
				if (_dx[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Left);
				if (_dx[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Right);
				if (_dy[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Up);
				if (_dy[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Down);
				cpu_item_cooldown = 2; // don't rapid fire
				current_step = 4; // skip to movement step
				return true;
			}
		break;
		#endregion
		#region Wild Card
		case unit.wildcard:
			var _dx = [-1, 1, 0, 0];
			var _dy = [0, 0, -1, 1];
			var _highest = noone;
			var _highest_idx = noone;
			
			for (var i = 0; i < 4; i++) {
				var _val = 0;
				var _tx = player_gridx + _dx[i];
				var _ty = player_gridy + _dy[i];
				var _here = grid[# _tx, _ty];
				if (unit_instance_is_valid(_here)) {
					var _ut = _here.unit_type;
					var _gm = id;
					var _count = 0;
					// find the total amount of these units on the grid
					with (oUnit) {
						if (grid_master != _gm) continue;
						if (_ut == unit_type) _count++;
					}
					_val = _count * _here.hpmax;
				}
				if (_val > _highest) {
					_highest_idx = i;
					_highest = _val;
				}
			}
			if (_highest >= 10 + irandom(10)) { // rng is to help the CPU use it at some point
				ds_list_add(cpu_moves, eInput.Item);
				if (_dx[_highest_idx] < 0) ds_list_add( cpu_moves, eInput.Left);
				if (_dx[_highest_idx] > 0) ds_list_add( cpu_moves, eInput.Right);
				if (_dy[_highest_idx] < 0) ds_list_add( cpu_moves, eInput.Up);
				if (_dy[_highest_idx] > 0) ds_list_add( cpu_moves, eInput.Down);
				current_step = 4; // skip to movement step
				return true;
			}
		#endregion
		#region Exploders
		case unit.exploder_x:
		case unit.exploder_t:
			var _dx = [-1, 1, 1, -1];
			var _dy = [-1, 1, -1, 1];
			if (player.item == unit.exploder_t) {
				_dx = [-1, 1, 0, 0];
				_dy = [0, 0, -1, 1];
			}
			var _total_value = 0;
			
			for (var i = 0; i < 4; i++) {
				var _val = 0;
				var _tx = player_gridx + _dx[i];
				var _ty = player_gridy + _dy[i];
				while (_tx >= 0 and _tx <= 7 and _ty >= 1 and _ty <= 8) {
					var _here = grid[# _tx, _ty];
					if (unit_instance_is_valid(_here)) {
						if		(_here.is_big)   _val += 3;
						else if (_here.is_enemy) _val += 2;
						else if (_here.is_block) _val += 1;
						else if (_here.is_heal)  _val -= 1;
					}
					_tx += _dx[i];
					_ty += _dy[i];
				}
				_total_value += _val;
			}
			var _cap = (player.item == unit.exploder_x) ? 14 : 16;
			if (_total_value >= _cap) { // 7 enemies for "x", 8 enemies for "+"
				ds_list_add(cpu_moves, eInput.Item);
				cpu_item_cooldown = 2; // don't rapid fire
				current_step = 4; // skip to movement step
				return true;
			}
		break;
		#endregion
		#region Teleporter
		case unit.vs_teleporter:
			var _val = 0;
			var _tx = player_gridx;
			var _ty = player_gridy;
			for (var xx = _tx - 1; xx <= _tx + 1; xx++) {
				for (var yy = _ty - 1; yy <= _ty + 1; yy++) {
					var _here = grid[# xx, yy];
					if (unit_instance_is_valid(_here)) {
						if		(_here.is_enemy) _val += 2;
						else if (_here.is_block) _val += 1;
						else if (_here.is_heal)  _val -= 2;
					}
				}
			}
			if (_val >= 8) { // 4 enemies at least (half of 3x3 area)
				ds_list_add( cpu_moves, eInput.Item);
				cpu_item_cooldown = 2; // don't rapid fire
				current_step = 4; // skip to movement step
				return true;
			}
		break;
		#endregion
		#region Other VS items
		// use these at random, since they don't involve our grid
		// the longer you don't use them the higher the chance of using it
		case unit.vs_geyser:
		case unit.vs_shuffle:
		case unit.vs_bomber:
		case unit.vs_transmogrify:
		case unit.vs_confuser:
		case unit.vs_freezer:
		case unit.vs_junk:
		case unit.vs_slamvil:
		case unit.vs_zorix:
			var _rng = irandom(100);
			if (_rng < cpu_item_chance or is_netplay_vm_test) {
				ds_list_add(cpu_moves, eInput.Item);
				current_step = 4; // skip to movement step
				cpu_item_chance = 0; // 0 chance to use it next turn
				cpu_item_cooldown = 7 + irandom(15);
				return true;
			}
			cpu_item_chance += 4;
		break;
		#endregion
	}
	return false;
}
