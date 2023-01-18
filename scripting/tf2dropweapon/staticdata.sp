#include <sourcemod>
#include <tf2>
#include <tf2_stocks>

void InitStaticData() {
	InitDefaultDefIndexByClassname();
}

// ----- Default Item Definitions -----

static StringMap g_DefaultDefIndexByClassname;

bool IsValidWeaponClassname(const char[] classname) {
	return g_DefaultDefIndexByClassname.ContainsKey(classname);
}
int GetDefaultItemDef(const char[] classname, TFClassType playerclass) {
	any data[2];
	if (g_DefaultDefIndexByClassname.GetArray(classname, data, 2) && data[1] != 0) {
		//basic class check
		return (playerclass == data[1]) ? data[0] : -1;
	}
	if (StrEqual(classname, "saxxy")) {
		//all-class melee:
		// instead of returning a saxxy id, this should return the default melee id and adjust the classname
		// since i don't want to take in a buffer, i just bank on translating the class string after calling this fixes that issue
		switch (playerclass) {
			case TFClass_Scout: return 0;
			case TFClass_Sniper: return 3;
			case TFClass_Soldier: return 6;
			case TFClass_DemoMan: return 1;
			case TFClass_Medic: return 8;
			case TFClass_Heavy: return 5;
			case TFClass_Pyro: return 2;
			case TFClass_Spy: return 4;
			case TFClass_Engineer: return 7;
			default: return -1;
		}
	} else if (StrEqual(classname, "tf_wearable")) {
		//this does not mean cosmetics, but non-weapon items that go into weapon loadout slots
		switch (playerclass) {
			case TFClass_Sniper: return 231;
			case TFClass_Soldier: return 133;
			case TFClass_DemoMan: return 405;
			default: return -1;
		}
	} else if (StrContains(classname, "tf_weapon_")!=0) {
		return -1; //below all start with this string
	} else if (StrEqual(classname[10], "shotgun")) {
		//multiclass shotgun
		switch (playerclass) {
			case TFClass_Soldier: return 10;
			case TFClass_Heavy: return 11;
			case TFClass_Pyro: return 12;
			case TFClass_Engineer: return 9;
			default: return -1;
		}
	} else if (StrEqual(classname[10],"shovel")) {
		switch (playerclass) {
			case TFClass_Soldier: return 6;
			case TFClass_DemoMan: return 154;
			default: return -1;
		}
	} else if (StrEqual(classname[10],"pistol")) {
		switch (playerclass) {
			case TFClass_Scout: return 23;
			case TFClass_Engineer: return 22;
			default: return -1;
		}
	} else if (StrEqual(classname[10],"builder")) {
		switch (playerclass) {
			case TFClass_Spy: return 735;
			case TFClass_Engineer: return 28;
			default: return -1;
		}
	} else if (StrEqual(classname[10],"katana")) {
		switch (playerclass) {
			case TFClass_Soldier: return 357;
			case TFClass_DemoMan: return 357;
			default: return -1;
		}
	} else if (StrEqual(classname[10],"parachute")) {
		switch (playerclass) {
			case TFClass_Soldier: return 1101;
			case TFClass_DemoMan: return 1101;
			default: return -1;
		}
	}
	return -1;
}
static void InitDefaultDefIndexByClassname() {
	if (g_DefaultDefIndexByClassname == INVALID_HANDLE) g_DefaultDefIndexByClassname = new StringMap();
	else g_DefaultDefIndexByClassname.Clear();
	
	any data[2]; //itemdef , class : -1 , 0 for multiclass
#define PUSH(%1,%2,%3) data[0]=(%2); data[1]=(%3); g_DefaultDefIndexByClassname.SetArray(%1, data, 2)
	PUSH("saxxy",                             -1,    0);
	PUSH("tf_wearable",                       -1,    0);
	PUSH("tf_weapon_shotgun",                 -1,    0);
	PUSH("tf_weapon_bat",                      0,    TFClass_Scout);
	PUSH("tf_weapon_bottle",                   1,    TFClass_DemoMan);
	PUSH("tf_weapon_fireaxe",                  2,    TFClass_Pyro);
	PUSH("tf_weapon_club",                     3,    TFClass_Sniper);
	PUSH("tf_weapon_knife",                    4,    TFClass_Spy);
	PUSH("tf_weapon_fists",                    5,    TFClass_Heavy);
	PUSH("tf_weapon_shovel",                  -1,    0);
	PUSH("tf_weapon_wrench",                   7,    TFClass_Engineer);
	PUSH("tf_weapon_bonesaw",                  8,    TFClass_Medic);
	PUSH("tf_weapon_shotgun_primary",          9,    TFClass_Engineer);
	PUSH("tf_weapon_shotgun_soldier",          10,   TFClass_Soldier);
	PUSH("tf_weapon_shotgun_hwg",              11,   TFClass_Heavy);
	PUSH("tf_weapon_shotgun_pyro",             12,   TFClass_Pyro);
	PUSH("tf_weapon_scattergun",               13,   TFClass_Scout);
	PUSH("tf_weapon_sniperrifle",              14,   TFClass_Sniper);
	PUSH("tf_weapon_minigun",                  15,   TFClass_Heavy);
	PUSH("tf_weapon_smg",                      16,   TFClass_Sniper);
	PUSH("tf_weapon_syringegun_medic",         17,   TFClass_Medic);
	PUSH("tf_weapon_rocketlauncher",           18,   TFClass_Soldier);
	PUSH("tf_weapon_grenadelauncher",          19,   TFClass_DemoMan);
	PUSH("tf_weapon_pipebomblauncher",         20,   TFClass_DemoMan);
	PUSH("tf_weapon_flamethrower",             21,   TFClass_Pyro);
	PUSH("tf_weapon_pistol",                  -1,    0);
	PUSH("tf_weapon_revolver",                 24,   TFClass_Spy);
	PUSH("tf_weapon_pda_engineer_build",       25,   TFClass_Engineer);
	PUSH("tf_weapon_pda_engineer_destroy",     26,   TFClass_Engineer);
	PUSH("tf_weapon_pda_spy",                  27,   TFClass_Spy);
	PUSH("tf_weapon_builder",                 -1,    0);
	PUSH("tf_weapon_medigun",                  29,   TFClass_Medic);
	PUSH("tf_weapon_invis",                    30,   TFClass_Spy);
	PUSH("tf_weapon_flaregun",                 39,   TFClass_Pyro);
	PUSH("tf_weapon_lunchbox",                 42,   TFClass_Heavy);
	PUSH("tf_weapon_bat_wood",                 44,   TFClass_Scout);
	PUSH("tf_weapon_lunchbox_drink",           46,   TFClass_Scout);
	PUSH("tf_weapon_compound_bow",             56,   TFClass_Sniper);
	PUSH("tf_wearable_razorback",              57,   TFClass_Sniper);
	PUSH("tf_weapon_jar",                      58,   TFClass_Sniper);
	PUSH("tf_weapon_rocketlauncher_directhit", 127,  TFClass_Soldier);
	PUSH("tf_weapon_buff_item",                129,  TFClass_Soldier);
	PUSH("tf_wearable_demoshield",             131,  TFClass_DemoMan);
	PUSH("tf_weapon_sword",                    132,  TFClass_DemoMan);
	PUSH("tf_weapon_laser_pointer",            140,  TFClass_Engineer);
	PUSH("tf_weapon_sentry_revenge",           141,  TFClass_Engineer);
	PUSH("tf_weapon_robot_arm",                142,  TFClass_Engineer);
	PUSH("tf_weapon_handgun_scout_primary",    220,  TFClass_Scout);
	PUSH("tf_weapon_bat_fish",                 221,  TFClass_Scout);
	PUSH("tf_weapon_jar_milk",                 222,  TFClass_Scout);
	PUSH("tf_weapon_crossbow",                 305,  TFClass_Medic);
	PUSH("tf_weapon_stickbomb",                307,  TFClass_DemoMan);
	PUSH("tf_weapon_katana",                  -1,    0);
	PUSH("tf_weapon_sniperrifle_decap",        402,  TFClass_Sniper);
	PUSH("tf_weapon_particle_cannon",          441,  TFClass_Soldier);
	PUSH("tf_weapon_raygun",                   442,  TFClass_Soldier);
	PUSH("tf_weapon_handgun_scout_secondary",  449,  TFClass_Scout);
	PUSH("tf_weapon_mechanical_arm",           528,  TFClass_Engineer);
	PUSH("tf_weapon_drg_pomson",               588,  TFClass_Engineer);
	PUSH("tf_weapon_flaregun_revenge",         595,  TFClass_Pyro);
	PUSH("tf_weapon_bat_giftwrap",             648,  TFClass_Scout);
	PUSH("tf_weapon_charged_smg",              751,  TFClass_Sniper);
	PUSH("tf_weapon_sapper",                   810,  TFClass_Spy);
	PUSH("tf_weapon_cleaver",                  812,  TFClass_Scout);
	PUSH("tf_weapon_breakable_sign",           813,  TFClass_Pyro);
	PUSH("tf_weapon_cannon",                   996,  TFClass_DemoMan);
	PUSH("tf_weapon_shotgun_building_rescue",  997,  TFClass_Engineer);
	PUSH("tf_weapon_sniperrifle_classic",      1098, TFClass_Sniper);
	PUSH("tf_weapon_parachute",               -1,    0);
	PUSH("tf_weapon_rocketlauncher_airstrike", 1104, TFClass_Soldier);
	PUSH("tf_weapon_rocketlauncher_fireball",  1178, TFClass_Pyro);
	PUSH("tf_weapon_rocketpack",               1179, TFClass_Pyro);
	PUSH("tf_weapon_jar_gas",                  1180, TFClass_Pyro);
	PUSH("tf_weapon_slap",                     1181, TFClass_Pyro);
#undef PUSH
	
}

// ----- Stock Loadout -----

static int g_StockItemDefs[10][6] = {
	{-1, -1, -1, -1, -1}, //unknown
	{13, 23,  0, -1, -1}, //scout=1
	{14, 16,  3, -1, -1}, //sniper
	{18, 10,  6, -1, -1}, //soldier
	{19, 20,  1, -1, -1}, //demo
	{17, 29,  8, -1, -1}, //medic
	{15, 11,  5, -1, -1}, //heavy
	{21, 12,  2, -1, -1}, //pyro
	{24, 735, 4, 27, 30}, //spy
	{ 9, 22,  7, 25, 26}, //engineer
};

int GetStockWeaponItemDef(TFClassType class, int slot) {
	if (!(0<=slot<6)) ThrowError("Slot %i unsupported", slot);
	return g_StockItemDefs[class][slot];
}