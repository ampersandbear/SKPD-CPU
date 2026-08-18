/// @description Runs every step from oGrid.
function cpu_step() {
	// return if Grid is calculating a turn, otherwise may cause a stutter
	with (oGrid) if (prev_turn_timer == 0) return;
	// return if the player is dead or respawning
	if (!instance_is_valid(player) or player.stun > 0 or player_is_respawning or !game_ready) {
		current_step = 0;
		// also cancel shovel drop
		if (player.gridy < GRID_HEIGHT-1 and has_behavior(player, "active_pogo")) {
			var _pogo = noone
			with (oShovel_knight_pogo) if (owner == other.player) _pogo = id;
			if (_pogo != noone) cpu_shovel_b_try_cancel(_pogo);
		}
		return;
	}
	if (player.is_modded) with (player) mod_run_program(program, program_folder, "cpu_pre_step");
	
	var _prev_step = current_step;
	if (!cpu_ignore_default_step_code) {
		switch (current_step) {
			case 0: // first, checks
				if (cpu_reset_on_inactivity) { 
					cpu_inactive += 1;
					if (cpu_inactive > cpu_inactivity_threshold or player.frozen > 0) { 
						current_step = 4; // skip te rest of the step logic
						// then cancel item & ability aiming
						if (player.item_aiming	 and ds_list_find_index(cpu_moves, eInput.Item) < 0)	ds_list_add(cpu_moves, eInput.Item);
						if (player.ability_using and ds_list_find_index(cpu_moves, eInput.Special) < 0) ds_list_add(cpu_moves, eInput.Special);
						// move randomly
						ds_list_add(cpu_moves, choose(eInput.Left, eInput.Right, eInput.Up, eInput.Down));
						return;
					}
				}
				// force us out of aiming if we are aiming
				if (player.item_aiming	 and ds_list_find_index(cpu_moves, eInput.Item)	   < 0) { ds_list_add( cpu_moves, eInput.Item);	  current_step = 4; return; }
				if (player.ability_using and ds_list_find_index(cpu_moves, eInput.Special) < 0) { ds_list_add( cpu_moves, eInput.Special); current_step = 4; return; }
			
				// clear tiles
				ds_list_clear(cpu_tiles);
				ds_grid_clear(cpu_bomb_grid, true);
				ds_grid_clear(cpu_grid, noone);
				ds_grid_clear(cpu_grid_check, false);
			
				// keep track of previosuly visited tiles
				if (cpu_prevent_backtracking) {
					var _size = ds_list_size(cpu_prev);
					var _backtracks_amount = 0;
					for (var i = 0; i < _size; i++) {
						var _arr = cpu_prev[| i];
						if (_arr[0] == player.gridx and _arr[1] == player.gridy) _backtracks_amount++;
					}
					if (_size > 6) ds_list_delete(cpu_prev, 0);
					ds_list_add(cpu_prev, [player.gridx, player.gridy]);
				}
			
				// reset variables
				cpu_ignore_bomb_check = false;
				cpu_ceiling_crusher = (instance_is_valid(ceiling_crusher)) ? ceiling_crusher.gridy : 0;
				if		(cpu_terrorpin_value > 0) cpu_terrorpin_value -= 1;
				else if (cpu_terrorpin_value < 0) cpu_terrorpin_value += 1;
				
				// set these values to use on the scan later
				player_type				= player.unit_type;
				player_hp				= player.hp;
				player_hpmax			= player.hpmax;
				player_gridx			= player.gridx;
				player_gridy			= player.gridy;
				blessings				= get_blessings_for_instance(player);
				player_hates_potions	= has_behavior(player, "pot_weak");
				player_keys				= has_blessing(blessings, blessing.skeleton_key) ? 5 : player.keys;
				cpu_mole_b				= is_mole_knight_b(player, id);
				cpu_beefto				= has_behavior(player, "beefto_time");
				has_two_step			= has_behavior(player, "fast_move") or has_modifier(curse.spinwulf_spirit, player_id);
				pocket_portal			= has_blessing(blessings, blessing.shortcut) and !prefab_is_shop(specific_prefab_loaded);
				push_attack				= has_modifier(curse.push_attack, player_id);
				
				var _grid = grid;
				var _gm = id;
				var _cpu_backtracks_check = cpu_prevent_backtracking;
				// add the following values to all units:
				with (oUnit) {
					// ignore other grid
					if (grid_master != _gm) continue;
					if (_cpu_backtracks_check and _backtracks_amount >= 2 and cpu_added_value > 0) cpu_added_value = 0;
					init_cpu_variables(_grid, cpu_added_value);
					// terrorpin hack
					if (unit_type == unit.terrorpin) cpu_added_value = other.cpu_terrorpin_value;
				}
			break;
		
			case 1: // scan all tiles
				if (player.gridy >= 0) {
					// scan the whole board for mole A and B:
					if (cpu_mole_b or has_behavior(player, "active_burrow")) {
						for (var i = 0; i < GRID_WIDTH; i++) {
							for (var j = 0; j < GRID_HEIGHT; j++) {
								cpu_scan_tile(i, j, 0, i == player.gridx and j == player.gridy, false, true);
							}
						}
					} else { // else, start with the player tile and proceed recursively
						cpu_scan_tile(player.gridx, player.gridy, 0, true);
					}
				}
			break;
		
			case 2: // use items / abilities
				if (player.item > 0 and cpu_item_use()) return;
				if (cpu_ability_use()) return;
				
				var _gm = id;
				var _grid = cpu_grid;
				var _lower = -5 - (player_hp <= 3) * 5 + has_blessing(blessings, blessing.bomb_resistance) * 5 + has_blessing(blessings, blessing.bombvest) * 10;
				cpu_bomb_is_exploding = false;
				cpu_player_is_in_bomb_range = false;
				cpu_player_is_in_big_unit_attack_range = false;
				// mark all "danger" tiles to step in (i.e. exploding bomb range)
				if (cpu_attempt_to_get_out_of_exploding_bomb_range) with (oUnit)
				{
					if (grid_master != _gm or !is_explodes or !primed) continue;
					// ignore friendlies
					if (has_behavior(id, "friendly")) continue;
					var _bomb_size = real(unit_type_behavior_value(unit_type, "explodes"));
					if (is_bomb) {
						if (has_blessing(get_blessings_for_grid(grid_master), blessing.bomb_range)) _bomb_size++;
						if (has_modifier(curse.bomb_mayhem, grid_master.player_id))	_bomb_size--;
						if (_bomb_size < 1) _bomb_size = 1;
					}
					for (var ii = max(0, gridx - _bomb_size); ii <= min(7, gridx + _bomb_size); ii++) {
						for (var oo = max(0, gridy - _bomb_size); oo <= min(8, gridy + _bomb_size); oo++) {
							other.cpu_bomb_grid[# ii, oo] = false; // mark the tile as dangerous
							var _here = other.grid[# ii, oo];
							if (unit_instance_is_valid(_here) and _here.player > 0) other.cpu_player_is_in_bomb_range = true;
							// lower value of tiles in bomb range:
							var _tile = _grid[# ii,oo];
							if (_tile == noone) continue;
							_tile[2] -= _lower;
						}
					}
					other.cpu_bomb_is_exploding = true;
				}
				if (lvl_advanced_biggies and cpu_attempt_to_avoid_enemy_area_attacks) {
					// dodge griffoth and mole minion attacks:
					with (oWarningFloor) if (unit_instance_is_valid(owner) and owner.grid_master == _gm and (object_index == oUnit and (has_behavior(owner, "slams") or has_behavior(owner, "slams_side")))) {
						other.cpu_bomb_grid[# gridx, gridy] = false;
						if (other.player.gridx == gridx and other.player.gridy == gridy) other.cpu_player_is_in_big_unit_attack_range = true;
					}
					// dodge Jar Geenie, Cogslotter and Airship:
					with (pUpdateMe) if ((object_index == oLancerJump or object_index == oLancerRaider) and grid_master == _gm) {
						for (var _x = 0; _x < 2 and gridx + _x < GRID_WIDTH; _x++) {
							for (var _y = 0; _y < 2 and gridy + _y < GRID_HEIGHT; _y++) {
								other.cpu_bomb_grid[# gridx + _x, gridy + _y] = false;
								if (other.player.gridx == gridx + _x and other.player.gridy == gridy + _y) other.cpu_player_is_in_big_unit_attack_range = true;
							}
						}
					}
				}
			break;
		
			case 3: // choose target
				var _highest_value = -1000;
				var _is_volleybomb = (!cpu_ignore_bomb_check and vs_mode == VERSUS_MODE.VOLLEYBOMB);
				var _on_top_of_volleybomb = false;
				var _volleybomb = noone;
				chosen_tile  = noone;
			
				if (_is_volleybomb and cpu_chase_volleybomb) {
					_highest_value = -200;
					with (oLobber) if (spawn_mode == "volleybomb" and grid_master == other.id) _volleybomb = id;
					_is_volleybomb = (_is_volleybomb and _volleybomb != noone and _volleybomb >= -1);
					// check if we aleady are in the voleybomb area
					if (_is_volleybomb and player.gridx + player.is_big >= _volleybomb.left and player.gridx <= _volleybomb.right and player.gridy + player.is_big >= _volleybomb.up and player.gridy <= _volleybomb.down) {
						_on_top_of_volleybomb = true;
					}
				}
				if (has_modifier(curse.no_loners, player_id) and no_loners_check_softlocked(id, player, -1)) {
					_highest_value = -2000; // we don't need a target if we're softlocked with the Extrovert Hat
				}
				var _bomb_resist = (has_blessing(blessings, blessing.bombvest) or has_blessing(blessings, blessing.bomb_resistance));
			
				// find the highest valued tile
				for (var i = ds_list_size(cpu_tiles) - 1; i >= 0; i--) {
					var _tile = cpu_tiles[| i];
					// blur the value of tiles for less strong CPUs
					var _value = _tile[2] * (cpu_level <= 5 ? 0.5 + random(cpu_level*0.1) : 1);
					if (_tile[2] > _highest_value) { // found new best
						// don't move out of volleybomb bounds
						if (_on_top_of_volleybomb and (_tile[0] < _volleybomb.left or _tile[0] > _volleybomb.right or _tile[1] > _volleybomb.down or _tile[1] < _volleybomb.up)) continue;
						if (!cpu_bomb_grid[# _tile[0], _tile[1]] and !_bomb_resist) continue; // don't pick a target inside the expoding bomb range
						_highest_value = _tile[2];
						chosen_tile  = _tile;
					}
				}
				#region Volleybomb override, try to get in range instead
				if (_is_volleybomb and cpu_chase_volleybomb and !_on_top_of_volleybomb) {
					// find landing spots first
					var _list = ds_list_create();
					if (cpu_mole_b) {
						ds_list_add(_list, [_volleybomb.gridx,_volleybomb.gridy]);
					} else {
						for (var i = _volleybomb.gridx - 1; i <= _volleybomb.gridx + 1; i++) {
							for (var e = _volleybomb.gridy - 1; e <= _volleybomb.gridy + 1; e++) {
								if (i < 0 or i > 7 or e < 1 or e > 8) continue; // spot is out of Grid bounds
								var _unit = grid[# i, e];
								if (!unit_instance_is_valid(_unit) or _unit.is_heal) { 
									ds_list_add(_list, [i, e]); // immediately add all empty spots
								} else { // increase value of non-empty spots as well, to try and gravitate towards this area if there are no empty tiles
									var _tile = cpu_grid[# i, e];
									if (_tile == noone) continue;
									_tile[2] += 50;
								}
							}
						}
					}
					// if no landing spots, we need to pick our target again
					if (ds_list_empty(_list)) {
						_highest_value = -10000;
						// find the highest valued tile
						for (var i = ds_list_size(cpu_tiles) - 1; i >= 0; i--) {
							var _tile = cpu_tiles[| i];
							if (_tile[2] > _highest_value) { // found new best
								_highest_value = _tile[2];
								chosen_tile  = _tile;
							}
						}
					} else { // move us there!
						ds_list_shuffle(_list);
						var _pos = _list[| 0];
						chosen_tile = [_pos[0],_pos[1], 10, noone];
					}
					cpu_ignore_bomb_check = true;
					ds_list_destroy(_list);
				}
				chosen_tile_draw = chosen_tile; // debug feature
				#endregion
				
				var _bomb = (cpu_bomb_is_exploding
					and !cpu_ignore_bomb_check
					and cpu_level >= 2
					and !has_blessing(blessings, blessing.bomb_resistance)
					and !has_blessing(blessings, blessing.bombvest)
					and cpu_player_is_in_bomb_range);
					
				if (cpu_player_is_in_big_unit_attack_range and !cpu_ignore_bomb_check) _bomb = true;
				// if no target found
				if (chosen_tile == noone and !_bomb) { 
					// if can't move with the Extrovert Hat - try to move down, let's force ourselves into being surrounded
					if (has_modifier(curse.no_loners, player_id) and !_on_top_of_volleybomb) {
						var _up		= grid[# player_gridx,player_gridy-1];
						var _down	= grid[# player_gridx,player_gridy+1];
						var _left	= grid[# player_gridx-1,player_gridy];
						var _right	= grid[# player_gridx+1,player_gridy];
					
						if (player_gridy < 8 and unit_counts_as_empty(_down)
						and (player_gridy - 1 < 1 or (unit_instance_is_valid(_up) and (_up.gridy < 1 or chain_size_from_unit(_up,2) <= 1)))
						and (player_gridx - 1 < 0 or (unit_instance_is_valid(_left) and (_left.gridy < 1 or chain_size_from_unit(_left,2) <= 1)))
						and (player_gridx + 1 > 7 or (unit_instance_is_valid(_right) and (_right.gridy < 1 or chain_size_from_unit(_right,2) <= 1)))
						) {
							ds_list_clear(cpu_moves);
							ds_list_add(cpu_moves, eInput.Down);
							current_step = 4;
							return;
						}
					}
					// restart CPU
					if (cpu_ignore_bomb_check) { 
						current_step = 3; 
						return; 
					} else if (cpu_level < 5) { 
						current_step = 0; 
						return; 
					} else if !has_modifier(curse.birder, player_id) { // skip the turn for high-level CPUs
						ds_list_clear(cpu_moves); 
						ds_list_add(cpu_moves, eInput.Speed); 
					} 
				} else if (cpu_movement(_bomb, _is_volleybomb, _on_top_of_volleybomb, _volleybomb)) return; // move to the target
			break;
		
			case 4: // execute move(s)
				var _bomb = (cpu_bomb_is_exploding
					and !cpu_ignore_bomb_check
					and cpu_level >= 2
					and !has_blessing( blessings, blessing.bomb_resistance)
					and !has_blessing( blessings, blessing.bombvest)
					and cpu_player_is_in_bomb_range);
			
				// chance of emoting for CPU lvl 10, must be ahead of the player
				if (!is_netplay and instance_number(oBossIntro) < 1 and instance_number(oEmote) < 1 and !_bomb and irandom(100) < 1 + (cpu_level == 10)) {
					randomize();
					if (player.is_vs_king >= 1) {
						make_emote(choose(sEmote_Goofy, sEmote_Floorb, sEmote_Party, sEmote_Googly, sEmote_Shifty, sEmote_Star, sEmote_V), player_id);
						cpu_wait += (55 - cpu_level * 2);
					} else {
						make_emote(choose(sEmote_Ouch, sEmote_Angry, sEmote_Bored, sEmote_Shocked, sEmote_Cyclops, sEmote_Retro), player_id);
						cpu_wait += (45 - cpu_level * 2);
					}
					break;
				}
				var _move = cpu_moves[| 0];
				ds_list_delete(cpu_moves, 0);
				// reset inactive counter
				cpu_inactive = 0;
				// do move
				switch (_move) {
					// directional movement
					case eInput.Left:		kLeft	= true;						break;
					case eInput.Right:		kRight	= true;						break;
					case eInput.Up:			kUp		= true;						break;
					case eInput.Down:		kDown	= true;						break;
					// items / specials
					case eInput.Item:		kItem	= true;						break;
					case eInput.Special:	kSpecial = true;					break;
					case eInput.Speed:		kSpeedPressed = 15; turn_timer = 1; break;
				}
				// handle confusion
				if (player.confused_turns > 0 and !player.ability_using and irandom(100) > cpu_level * 9) {
					if		(kLeft)		{ kRight = true; kLeft  = false; }
					else if (kRight)	{ kLeft  = true; kRight = false; }
					if		(kUp)		{ kDown  = true; kUp	= false; }
					else if (kDown)		{ kUp    = true; kDown  = false; }
				}
				
				if (player.is_modded) with (player) mod_run_program(program, program_folder, "cpu_set_keys");
			break;
		}
	}
	// advance to the next step if we didn't before
	if (_prev_step == current_step) current_step += 1;
	// after a move, wait X steps (cpu_wait)
	if (current_step > cpu_wait) {
		// recalculate cpu_wait (and, if confused, add some dummy time)
		cpu_wait = cpu_wait_base + irandom(cpu_wait_random) + ((player.confused_turns > 0) ? max(0, irandom(30 - floor(cpu_level * 3))) : 0);
		// execute next move
		if (!ds_list_empty(cpu_moves)) {
			current_step = 4;
		} else { // restart
			current_step = 0;
		}
	}
	if (player.is_modded) with (player) mod_run_program(program, program_folder, "cpu_step");
}
