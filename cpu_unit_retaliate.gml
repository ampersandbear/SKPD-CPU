/// @description			Calculates retaliation damage the CPU will receive from the specified unit.
/// @param {Id.Instance}	_player						The instance ID of the player unit.
/// @param {Id.Instance}	_unit						The instance ID of the enemy unit.
/// @param {Id.DsList}		_blessings					The ds_list of the player's relics.
/// @param {Real}			_player_damage				The damage the player will deal (use cpu_player_attack() to calculate).
/// @returns {Real}
function cpu_unit_retaliate(_player, _unit, _blessings, _player_damage = 0) {
	var _total_damage = 0;
	with (_unit) {
		if (frozen or is_flipped or (_player.item and unit_type_has_behavior(_player, "ice_touch"))) return 0;
		if instance_position(grid_master.x + 32 * _player.gridx, grid_master.y + 32 * _player.gridy, oSmokeCloud) return 0; // protected by Phase Locket
		_total_damage += atk; // base attack
		// account for Shield Knight's shields
		if (_player.shield_knight_shields > 0 or _player.shield_knight_b_charge > 0) return 0;
		// Shield item
		if (_player.item > 0 and unit_type_has_behavior(_player.item, "shield")) _total_damage--;
		// Polar Knight's passive
		if (cpu_chain_size > 1 and has_behavior(_player, "ice_kill")) {
			var _c_chain = chain_from_unit(id, undefined, 10);
			for (var i = 0; i < cpu_chain_size; i++) {
				var c_u = ds_list_find_value(_c_chain, i);
				if (instance_is_valid(c_u) and c_u.hp <= _player_damage) {
					ds_list_destroy(_c_chain);
					return (_total_damage == 0);
				}
			}
			ds_list_destroy(_c_chain);
		}
		if (cpu_chain_size > 1 and has_behavior(_player, "chain_recoil")) _total_damage += 1; // Propeller Knight's chain weakness
		if (mob_rage > 0) _total_damage += min(cpu_chain_size - 1, mob_rage - 1); // Wasps' ability
		if (sprite_index != idle_sprite_index and has_behavior(id, "lowHP_rage")) _total_damage += 1; // Fairies
		if (electrified and !has_blessing(_blessings, blessing.ignore_electricity)) _total_damage += 2; // electrified units
	}
	return _total_damage;
}
