/// @description			Assigns a relative `importance` value to the specified tile, and proceeds with further scanning of the Grid recursively.
/// @param {Id.DsGrid}		_x							The x Grid position to scan.
/// @param {Real}			_y							The y Grid position to scan.
/// @param {Real}			_value						The starting value of the tile.
/// @param {Bool}			_starting_tile				If we started the recursion from this tile.
/// @param {Bool}			_from_portal				If we're considering Pocket Portal for this check.
/// @param {Bool}			_is_mole_knight				If we're checking for Mole B.
/// @returns {Any}
function cpu_scan_tile(_x, _y, _value = 0, _starting_tile = false, _from_portal = false, _is_mole_knight = false) {
	if (cpu_grid_check[# _x,_y]) return; // we have already parced this tile
	if (!pocket_portal and (_x < 0 or _x > 7 or _y < 0 or _y > 8)) return; // tile is out of bounds
	cpu_grid_check[# _x,_y] = true;
	
	if (_starting_tile) { // for starting tile - proceed with the surrounding tiles
		if (_x > 0) cpu_scan_tile(_x - 1, _y); else if (pocket_portal) cpu_scan_tile(7, _y, 0, false, true);
		if (_x < 7) cpu_scan_tile(_x + 1, _y); else if (pocket_portal) cpu_scan_tile(0, _y, 0, false, true);
		if (_y > 1) cpu_scan_tile(_x, _y - 1); else if (pocket_portal and ceiling_crusher == noone) cpu_scan_tile(_x, 8, 0, false, true);
		if (_y < 8) cpu_scan_tile(_x, _y + 1); else if (pocket_portal and ceiling_crusher == noone) cpu_scan_tile(_x, 1, 0, false, true);
		// if the player is mole knight, scan the tile we are currently sitting on
		// otherwise, just return
		if (!is_mole_knight_b( player, id)) return;
	}
	var _unit = grid[# _x, _y];
	// if the tile is empty, check nearby
	if (!unit_instance_is_valid(_unit) or _unit.is_corpse) {
		if (_is_mole_knight) return;
		if (_x > 0) cpu_scan_tile(_x - 1, _y); else if (pocket_portal) cpu_scan_tile(7, _y, 0, false, true);
		if (_x < 7) cpu_scan_tile(_x + 1, _y); else if (pocket_portal) cpu_scan_tile(0, _y, 0, false, true);
		if (_y > 1) cpu_scan_tile(_x, _y - 1); else if (pocket_portal and ceiling_crusher == noone) cpu_scan_tile(_x, 8, 0, false, true);
		if (_y < 8) cpu_scan_tile(_x, _y + 1); else if (pocket_portal and ceiling_crusher == noone) cpu_scan_tile(_x, 1, 0, false, true);
	} else if (_unit.is_clone or _unit.player) {
		if (_is_mole_knight) return;
		if (_x > 0) cpu_scan_tile(_x - 1, _y);
		if (_x < 7) cpu_scan_tile(_x + 1, _y);
		if (_y > 1) cpu_scan_tile(_x, _y - 1);
		if (_y < 8) cpu_scan_tile(_x, _y + 1);
	} else { // something is here! Grade it!
		// we value action closer to the middle of the board higher than the edges (don't want to be stuck in a corner)
		switch (_x) { // column value
			case 0: _value -= 1; break;
			case 1: _value += 0; break;
			case 2: _value += 1; break;
			case 3: _value += 2; break;
			case 4: _value += 3; break;
			case 5: _value += 2; break;
			case 6: _value += 1; break;
			case 7: _value += 0; break;
		}
		switch (_y) { // row value
			case 0: _value -= 5; break;
			case 1: _value -= 2; break;
			case 2: _value -= 1; break;
			case 3: _value += 0; break;
			case 4: _value += 1; break;
			case 5: _value += 2; break;
			case 6: _value += 1; break;
			case 7: _value += 0; break;
			case 8: _value -= 1; break;
		}
		
		var _p_gridx	= player_gridx;
		var _p_gridy	= player_gridy;
		var _p_hp		= player_hp;
		var _p_hpmax	= player_hpmax;
		var _p_type		= player_type;
		var _player		= player;
		var _blessings	= blessings;
		var _cpu_level	= cpu_level;
		var _p_keys		= player_keys;
		var _money		= (player_id == 1) ? p1_money : p2_money;
		var _ccrusher	= cpu_ceiling_crusher;
		var _two_step	= has_two_step and specific_prefab_loaded != "chester";
		var _px_is_odd	= false;
		var _py_is_odd	= false;
		if (_two_step) {
			_px_is_odd = (player_gridx % 2 == 1);
			_py_is_odd = (player_gridy % 2 == 1);
		}
		// analyse the unit
		with (_unit) {
			// only process the ones that match the Grid position (avoids big units extra spaces)
			if (_x != gridx or _y != gridy or player) return;
			if (_two_step) {
				// give more importance to travel distance (the shorter it is, the better)
				_value -= (ceil(point_distance(_p_gridx,_p_gridy, gridx, gridy))-3)*2;
			}
			// the further the unit is, the less we care about it
			var _dx = abs(_unit.gridx - _p_gridx);
			var _dy = abs(_unit.gridy - _p_gridy);
			if (other.pocket_portal) {
				_dx = min(_dx, abs(_dx - GRID_WIDTH));
				_dy = min(_dy, abs(_dy - GRID_HEIGHT));
			}
			_value -= (_dx + _dy) * 2.05; // +0.05 to try and avoid the CPU walking back and forth between two tiles that have the same values
			// prioritize bigger chains
			var _chain_size = cpu_chain_size;
			// added value from previous checks
			_value += cpu_added_value + 2; // 2 offsets the distance value, if you are next to this unit
			// prioritize units that are not falling
			if (prevent_falling_for_x_turns > 0 or !cpu_empty_below) _value += 5;
			
			#region Blocks
			// we should clear them out if they are in big groups or have low HP
			if (is_block) {
				// ignore loners with Extrovert Hat
				if (_chain_size < 2 and has_modifier( curse.no_loners, grid_master.player_id)) { _value = -1000; continue; }
				// bombable blocks can only be taken out with Obsidian Drill
				if (info.untouchable and !has_blessing(_blessings, blessing.digger)) _value = -1000;
				var _bhp = hp;
				// Obsidian Drill also makes them easier to kill
				if (_bhp > 1 and has_blessing(_blessings, blessing.digger)) _bhp = ceil(_bhp * 0.5);
				// Whetstone gives us an incentive to hit it, but not when our attack is boosted
				if (_player.extra_damage_from_block > 0)			   { _value -= 5; _bhp = ceil(_bhp*0.5); }
				else if (has_blessing(_blessings, blessing.whetstone)) { _value += 5; }
				// increase value for low HP blocks
				_value += (_bhp <= 1) + (_bhp <= 3);
				// increase value for chain size
				_value += _chain_size;
				// try to not hit goo blocks when low on HP
				if (has_behavior(id, "goo") and _p_hp <= 2) _value -= 5;
				// Tinker Knight has to collect metal
				if (_player.metal < _player.max_metal and has_behavior(_player, "25%steel")) { 
					_value += 1 + (_player.metal <= 5) * 4 + (_player.metal <= 10) * 2;
				}
				// bonus points for cakes
				if (block_is_cake and _p_hp < _p_hpmax) _value += 1 + (_p_hp <= 2);
				// increased value in case of Hearty Wandy free shot
				if (_p_hp >= _p_hpmax and has_blessing(_blessings, blessing.heart_wand)) _value += 5;
			}
			#endregion
			#region Potions
			// turkey trays, let's open them!
			if (unit_type == unit.turkey_tray) _value += 2;
			// generally, we should heal, but attempt to not overheal
			if (is_heal) {
				// Bonuses from relics
				if (has_blessing(_blessings, blessing.potion_extra_atk)) _value += 2;
				var _extra_heal	= has_blessing(_blessings, blessing.potion_extra_heal);
				// Specter Knight HATES potions
				if (other.player_hates_potions) {
					// Lemonade cancels the damage from potions
					if (_extra_heal) {
						_value += _chain_size;
					} else {
						var _damage = clamp(_chain_size, 1, 3);
						if (_damage  >= _p_hp) { 
							_value -= 100; // completely avoid if it'll kill
						} else {
							_value -= _damage; // the higher damage, the less we want it
							_value += _chain_size - _damage; // the bigger the chain, the more we want it
						}
					}
				} else { // everybody else LOVES 'em
					if (_p_hp >= _p_hpmax) { // ignore when at full HP
						_value -= 10; 
					} else if (_p_hp <= 1) { // desperately need healing
						_value += 20; 
					} else if (_p_hp <= 2) { // a big urgent in healing
						_value += 10;
					} else if (_p_hpmax - _p_hp >= (heal_value + _extra_heal) * _chain_size) {
						_value += 7; // prioritize if it's just the right amount of healing
					} else { 
						_value += 2; // not in a rush, but it's nice
					}
					// Black Knight should try to avoid them if he has any active boosts
					if (_player.black_knight_boost > 0) _value -= 5;
				}
			}
			#endregion
			#region Enemies
			if (is_body) _value = -100; // Grapps bodies must be ignored
			// we should clear bigger chains or easy enemies first
			if (is_enemy and !is_big) {
				// ignore loners with the Extrovert Hat
				if (_chain_size < 2 and has_modifier(curse.no_loners, grid_master.player_id)) { _value = -1000; continue; }
				// If Goo Bumpin' Bonnet is equipped, ignore enemies on conveyor belt
				if (other.push_attack) {
					var _trap = instance_place(x, y, oTrap);
					if (_trap != noone && _trap.tile_type == stile.cbelt) {
						if ((_p_gridx < gridx && _p_gridy == gridy && _trap.image_angle == 180) 
						|| (_p_gridx > gridx && _p_gridy == gridy && _trap.image_angle == 0)
						|| (_p_gridy > gridy && _p_gridx == gridx && _trap.image_angle == 90)
						|| (_p_gridy < gridy && _p_gridx == gridx && _trap.image_angle == 270)) {
							_value = -1000; continue;
						}
					}
				}
				// shielded enemies:
				if (invincible_side[0] != 0 or invincible_side[1] != 0) {
					// if we have a spear, we have a bigger incentive to hit this unit
					if (has_behavior(_player, "spear") or (_player.item > 0 and unit_type_has_behavior(_player.item, "spear"))) {
						_value += (_p_hp > 2) * 4;
					} else {
						// if we are directly next to its invincible side... don't hit it!
						if ((_p_gridy == gridy and invincible_side[0] != 0 and _p_gridx == sign(invincible_side[0]) + gridx)
						or  (_p_gridx == gridx and invincible_side[1] != 0 and _p_gridy == sign(invincible_side[1]) + gridy)) {
							_value -= 50;
						}
						// if we are directly next to a not invincible side... hit it!
						else if ((_p_gridy == gridy and (invincible_side[0] == 0 or _p_gridx == gridx - sign(invincible_side[0])))
							 or  (_p_gridx == gridx and (invincible_side[1] == 0 or _p_gridy == gridy - sign(invincible_side[1])))) {
							_value += 5;
						} else if (cpu_empty_above and invincible_side[1] >= 0)
							   or (cpu_empty_below and invincible_side[1] <= 0)
							   or (cpu_empty_left  and invincible_side[0] >= 0)
							   or (cpu_empty_right and invincible_side[0] <= 0) {
								// can be attacked, but its shield is facing an empty space, so lower value
								if ((invincible_side[0] < 0 and cpu_empty_left)
								or  (invincible_side[0] > 0 and cpu_empty_right)
								or  (invincible_side[1] < 0 and cpu_empty_above)
								or  (invincible_side[1] > 0 and cpu_empty_below)) {
									_value -= 3;
								}
						} else { // can't be attacked!
							_value -= 50;
						}
					}
				}
				// ignore if we can't damage the enemy
				if ((invincible or phased) and unit_type != unit.rat) { _value -= 30; continue; }
				// ignore if it's electrified
				if (electrified and !has_blessing(_blessings, blessing.ignore_electricity)) { _value -= 30; continue; }
				// if it is hidden, forget about it if we are lower CPU level
				if (hidden and _cpu_level < 3) continue;
				// as Stache: avoid possessing birders and propeller rats, CPU can't control them
				if (has_behavior(_player, "possess") and !grid_master.player_is_possessed and (unit_type == unit.propeller_rat or unit_type == unit.birder)) { _value -= 30; continue; }
				var _attack = cpu_player_attack(_player, id, _blessings);
				if (_attack >= hp) { // can we one-shot the enemy?
					cpu_survives_with_hp = 0; // mark as we can kill
					// we really want to attack loners as Propeller
					if (_chain_size == 1 and has_behavior(_player, "propelled_hit")) _value += 5;
					// the bigger the chain, the more we want it!
					_value += _chain_size >= 3 ? _chain_size * 3 : _chain_size * 2;
					// Shield Knight would prefer a chain though
					if (has_behavior(_player, "hit_shield")) {
						if (_chain_size >= 3) {
							_value += 5;
						} else {
							_value -= 5;
						}
					}
					// if killing this connects a chain with the unit above and below, bonus points
					if (!cpu_empty_above and !cpu_empty_below) {
						if (unit_instance_is_valid(cpu_unit_above) 
						and unit_instance_is_valid(cpu_unit_below)
						and cpu_unit_above.unit_type == cpu_unit_below.unit_type) {
							_value += 2;
						}
					}
					// Desperation Talon: if we are at 1HP, this will heal us, bonus!
					if (_p_hp == 1 and has_blessing(_blessings, blessing.kill_at_1hp)) _value += 5;
					// Specter Knight needs to heal
					if (_p_hp < _p_hpmax and has_behavior(_player, "lifesteal")) _value += (_p_hpmax - _p_hp) * 2;
					// increased value in case of Hearty Wandy free shot
					if (_p_hp >= _p_hpmax and has_blessing(_blessings, blessing.heart_wand)) _value += 5;
				} else { // we'll take damage back
					cpu_survives_with_hp = hp - _attack; // mark as not killed
					var _counter = cpu_unit_retaliate(_player, _unit, _blessings, _attack); // get retaliation damage
					// increased value in case of Hearty Wandy free shot
					if (_p_hp >= _p_hpmax and (_counter <= 0 or freeze_counter >= 5) and has_blessing(_blessings, blessing.heart_wand)) _value += 5;
					// Frosty Fauld: freezes the enemy before it attacks
					if (freeze_counter >= 5) { _value += _counter * 3; continue; }
					// we do want to hit frozen units
					if (frozen > 0) _value += 5;
					// if we would die attacking it,
					if (_counter >= _p_hp) {
						_value -= 500; // ignore it completely
					} else { // figure out if the trade-off is worth it
						var _attacks_to_kill = ceil(hp / _attack);
						var _total_counter	 = (_attacks_to_kill - 1) * _counter;
						
						// Shield Knight would prefer a chain though
						if (has_behavior(_player, "hit_shield")) {
							if (_chain_size >= 3) {
								_value += 5;
							} else {
								_value -= 5;
							}
						}
						// even if we survive, still lower the values a bit
						if (_total_counter >= _p_hp) {
							_value  -= 2;
						} else { 
							_value += _p_hp - _total_counter;
						}
						// if enemy has a spear attack, add more value to a unit is behind us
						if (has_behavior(id, "pierce")) {
							// horizontal check
							var _hor = grid_master.grid[# gridx + sign(_p_gridx - gridx) * 2, gridy];
							if (instance_is_valid(_hor) and (_hor.is_enemy or _hor.is_block)) _value += 1;
							// vertical check
							var _ver = grid_master.grid[# gridx, gridy + sign(_p_gridy - gridy) * 2];
							if (instance_is_valid(_ver) and (_ver.is_enemy or _ver.is_block)) _value += 1;
						}
						// Wasps: increase values for them when they are in low numbers 
						if (has_behavior(id, "mob_rage")) {
							if (_chain_size <= 1) {
								_value += 5; 
							} else if (_chain_size <= 2) {
								_value += 2;
							} else if (_chain_size >= 3) {
								_value -= 3;
							}
						}
						// don't attack lone Zambies
						if (_chain_size <= 1 and has_behavior(id, "wake")) _value -= 10;
						// for other loners, scan units below to see if they will form a chain if they fall
						if (_chain_size <= 1 and grid_master.grid_gravity != 0 and !is_tangle) {
							for (var ii = gridy + 1; ii > GRID_HEIGHT; ii++) {
								if (unit_instance_is_valid(grid_master.grid[# gridx, ii])) {
									var _will_form_chain = false;
									if (grid_master.grid[# gridx, ii].unit_type == unit_type) {
										_will_form_chain = true;
									}
									if (gridx > 0) {
										var _unit_left = grid_master.grid[# gridx - 1, ii - 1];
										if (unit_instance_is_valid(_unit_left) and _unit_left.unit_type == unit_type) _will_form_chain = true;
									}
									if (gridx != GRID_WIDTH - 1) {
										var _unit_right = grid_master.grid[# gridx + 1, ii - 1];
										if (unit_instance_is_valid(_unit_right) and _unit_right.unit_type == unit_type) _will_form_chain = true;
									}
									if (_will_form_chain) _value -= 10;
									break;
								}
							}
							
						}
						// if it is a really big chain, then increase the value even more
						_value += _chain_size >= 3 ? _chain_size * 2 : _chain_size;
					}
				}
			}
			#endregion
			#region Chests, Items & Keys
			if (has_behavior(id, "chest")) {
				if (has_behavior(id, "king")) {
					if (grid_master.is_vs_king <= 0 and _cpu_level < 10) {
						_value -= 10; // ignore if can't open
					} else {
						_value += 10; // try to open it!
					}
				} else {
					if (_p_keys <= 0) {
						_value = -2000; // ignore it if we don't have a key
					}  else if (_player.item <= 0) {
						_value += 10; // we should really try to open it when don't have an item
					} else {
						_value += 2; // it's cool to open it if we have an item, but not that exciting
					}
					// Dynamallet: we want to open chests to recharge it
					if (_p_keys > 0 and has_blessing(_blessings, blessing.soil_chain)) {
						if (dynamallet_ready) {
							_value -= 5;
						} else {
							_value += 5;
						}
					}
				}
			}
			if (unit_type == unit.key) {
				// if we have a Skeleton Key, we want to blow surrounding units
				if (_p_keys >= 5 and has_blessing(_blessings, blessing.skeleton_key)) {
					// increase value for each nearby unit
					_value += (!cpu_empty_above + !cpu_empty_below + !cpu_empty_left + !cpu_empty_right) * 3;
				} else { // keys are always valuable, unless they are far away
					_value += 10 - (abs(_unit.gridx - _p_gridx) + abs(_unit.gridy - _p_gridy));
					// if we have no keys, give it even more priority
					if (_p_keys <= 0) _value += 5;
				}
			}
			if (is_item and unit_is_item(unit_type)) {
				// we definitely want it if we have no item
				if (_player.item <= 0) _value += 10;
				else if (_player.item2 <= 0 and has_behavior(_player, "dual_wield")) {
					_value += 10; // Chester A dual wielding, item can go into second slot
				} else { // see if we want to swap items
					var _new_item_tier = cpu_item_tier(unit_type, has_blessing(_blessings, blessing.durability), _player);
					var _old_item_tier = cpu_item_tier(_player.item, has_blessing(_blessings, blessing.durability), _player);
					if (_new_item_tier > _old_item_tier) {
						_value += 5;
					} else {
						_value -= 15;
					}
				}
			}
			if (unit_type == unit.growth_gem) {
				_value += (value - 1) * 2; // increase value with gem growth
				if (grid_master.versus_mode and grid_master.vs_mode == VERSUS_MODE.GEM_RACE) _value += (value - 1) * 2; // value them even more in Gem Race
			}
			#endregion
			#region Explosives
			// generally, we want to trigger them, if we can tank them
			if (is_explodes) {
				if (!primed) {
					if (_p_hp >= _p_hpmax or _p_hp > 3) _value += 5;
					// take blessings into account
					if (has_blessing(_blessings, blessing.bomb_resistance) or has_blessing(_blessings, blessing.bombvest)) {
						_value += 10 + has_blessing(_blessings, blessing.bomb_range) * 5;
					}
					if (unit_type == unit.bomb_ultimate) _value += 10; // Crystal Clear
				} else { 
					_value -= 100; // ignore primed bombs completely
				}
			}
			#endregion
			#region Chester Shop
			if (unit_type == unit.door_vs) {
				if (_p_keys > 0 or opened) {
					if (cpu_added_value != -15) _value += 15 + _ccrusher * 5;
					if (_ccrusher > 0) { // if the Celing Crusher is approaching, give more priority to nearby tiles
						var _grid = grid_master.grid;
						for (var i = gridx - 2; i <= gridx + 2; i++) {
							for (var e = gridy - 2; e <= gridy + 2; e++) {
								if (e > 0 and e <= 8 and i >= 0 and i <= 7) {
									var _uu = _grid[# i, e];
									if (unit_instance_is_valid(_uu) and _uu.cpu_added_value >= 0) {
										_uu.cpu_added_value = max(_uu.cpu_added_value, _ccrusher * 2);
									}
								}
							}
						}
					}
				} else _value -= 1000;
			}
			if (unit_type == unit.chester_chest) {
				if (_p_keys > 0 or opened) {
					// only enter the shop if we can actually buy something in there
					if (_money >= relic_get_price(blessing.hp1, grid_master)) {
						_value += 140;
					} else {
						_value -= 1000;
					}
				} else _value -= 1000;
			}
			if (unit_type == unit.bohto_bugle) {
				var _shop_items = 0;
				// count the amount of shop items we can afford
				with (oUnit) if (unit_type == unit.shop_item) {
					if (_money >= relic_get_price(it[BLESSING_DATA.INDEX], grid_master)) _shop_items++;
				}
				// set value based on those items
				switch (_shop_items) {
					case 0: _value = 120;	break;
					case 1: _value = 40;	break;
					case 2: _value = 0;		break;
					case 3: _value = -100;	break;
				}
			}
			if (unit_type == unit.shop_item) {
				var _price = relic_get_price(it[BLESSING_DATA.INDEX], grid_master);
				if _money < _price { 
					_value -= 20; // can't afford it, not interested
				} else {
					_value += cpu_relic_tier(it[BLESSING_DATA.INDEX], _player, _blessings);
				}
			}
			if (unit_type == unit.portal_door) {
				_value += 20; // leave the shop if can't afford any shop item
			}
			#endregion
			
			if (unit_type == unit.crusher_block) _value -= 1000;
			if (unit_type == unit.garbage) _value += _chain_size * 2; // value scales with the chain size
			if (unit_type == unit.moneybag) _value += 5;
			if (is_wall or unit_type == unit.reserved_space or unit_type == unit.big_reserved_space) _value -= 100;
			
			if (_player.is_modded) {
				cpu_unit_value = undefined;
				cpu_added_value = 0;
				mod_run_program(_player.program, _player.program_folder, "cpu_scan_tile");
				if (!is_undefined(cpu_unit_value)) {
					_value = cpu_unit_value;
				} else {
					_value += cpu_added_value;
				}
			}
		}
		
		var _tile = [_x, _y, _value, _unit];
		ds_list_add(cpu_tiles, _tile);
		cpu_grid[# _x, _y] = _tile;
	}
}
