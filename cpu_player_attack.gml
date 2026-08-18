/// @description			Calculates damage CPU will deal to the specified unit.
/// @param {Id.Instance}	_player						The instance ID of the player unit.
/// @param {Id.Instance}	_unit						The instance ID of the enemy unit.
/// @param {Id.DsList}		_blessings					The ds_list of the player's relics.
/// @returns {Real}
function cpu_player_attack(_player, _unit, _blessings) {
	var _total_damage = 0;
	with (_player) {
		// enemy can't be attacked
		if (_unit.invincible or _unit.phased or _unit.protected) return 0;
		// can't be attacked without Shockproof Socks
		if (_unit.electrified and !has_blessing(_blessings, blessing.ignore_electricity)) return 0;
		_total_damage += atk; // player's base attack
		// added attack from items
		if (item and unit_type_has_behavior( item, "attack")) {
			_total_damage += unit_type_behavior_value(item, "attack");
			if (has_blessing(_blessings, blessing.durability))   _total_damage += 1;
			if (has_blessing(_blessings, blessing.dubious_dust)) _total_damage += 1;
		} else if (item and _total_damage <= 0 and has_behavior(id, "item_1dmg")) {
			_total_damage += 1;
			if (has_blessing(_blessings, blessing.durability))   _total_damage += 1;
			if (has_blessing(_blessings, blessing.dubious_dust)) _total_damage += 1;
		}
		// modifier buffs
		if (grid_master.damage_buff) _total_damage += 1;
		if (has_modifier(curse.double_garbage, grid_master.player_id)) _total_damage += 1;
		// buffs from passive abilities
		if (black_knight_boost > 0 and has_behavior( id, "active_gempower")) _total_damage += black_knight_boost;
		if (has_behavior(id, "uppercut") and grid_master.grid[# gridx, gridy - 1] == _unit) _total_damage += 1;
		_total_damage += propeller_combo + tinker_mech_form_enabled * 2;
		// Polar Knight's passsive
		if (_unit.frozen and has_behavior(id, "ice_extra_dmg")) _total_damage += 1;
		if (shield_knight_b_charge) _total_damage += 1;
		// Divine Liquid
		if (has_behavior(_unit, "undead") and has_blessing(_blessings, blessing.undead_slayer)) _total_damage += 1;
		// extra damage from relics
		_total_damage += (shockproof_socks_counter >= 10) 
			+ atk_extra
			+ extra_damage_after_kill
			+ extra_damage_from_potion
			+ extra_damage_from_block
			+ extra_damage_surrounded
			+ extra_damage_tambourine;
		
		// Power Pail
		if (grid_master.chain_meter >= 576 and has_blessing(_blessings, blessing.attack_full_meter)) _total_damage += 1;
		// Third Amulet
		if (_unit.times_hit >= 2 and has_blessing(_blessings, blessing.third_strike)) _total_damage += 1;
		// Obsidian Drill
		if (_unit.is_block and has_blessing(_blessings, blessing.digger)) _total_damage += 1;
		// Swift Dagger and Swift Stick
		if (_unit.hp == _unit.hpmax) _total_damage += has_blessing(_blessings, blessing.first_strike) + has_blessing(_blessings, blessing.swift_stick);
		// Single Glove
		if (_unit.cpu_chain_size <= 1 and has_blessing(_blessings, blessing.solo_strike)) _total_damage += 1;
		// Five String
		if (crit_counter >= 4 and has_blessing(_blessings, blessing.critical_hit_per_5)) _total_damage += 1;
		// Battering Ram
		if (abs(battering_x) >= 2 or abs(battering_y) >= 2) {
			var dx = [-1, 1, 0, 0];
			var dy = [0, 0, -1, 1];
			// check if the unit being evaluated is in the direction of the player's movement
			for (var i = 0; i < 4; i++) {
				var _x = gridx + dx[i];
				var _y = gridy + dy[i];
				var _unit_check = grid_master.grid[# _x, _y];
				if (_unit_check == _unit and dx[i] == sign(battering_x) and dy[i] == sign(battering_y)) {
					_total_damage += 1;
				}
			}
		}
		// Shovel Knight's passive
		if (_unit.cpu_chain_size > 1 and _unit.is_enemy and has_behavior(id, "damage_on_kill")) {
			var _ch = chain_from_unit(_unit, undefined, 10);
			for (var i = 0; i < _ch; i++) {
				var uu = _ch[| i];
				if (instance_is_valid(uu) and uu.hp <= _total_damage) {
					_total_damage++;
					break;
				}
			}
			ds_list_destroy(_ch);
		}
	}
	return _total_damage;
}
