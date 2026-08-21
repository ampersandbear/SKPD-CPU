/// @description			Grades an item based on how useful it is for the CPU.
/// @param {Real}			_item						The unit_type of the item to grade.
/// @param {Bool}			_diamond_dust				If CPU has Diamond Dust equipped.
/// @param {Id.Instance}	_player						Instance ID of the player object, if the function is called outside of oGrid.
/// @returns {Real}
function cpu_item_tier(_item, _diamond_dust = false, _player = -1) {
	var _p = (_player == -1) ? player : _player;
	if (_p.is_modded) {
		cpu_item = _item;
		cpu_item_grade = undefined;
		cpu_has_diamond_dust = _diamond_dust;
		mod_run_program(_p.program, _p.program_folder, "cpu_item_tier");
		if (!is_undefined(cpu_item_grade)) return cpu_item_grade;
	}
	
	if (_item <= 0) return -10;
	
	switch (_item) {
		case unit.sword1:			return 1 + _diamond_dust;
		case unit.sword2:			return 2 + _diamond_dust;
		case unit.sword3:			return 3 + _diamond_dust;
		
		case unit.spear:			return 1 + _diamond_dust;
		case unit.trident:			return 3 + _diamond_dust;
		
		case unit.shield:			return 1;
		
		case unit.axe_fire:			return 1 + _diamond_dust;
		case unit.axe_ice:			return 3 + _diamond_dust;
		case unit.poison_dagger:	return 1 + _diamond_dust;
		
		case unit.anchor:			return 2;
		case unit.war_horn:			return 2;
		case unit.flare_wand:		return 2;
		case unit.flipwand:			return 1;
		case unit.magic_wand:		return 1 + _diamond_dust;
		case unit.chrono_coin:		return 2;
		case unit.copycard:			return 1;
		case unit.wildcard:			return 3;
		case unit.exploder_t:		return 2;
		case unit.exploder_x:		return 1;
		case unit.phase_locket:		return 1;
		
		case unit.vs_bomber:		return 2;
		case unit.vs_shuffle:		return 3;
		case unit.vs_geyser:		return 3;
		case unit.vs_transmogrify:	return 2;
	}
	return 2;
}
