/// @description See if we should use our active ability. Some abilities are for moving around and handled in cpu_ability_move() instead.
function cpu_ability_use() {
	// don't use any inside the shop
	if (specific_prefab_loaded != "game") return false;
	if (player.transmog_turns) return false;
	// don't, if ability using is on cooldown
	if (cpu_ability_cooldown > 0 and cpu_use_ability_cooldown) { 
		cpu_ability_cooldown -= 1; 
		return false; 
	}
	
	var _player_hp2 = (player.hp > 2);
	
	if (player.is_modded) {
		cpu_ability_used = false;
		mod_run_program(player.program, player.program_folder, "cpu_ability_use");
		if (cpu_ability_used) return true;
	}
	
	// A skills
	#region King Knight's bash
	if (_player_hp2 and has_behavior(player, "active_bash")) {
		var _dx = [-1, 1, 0];
		var _dy = [0, 0, 1]; // never bash upwards
		var _highest = noone;
		var _highest_idx = noone;
		
		for (var i = 0; i < 3; i++) {
			var _val = 0;
			var _tx = player_gridx + _dx[i];
			var _ty = player_gridy + _dy[i];
			var _distance = 0;
			while (_tx >= 0 and _tx <= 7 and _ty >= 1 and _ty <= 8) {
				var _here = grid[# _tx, _ty];
				if (unit_instance_is_valid(_here)) {
					if (_here.is_enemy and cpu_player_attack(player, _here, blessings) + _distance >= _here.hp) {
						var _tile = cpu_grid[# _tx, _ty]; // get the value calculated in cpu_scan_tile()
						if (_tile != noone) {
							_val += _tile[2];
						} else {
							_val += 10;
						}
					} else if (_here.is_block and cpu_player_attack(player, _here, blessings) + _distance >= _here.hp) { // blocks are not as worth it
						var _tile = cpu_grid[# _tx, _ty];
						if (_tile != noone) _val += floor(_tile[2] * 0.5);
					} else { 
						_val = -5; // nothing of interest
					} 
					break;
				} else {
					_distance++;
					_tx += _dx[i];
					_ty += _dy[i];
				}
			}
			if (_val > _highest and _distance > 0) {
				_highest_idx = i;
				_highest = _val;
			}
		}
		if (_highest >= 8 and _distance > 1) { // 4 enemies at least
			ds_list_add(cpu_moves, eInput.Special);
			if (_dx[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Left);
			if (_dx[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Right);
			if (_dy[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Up);
			if (_dy[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Down);
			current_step = 4; // skip to movement step
			return true;
		}
	}
	#endregion
	#region Tinker Knight's mech
	if (player.metal > 5 and !player.tinker_mech_form_enabled and has_behavior(player, "active_mech")) {
		// activate on low HP, or when we have a lot of metal
		if (player.hp < 2 or player.metal >= 10) {
			ds_list_add(cpu_moves, eInput.Special);
			current_step = 4; // skip to movement step
			return true;
		}
	}
	#endregion
	#region Black Knight's rage
	if (player.black_knight_boost < 5 and chain_meter > 144 + (player.hpmax > 3) * 144 and player.hp >= player.hpmax and has_behavior(player, "active_gempower")) {
		repeat floor(chain_meter/144) ds_list_add(cpu_moves, eInput.Special);
	}
	#endregion
	#region Enchantress blast
	if (_player_hp2 and has_behavior(player, "active_boom")) {
		var _dx = [-1, 1, 0, 0];
		var _dy = [0, 0, -1, 1];
		var _total_value = 0;
		for (var i = 0; i < 4; i++) {
			var _tx = player.gridx + _dx[i];
			var _ty = player.gridy + _dy[i];
			var _unit = grid[# _tx, _ty];
			if (unit_instance_is_valid(_unit)) {
				if (_unit.is_heal) { 
					_total_value -= 2; // not really that nice to take down potions
				} else if (!_unit.is_corpse) {
					if (_unit.hp > 1 and cpu_player_attack(player, _unit, blessings) + 1 >= _unit.hpmax) { // if we'll kill it
						_total_value += _unit.cpu_chain_size * _unit.hpmax; 
					} else {
						_total_value += _unit.cpu_chain_size;
					}
				}
			}
		}
		if (_total_value >= 8) {
			ds_list_add(cpu_moves, eInput.Special);
			current_step = 4; // skip to movement step
			return true;
		}
	}
	#endregion
	#region Chester's shop
	if (cpu_chester_uses < vs_difficulty 
		and ability_chester_can_do(player, true)
		and (player_id > 1 ? p2_money : p1_money) >= (8000 + 1000 * ds_list_size(blessings))
		and vs_mode != VERSUS_MODE.GEM_RACE
	) {
		// don't use ability, if the shop is empty
		if (shop_items == noone or ds_list_empty(shop_items)) return false; 
		var _relic_count = 0;
		for (var i = ds_list_size(shop_items) - 1; i >= 0; i--) {
			if (shop_items[| i] != noone) _relic_count++;
		}
		if (_relic_count <= 0) return false;
		ds_list_add(cpu_moves, eInput.Special);
		current_step = 4; // skip to movement step
		cpu_ability_cooldown = 30;
		return true;
	}
	#endregion
	#region Mona's potion explosion
	if ((_player_hp2 or has_blessing(blessings, blessing.bomb_resistance)) and has_behavior(player, "active_potion_boom")) {
		var _dx = [-1, 1, 0, 0];
		var _dy = [0, 0, 1, -1];
		var _highest = noone;
		var _highest_idx = noone;
		var _unit_list = ds_list_create();
		
		var _has_big_bomb = has_blessing(blessings, blessing.bomb_range);
		var _damage = 2 + has_blessing(blessings, blessing.potion_extra_heal) + (has_blessing(blessings, blessing.potion_extra_atk) and player.extra_damage_from_potion);
		_damage += has_blessing(blessings, blessing.poison_strike);
		
		for (var i = 0; i < 4; i++) {
			var _tx = player_gridx + _dx[i];
			var _ty = player_gridy + _dy[i];
			var _value = 0;
			ds_list_clear(_unit_list);
			
			while (_tx >= 0 and _tx <= 7 and _ty >= 1 and _ty <= 8) {
				var _here = grid[# _tx, _ty];
				if (unit_instance_is_valid(_here) and _here.is_potion) {
					// сheck the surroundings for unique units
					for (var ii = -1 - _has_big_bomb; ii <= 1 + _has_big_bomb; ii++) {
						for (var ee = -1 - _has_big_bomb; ee <= 1 + _has_big_bomb; ee++) {
							if (ii != 0 or ee != 0) {
								var _unit = grid[# _tx + ii, _ty + ee];
								// if it exists and we haven't added it yet
								if (unit_instance_is_valid(_unit) and ds_list_find_index(_unit_list, _unit) < 0) {
									if (_unit.is_enemy) {
										_value += 1;
										if (_unit.hp <= _damage) _value += _unit.hp;
										if (_unit.cpu_chain_size < 3) {
											_value += 1;
										} else {
											_value -= 3;
										}
									} else if (_unit.is_potion) _value -= 1;
									else if (_unit.is_block) _value += 1;
									else if (unit_is_item(_unit.unit_type)) _value -= 5;
									// don't process is twice
									ds_list_add(_unit_list, _unit);
								}
							}
						}
					}
				}
				_tx += _dx[i];
				_ty += _dy[i];
			}
			if (_value > _highest and ds_list_size(_unit_list) > 3) {
				_highest_idx = i;
				_highest = _value;
			}
		}
		ds_list_destroy(_unit_list);
		
		if (_highest >= 8) {
			ds_list_add(cpu_moves, eInput.Special);
			if (_dx[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Left);
			if (_dx[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Right);
			if (_dy[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Up);
			if (_dy[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Down);
			current_step = 4; // skip to movement step
			return true;
		}
	}
	#endregion
	
	// B skills
	#region Shovel Knight's pogo
	if (has_behavior(player, "active_pogo")) {
		var _pogo = noone
		with (oShovel_knight_pogo) if (owner == other.player) _pogo = id;
		if (_pogo != noone) { // cancel if we're mid-pogo
			return cpu_shovel_b_try_cancel(_pogo);
		} else if (player.gridy < GRID_HEIGHT-2 and player.hp >= 4) { // only start pogo jumping when healthy
			var _value = 0;
			var _added_damage = 0;
			var _different_units = 0;
			var _hp = player.hp;
			var _prev_unit = noone;
			// abort if the Ceiling Crusher or a wall is above us
			var _above = grid[# player.gridx, player.gridy - 1];
			if (unit_instance_is_valid(_above) and (_above.is_wall or _above.unit_type == unit.crusher_block)) return false;
			// check if we can combine multiple kills in this row:
			for (var e = player.gridy + 1; e < GRID_HEIGHT; e++) {
				var _unit = grid[# player.gridx, e];
				if (instance_is_valid(_unit)) {
					if (_unit.is_enemy) {
						if (_unit.unit_type == _prev_unit) continue;
						_different_units += 1;
						_prev_unit = _unit.unit_type;
						
						var _damage = cpu_player_attack(player, _unit, blessings) + _added_damage;
						var _retali = cpu_unit_retaliate(player, _unit, blessings, _damage);
						
						// check if can we kill it, without dying ourselves
						if _unit.is_explodes or _unit.is_wall or _unit.info.untouchable or _unit.phased or _unit.invincible_side[1] < 0
						or (_unit.electrified and !has_blessing(blessings, blessing.ignore_electricity)
						or (has_modifier(curse.no_loners, player_id) && _unit.cpu_chain_size <= 1)) {
							break; // can't go past this unit
						}
						else if (_damage > 0 and ceil(_unit.hp / _damage) * _damage >= _unit.hp) and (_retali == 0 or (clamp(ceil(player.hp / _retali)-1, 0, 10)*_retali < player.hp)) {
							_value += _unit.cpu_chain_size;
							if (_retali > 0) _hp -= clamp(ceil(player.hp / _retali)-1, 0, 10) * _retali;
							_added_damage = 1;
						} else { 
							break; // we'll die
						}
					} else if (_unit.is_heal) {
						if (_hp < player.hpmax) { 
							_value += _unit.heal_value;
							_hp += _unit.heal_value;
						}
					} else if (_unit.is_block) {
						_value += 1 + _added_damage;
					} else if (_unit.is_explodes or _unit.invincible) { 
						_value = -100; 
						break; 
					}
				}
			}
			// use pogo
			if (_value >= 3 and _different_units > 1) {
				ds_list_add(cpu_moves, eInput.Special);
				current_step = 4; // skip to movement step
				return true;
			}
		}
	}
	#endregion
	#region King Knight's joustus
	if (!is_undefined(player.joustus_deck) and has_behavior(player, "active_joustus")) {
		var _best_card = noone;
		var _best_value = 0;
		// loop through our deck and find the best card to use
		for (var i = ds_list_size(player.joustus_deck) - 1; i >= 0; i--) {
			var _card = player.joustus_deck[| i];
			var _value = -floor(i * 0.5); // the further we need to scroll, the less valuable the option
			
			switch (_card[5]) {
				case joustus_power_heal:
					if (player.hp < player.hpmax) _value += 2;
					if (player.hp <= 2)			  _value += 5;
				break;
				
				case joustus_power_bomb:
					// don't use it we'll die
					if (player.hp <= 3 and !has_blessing(blessings, blessing.bomb_resistance) and !has_blessing(blessings, blessing.bombvest)) _value = -100;
				case joustus_power_freeze:
					// use it closer to the center of the grid
					_value += (5 - abs(4 - player.gridx)) + (5 - abs(4 - player.gridy));
				break;
				
				case joustus_power_poison:
					// only use it when high on hp
					if (player.hp >= 5) _value += 2;
					if (player.hp > 5)	_value += 5;
				break;
				
				case joustus_power_rock:
					// use it at random when healthy, hopefully you dodge it
					if (player.hp >= 5) _value += irandom(10);
				break;
			}
			
			// check for any arrows and its value
			var _dx = [-1, 0, 1, 0];
			var _dy = [0, -1, 0, 1];
			for (var c = 1; c < 5; c++) {
				if (_card[c] == noone) continue;
				// check value of attacking this unit
				var _tx = player.gridx + _dx[c - 1];
				var _ty = player.gridy + _dy[c - 1];
				var _unit = grid[# _tx, _ty];
				if (unit_instance_is_valid(_unit) and !_unit.is_corpse and _unit.unit_type != unit.crusher_block) {
					if (_unit.is_heal) {
						_value -= 2; // not really that nice to take down potions
					} else if (_unit.hp <= 1) {
						_value += 1; // we aren't interested in taking down hp1 units, since we can just bump them
					} else {
						var _damage = 2;
						switch (_card[c]) {
							case joustus_arrow:  _damage = 2; break;
							case joustus_arrow2: _damage = 4; break;
							case joustus_arrow3: _damage = 6; break;
							
							case joustus_arrow_bomb: _damage = 2; break;
							case joustus_arrow_gear: _damage = 2; break;
						}
						
						if (_damage >= _unit.hpmax) {
							// we'll kill the unit
							_value += _unit.cpu_chain_size * 2 + (_card[c] == joustus_arrow_bomb) * 5;
							if (_unit.cpu_chain_size >= 3) { // a chain gives a card
								if (_unit.is_block) {
									_value -= 7; // but we don't want chains of blocks
								} else {
									_value += 5; 
								}
							}
						} else _value += _unit.cpu_chain_size;
					}
				}
			}
			if (_value > _best_value) {
				_best_value = _value;
				_best_card	= i;
			}
		}
		if (_best_value > 5) { // use the card
			ds_list_add(cpu_moves, eInput.Special);
			// direction (find card)
			var _left_card = ds_list_size(player.joustus_deck) - _best_card;
			if (_left_card < _best_card) {
				repeat (_left_card) ds_list_add(cpu_moves, eInput.Left);
			} else {
				repeat (_best_card) ds_list_add(cpu_moves, eInput.Right);
			}
			ds_list_add(cpu_moves, eInput.Up);
			current_step = 4; // skip to movement step
			return true;
		}
	}
	#endregion
	#region Specter Knight's slice
	if (player.hp > 2 and has_behavior(player, "active_slice")) {
		var _dx = [-1, 1, 0];
		var _dy = [0, 0, -1];
		var _highest = noone;
		var _highest_idx = noone;
		
		for (var i = 0; i < 3; i++) {
			var _val = 0;
			var _tx = player_gridx + _dx[i];
			var _ty = player_gridy + _dy[i];
			var _spots = 0;
			var _free_spot_on_end = false;
			// find out how many units can we slice through
			while (_tx >= 0 and _tx <= 7 and _ty >= 1 and _ty <= 8)	{
				var _here = grid[# _tx, _ty];
				if (unit_instance_is_valid(_here)) { 
					_spots++; 
				} else {
					_free_spot_on_end = true;
					break;
				}
				_tx += _dx[i];
				_ty += _dy[i];
			}
			// check the area again, this time counting total attack value
			if (_free_spot_on_end and _spots > 1) {
				var _tx = player_gridx + _dx[i];
				var _ty = player_gridy + _dy[i];
				while (_tx >= 0 and _tx <= 7 and _ty >= 1 and _ty <= 8) {
					var _here = grid[# _tx, _ty];
					if (unit_instance_is_valid(_here)) {
						if ((_here.is_enemy or _here.is_block) and cpu_player_attack(player, _here, blessings) + _spots - 1 >= _here.hp) {
							var _tile = cpu_grid[# _tx, _ty]; // get the value calculated in cpu_scan_tile()
							if (_tile != noone) {
								_val += _tile[2]; 
							} else {
								_val += 5;
							}
						}
						else _val = -2; // hitting nothing of interest, at least it boosts damage though
					} else break;
					_tx += _dx[i];
					_ty += _dy[i];
				}
				if (_val > _highest and _spots > 1) {
					_highest_idx = i;
					_highest = _val;
				}
			}
		}
		if (_highest >= 4) { // 2 enemies at least
			ds_list_add(cpu_moves, eInput.Special);
			if (_dx[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Left);
			if (_dx[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Right);
			if (_dy[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Up);
			if (_dy[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Down);
			current_step = 4; // skip to movement step
			return true;
		}
	}
	#endregion
	#region Tinker Knight's mobile gear
	if (player.metal >= 5 and has_behavior(player, "active_gear")) {
		// activate on low HP, or when we have a lot of metal
		if (player.hp < 2 or irandom(100) < 25) {
			ds_list_add(cpu_moves, eInput.Special);
			ds_list_add(cpu_moves, eInput.Special);
			current_step = 4; // skip to movement step
			return true;
		}
	}
	#endregion
	#region Polar Knight's spinwulves
	if (has_behavior(player, "puppies")) {
		var _can_spawn = false;
		for (var i = array_length(polar_knight_spinwulves) - 1; i >= 0; i--) {
			if (polar_knight_spinwulves[i] >= 4) { 
				_can_spawn = true; 
				break; 
			}
		}
		if (_can_spawn and irandom(100) < 25) {
			// choose a semi-random direction
			var _directions = ds_list_create();
			if (player.gridx < 3) ds_list_add(_directions, eInput.Right);
			if (player.gridx > 4) ds_list_add(_directions, eInput.Left);
			if (player.gridy < 5) ds_list_add(_directions, eInput.Down);
			if (player.gridy > 7) ds_list_add(_directions, eInput.Up);
			if (ds_list_empty(_directions)) {
				ds_list_destroy(_directions);
			} else {
				ds_list_shuffle(_directions);
				ds_list_add(cpu_moves, eInput.Special);
				ds_list_add(cpu_moves, _directions[| 0]);
				ds_list_destroy(_directions);
				current_step = 4; // skip to movement step
				return true;
			}
		}
	}
	#endregion
	#region Black Knight's meteors
	if (chain_meter > 144 * 2 and player.hp >= player.hpmax and has_behavior(player, "meteor_shower")) {
		repeat floor(chain_meter / 144) ds_list_add(cpu_moves, eInput.Special);
	}
	#endregion
	#region Enchantress fireballs
	if (_player_hp2 and has_behavior( player, "active_fireball")) {
		var _dx = [-1, 1, 0, 0];
		var _dy = [0, 0, 1, -1];
		var _highest = noone;
		var _highest_idx = noone;
		var _highest_distance = -1;
		
		for (var i = 0; i < 4; i++) {
			var _val = 0;
			var _tx = player_gridx + _dx[i];
			var _ty = player_gridy + _dy[i];
			var _distance = 0;
			while (_tx >= 0 and _tx <= 7 and _ty >= 1 and _ty <= 8) {
				var _here = grid[# _tx, _ty];
				if (unit_instance_is_valid(_here)) {
					if (_here.is_enemy and _distance >= _here.hp) {
						var _tile = cpu_grid[# _tx, _ty]; // get the value calculated in cpu_scan_tile()
						if (_tile != noone) { 
							_val += _tile[2]; 
						} else { 
							_val += 10;	
						}
					} else if (_here.is_block and _distance >= _here.hp) { // blocks are not as worth it
						var _tile = cpu_grid[# _tx, _ty];
						if (_tile != noone) {
							_val += floor(_tile[2] * 0.5); 
						}
					} else { // hitting nothing of interest
						_val = -5; 
					} 
					break;
				} else {
					_distance++;
					_tx += _dx[i];
					_ty += _dy[i];
				}
			}
			if (_val > _highest and _distance > 0) {
				_highest_idx = i;
				_highest = _val;
				_highest_distance = _distance;
			}
		}
		if (_highest >= 4 and _distance > 1) { // 4 enemies at least
			ds_list_add(cpu_moves, eInput.Special);
			if (_dx[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Left);
			if (_dx[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Right);
			if (_dy[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Up);
			if (_dy[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Down);
			current_step = 4; // skip to movement step
			return true;
		}
	}
	#endregion
	#region Chester's dual wield
	if (has_behavior(player, "dual_wield")
		and ((player.item <= 0 and player.item2 > 0)
		or (cpu_item_tier(player.item) < cpu_item_tier(player.item2))
	)) { // swap items
		ds_list_add(cpu_moves, eInput.Special);
		current_step = 4; // skip to movement step
		return true;
	}
	#endregion
	#region Mona's potion throw
	if (player.potions > 0 and has_behavior(player, "collect_potions")) {
		var _has_extra_heal = has_blessing(blessings, blessing.potion_extra_heal);
		// drink a potion
		if (player.hpmax - player.hp >= 2 + _has_extra_heal) {
			ds_list_add(cpu_moves, eInput.Special);
			ds_list_add(cpu_moves, eInput.Up);
			current_step = 4; // skip to movement step
			return true;
		}
		var _has_extra_atk  = (has_blessing(blessings, blessing.potion_extra_atk) and player.extra_damage_from_potion);
		var _is_poisonous	= has_blessing(blessings, blessing.poison_strike) or has_modifier(curse.all_poisonous, player_id);
		
		var _dx = [-2, 2, 0];
		var _dy = [0, 0, 2];
		var _highest = noone;
		var _highest_idx = noone;
		
		for (var i = 0; i < 3; i++) {
			var _val = 0;
			var _tx = player_gridx + _dx[i];
			var _ty = player_gridy + _dy[i];
			var _here = grid[# _tx, _ty];
			if (unit_instance_is_valid(_here) and !_here.is_body and _here.hp > 1 and (_here.is_enemy or _here.is_block)) {
				_val += _here.cpu_chain_size;
				if (_here.hp <= 2 + _has_extra_atk + _has_extra_heal + _is_poisonous) _val += _here.hp;
			}
			if (_val > _highest) {
				_highest_idx = i;
				_highest = _val;
			}
		}
		if (_highest >= 7) {
			ds_list_add(cpu_moves, eInput.Special);
			if (_dx[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Left);
			if (_dx[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Right);
			if (_dy[_highest_idx] < 0) ds_list_add(cpu_moves, eInput.Up);
			if (_dy[_highest_idx] > 0) ds_list_add(cpu_moves, eInput.Down);
			// lower the value of the targeted unit
			var _tx = player_gridx + _dx[_highest_idx];
			var _ty = player_gridy + _dy[_highest_idx];
			var _here = grid[# _tx, _ty];
			if (unit_instance_is_valid(_here)) _here.cpu_added_value = -10;
			cpu_ability_cooldown = 2; // don't throw a potion again in the next 2 turns
			current_step = 4; // skip to movement step
			return true;
		}
	}
	#endregion
	#region Prism Knight's clones
	if (player.hp >= 5 and has_behavior(player, "active_clone")) {
		// count amount of active clones
		var _clones = 0;
		with (oUnit) if (is_clone and grid_master == other.id) _clones += 1;
		
		if (_clones < 7) {
			var _dx = [-1, 1, 0, 0];
			var _dy = [0, 0, -1, 1];
			
			switch (irandom(4)) { // randomize the order in which we handle directions
				case 0: _dx = [1, -1, 0, 0];
						_dy = [0, 0, 1, -1]; break;
				case 1: _dx = [0, -1, 1, 0];
						_dy = [1, 0, 0, -1]; break;
				case 2: _dx = [0, 1, -1, 0];
						_dy = [-1, 0, 0, 1]; break;
				case 3: _dx = [0, 0, -1, 1];
						_dy = [-1, 1, 0, 0]; break;
				case 4: _dx = [0, 0, 1, -1];
						_dy = [1, -1, 0, 0]; break;
			}
			
			for (var i = 0; i < 3; i++) {
				var _tx = player_gridx + _dx[i];
				var _ty = player_gridy + _dy[i];
				var _here = grid[# _tx, _ty];
				if (!unit_instance_is_valid(_here)) { // make sure the space is empty
					ds_list_add(cpu_moves, eInput.Special);
					if (_dx[i] < 0) ds_list_add(cpu_moves, eInput.Left);
					if (_dx[i] > 0) ds_list_add(cpu_moves, eInput.Right);
					if (_dy[i] < 0) ds_list_add(cpu_moves, eInput.Up);
					if (_dy[i] > 0) ds_list_add(cpu_moves, eInput.Down);
					break;
				}
			}
		}
	}
	#endregion
	
	return false;
}

/// @description			Check if we should cancel our pogo.
/// @param {Id.Instance}	_pogo						The oShovel_knight_pogo instance.
/// @returns {Bool}
function cpu_shovel_b_try_cancel(_pogo) {
	var _blessings = get_blessings_for_grid(id);
	
	for (var i = player.gridy; i < GRID_HEIGHT; i++) {
		var _next_unit = grid[# player.gridx, i];
		// stop when we are low on HP
		if (unit_instance_is_valid(_next_unit) and _next_unit != player) {
			// the unit is not worth attacking
			if (_next_unit.is_explodes or _next_unit.is_wall
			or (_next_unit.info.untouchable and (!_next_unit.is_block or !has_blessing(_blessings, blessing.digger)))
			or _next_unit.phased
			or (_next_unit.electrified and !has_blessing(_blessings, blessing.ignore_electricity))
			or (has_modifier(curse.no_loners, player_id) && _next_unit.cpu_chain_size <= 1)) {
				_pogo.cpuSpecial = true;
				return true;
			} else if (_next_unit.is_enemy) {
				var _damage = cpu_player_attack(player, _next_unit, _blessings);
				// we will die
				if (_damage < _next_unit.hp) and (player.hp <= cpu_unit_retaliate(player, _next_unit, _blessings, _damage)) {
					_pogo.cpuSpecial = true;
					return true;
				} else return false;
			} else return false;
		}
	}
	current_step = -7;
	return false;
}
