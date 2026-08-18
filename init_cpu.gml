/// @description Runs when oUnit of the CPU is created.
function init_cpu() {
	current_step = 0; // current step of the CPU logic, see cpu_step()
	couldnt_move = false; // if we were able to move or not, see cpu_movement()
	chosen_tile = noone; // object_index of the choosen target
	chosen_tile_draw = noone; // debug feature
	cpu_path = path_add(); // path to the target
	cpu_item_chance = 0; // chance to use an item every step, some items have exceptions, see cpu_item_use()
	cpu_item_cooldown = 0; // cooldown between item uses
	cpu_ability_cooldown = 0; // cooldown between ability uses
	cpu_tiles = ds_list_create(); // scanned tiles with their respective values
	cpu_grid  = ds_grid_create(GRID_WIDTH, GRID_HEIGHT); // same info as above, but in ds_grid format
	cpu_grid_check = ds_grid_create(GRID_WIDTH, GRID_HEIGHT); // used for the tile scanning recursion
	cpu_bomb_grid = ds_grid_create(GRID_WIDTH, GRID_HEIGHT); // used for marking tiles inside exploding bombs' ranges
	cpu_terrorpin_value = 0; // value for interacting with Terrorpin
	cpu_moves = ds_list_create(); // list of planned moves
	cpu_prev = ds_list_create(); // list of previously visited tiles, used for backtracking check
	// difficulty sliders
	cpu_level = global.vs_cpu_difficulty; // goes from 1 to 9 (10 is cheat tier)
	cpu_wait = 10; // delay after each move in steps, it's randomized using the values below:
	cpu_wait_base = 10;
	cpu_wait_random = 10;
	cpu_inactive = 0; // how many turns we haven't moved for
	cpu_bomb_is_exploding = false; // if CPU is inside the exploding bomb range
	cpu_ignore_bomb_check = false; // if CPU is inside the exploding bomb range, but should ignore it (when chasing Volleybomb, for example)
	cpu_ceiling_crusher = 0; // the gridy position of the ceiling crusher (if exists)
	cpu_mole_b = false; // if CPU is mole B
	cpu_beefto = false; // if CPU is Beefto
	cpu_beefto_delay = irandom_range(5, 15); // dealy between Beefto stomps
	cpu_chester_uses = -1; // limit for entering shop as Chester B
	
	switch (cpu_level) {
		case 1:  cpu_wait_base = 15; cpu_wait_random = 25; break;
		case 2:  cpu_wait_base = 14; cpu_wait_random = 19; break;
		case 3:  cpu_wait_base = 13; cpu_wait_random = 17; break;
		case 4:  cpu_wait_base = 12; cpu_wait_random = 15; break;
		case 5:  cpu_wait_base = 11; cpu_wait_random = 13; break;
		case 6:  cpu_wait_base = 10; cpu_wait_random = 11; break;
		case 7:  cpu_wait_base =  9; cpu_wait_random =  9; break;
		case 8:  cpu_wait_base =  8; cpu_wait_random =  7; break;
		case 9:  cpu_wait_base =  7; cpu_wait_random =  5; break;
		case 10: cpu_wait_base =  7; cpu_wait_random =  2; break;
		case 11: cpu_wait_base =  7; cpu_wait_random =  0; break;
	}
	cpu_wait = cpu_wait_base;
	
	// mod setup variables
	cpu_ignore_default_step_code = false; // set to `true` if you want to set up your own CPU logic from scratch
	cpu_reset_on_inactivity = true; // if CPU should be reset when inactive for a specific number of frames
	cpu_inactivity_threshold = 100; // the number of frames for a reset
	cpu_use_item_cooldown = true; // prevents CPU from speed firing items
	cpu_use_ability_cooldown = true; // prevents CPU from spamming its active ability
	cpu_prevent_backtracking = true;
	cpu_attempt_to_get_out_of_exploding_bomb_range = true;
	cpu_attempt_to_avoid_enemy_area_attacks = true;
	cpu_attempt_to_avoid_enemy_area_attacks = true;
	cpu_chase_volleybomb = true;
}


/// @description			Runs from cpu_step() before each iteration of the logic (current_step == 0).
/// @param {Id.DsGrid}		_grid						The Grid CPU belongs to.
/// @param {Real}			_added_value				The added `importance` value for the unit.
function init_cpu_variables(_grid, _added_value = 0) {
	// these variables are per each oUnit on the grid (not the CPU itself)!
	cpu_added_value = _added_value;
	if (cpu_added_value != 0) {
		if (cpu_added_value < 0) { cpu_added_value += 2; if (cpu_added_value > 0) { cpu_added_value = 0; }}
		if (cpu_added_value > 0) { cpu_added_value -= 2; if (cpu_added_value < 0) { cpu_added_value = 0; }}
	}
	cpu_chain_size = chain_size_from_unit(id, 10);
	cpu_unit_above = _grid[# gridx, gridy - 1];
	cpu_unit_below = _grid[# gridx, gridy + 1];
	cpu_unit_left  = _grid[# gridx - 1, gridy];
	cpu_unit_right = _grid[# gridx + 1, gridy];
	
	cpu_empty_above = (gridy > 0 and (!unit_instance_is_valid(cpu_unit_above) or cpu_unit_above == player));
	cpu_empty_below	= (gridy < 8 and (!unit_instance_is_valid(cpu_unit_below) or cpu_unit_below == player));
	cpu_empty_left	= (gridx > 0 and (!unit_instance_is_valid(cpu_unit_left ) or cpu_unit_left  == player));
	cpu_empty_right = (gridx < 7 and (!unit_instance_is_valid(cpu_unit_right) or cpu_unit_right == player));
	
	cpu_survives_with_hp = 0;
}
