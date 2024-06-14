#include <sourcemod>
#include <tf_econ_data>
#include <tf2dropweapon>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "24w24a"

public Plugin myinfo = {
	name = "[TF2] DropWeapon SimpleConfig",
	author = "reBane",
	description = "Module plugin for DropWeapon",
	version = PLUGIN_VERSION,
	url = "N/A"
}

#define WPN_SLOT_CNT 8

//slot perm size: 50
//slots: 8 -> 400 per team
//teams: 4 -> 1600 for all
//-> 200 for item for all teams
static char permission_buffer_drop[1600];
static char permission_buffer_pickup[1600];
enum struct ItemDropPerm {
    int itemdef;
    char permission[200];
}
static ArrayList permission_itemdef_drop=null;
static ArrayList permission_itemdef_pickup=null;

public void OnMapStart() {
    LoadPermissionsFromFile();
    PrecacheSound("common/wpn_denyselect.wav");
}

// ----- Plugin forwards -----

public Action TF2DW_OnClientDropWeapon(int client, int weapon) {
    int itemdef = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
    TFClassType pclass = TF2_GetPlayerClass(client);
    int slot = LoadoutSlotToIndex(TF2Econ_GetItemLoadoutSlot(itemdef, pclass));
    if (slot < 0 || slot >= WPN_SLOT_CNT) return Plugin_Continue;
    bool allowed = checkPermSlot(permission_buffer_drop, client, slot) && checkPermItem(permission_itemdef_drop, client, itemdef);
    if (!allowed) {
        if (checkHudSpam(client))
            PrintHintText(client, "You can not drop this weapon");
        EmitSoundToClient(client, "common/wpn_denyselect.wav");
    }
    return allowed ? Plugin_Continue : Plugin_Handled;
}

public Action TF2DW_OnClientPickupWeapon(int client, int droppedWeapon) {
    int itemdef = GetEntProp(droppedWeapon, Prop_Send, "m_iItemDefinitionIndex");
    TFClassType pclass = TF2_GetPlayerClass(client);
    int slot = LoadoutSlotToIndex(TF2Econ_GetItemLoadoutSlot(itemdef, pclass));
    if (slot < 0 || slot >= WPN_SLOT_CNT) return Plugin_Continue;
    bool allowed = checkPermSlot(permission_buffer_pickup, client, slot) && checkPermItem(permission_itemdef_pickup, client, itemdef);
    return allowed ? Plugin_Continue : Plugin_Handled;
}

// ----- List/Array and permission handling -----

static int permOffsetSlot(int team, int slot) {
    int offset;
    switch(team) {
    case 2:
        offset = 000;
    case 3:
        offset = 490;
    case 5:
        offset = 800;
    default:
        offset = 1200;
    }
    if (slot < 0 || slot >= WPN_SLOT_CNT) return offset;
    return offset + slot * 50;
}
static int permOffsetItem(int team) {
    switch(team) {
    case 2:
        return 000;
    case 3:
        return 050;
    case 5:
        return 100;
    default:
        return 150;
    }
}

static bool checkPermRaw(const char[] perm, int client) {
    if (perm[0] == '\0' || StrEqual(perm, "everyone", false)) {
        return true;
    } else if (StrEqual(perm, "nobody", false)) {
        return false;
    } else if (perm[0] != '/') {
        int numchars;
        int flagBits = ReadFlagString(perm, numchars);
        if (numchars == strlen(perm)) {
            return CheckCommandAccess(client, perm, ADMFLAG_ROOT);
        } else {
            return CheckCommandAccess(client, "", flagBits, true);
        }
    } else {
        return CheckCommandAccess(client, perm[1], ADMFLAG_ROOT);
    }
}

static void setPermissionSlot(char[] permBuffer, int team, int weaponSlot, const char[] permString) {
    PrintToServer("Set permission for slot %i on team %i to %s", weaponSlot, team, permString);
    strcopy(permBuffer[permOffsetSlot(team, weaponSlot)], 50, permString);
}
static bool checkPermSlot(char[] permBuffer, int client, int weaponSlot) {
    int offset = permOffsetSlot(GetClientTeam(client), weaponSlot);
    return checkPermRaw(permBuffer[offset], client);
}
static void setPermissionItem(ArrayList permList, int team, int itemdef, const char[] permString) {
    ItemDropPerm entry;
    int offset = permOffsetItem(team);

    int at = BSearchList(permList, itemdef);
    if (at >= 0) {
        permList.GetArray(at, entry);
        strcopy(entry.permission[offset], 50, permString);
        permList.SetArray(at, entry);
    } else {
        entry.itemdef = itemdef;
        strcopy(entry.permission[offset], 50, permString);
        permList.PushArray(entry);
        permList.Sort(Sort_Ascending, Sort_Integer);
    }
}
static bool checkPermItem(ArrayList permList, int client, int itemdef) {
    ItemDropPerm entry;
    int at = BSearchList(permList, itemdef);
    if (at == -1) return true;
    permList.GetArray(at, entry);
    int offset = permOffsetItem(GetClientTeam(client));
    return checkPermRaw(entry.permission[offset], client);
}

// ----- Config Handling -----

enum LoadEntryKind {
    LEK_Drop,
    LEK_Pickup
}

void loadSlotPerms(char[] permBuffer, KeyValues kvs, int slot) {
    char buffer[64];
    KvDataTypes type = kvs.GetDataType(NULL_STRING);
    if (type == KvData_String) {
        kvs.GetString(NULL_STRING, buffer, sizeof(buffer));
        setPermissionSlot(permBuffer, 1, slot, buffer);
        setPermissionSlot(permBuffer, 2, slot, buffer);
        setPermissionSlot(permBuffer, 3, slot, buffer);
        setPermissionSlot(permBuffer, 5, slot, buffer);
    } else if (type == KvData_None) {
        kvs.GetString("red", buffer, sizeof(buffer), "");
        setPermissionSlot(permBuffer, 2, slot, buffer);
        kvs.GetString("blue", buffer, sizeof(buffer), "");
        setPermissionSlot(permBuffer, 3, slot, buffer);
        kvs.GetString("spec", buffer, sizeof(buffer), "");
        setPermissionSlot(permBuffer, 1, slot, buffer);
        kvs.GetString("boss", buffer, sizeof(buffer), "");
        setPermissionSlot(permBuffer, 5, slot, buffer);
    } else {
        SetFailState("Broken configuration, expected perm string or group with teams");
    }
}

void loadItemPerms(ArrayList permList, KeyValues kvs, int itemdef) {
    char buffer[64];
    KvDataTypes type = kvs.GetDataType(NULL_STRING);
    if (type == KvData_String) {
        kvs.GetString(NULL_STRING, buffer, sizeof(buffer));
        setPermissionItem(permList, 1, itemdef, buffer);
        setPermissionItem(permList, 2, itemdef, buffer);
        setPermissionItem(permList, 3, itemdef, buffer);
        setPermissionItem(permList, 5, itemdef, buffer);
    } else if (type == KvData_None) {
        kvs.GetString("red", buffer, sizeof(buffer), "");
        setPermissionItem(permList, 2, itemdef, buffer);
        kvs.GetString("blue", buffer, sizeof(buffer), "");
        setPermissionItem(permList, 3, itemdef, buffer);
        kvs.GetString("spec", buffer, sizeof(buffer), "");
        setPermissionItem(permList, 1, itemdef, buffer);
        kvs.GetString("boss", buffer, sizeof(buffer), "");
        setPermissionItem(permList, 5, itemdef, buffer);
    } else {
        SetFailState("Broken configuration, expected perm string or group with teams");
    }
}

void loadPermEntries(KeyValues kvs, LoadEntryKind kind) {
    char slotname[32];
    // naming is a bit bad here: with keys they mean section names, with values they mean value keys, so passing false is correct
    if (!kvs.GotoFirstSubKey(false))
        return;
    do {
        kvs.GetSectionName(slotname, sizeof(slotname));
        int itemdef;
        int parsed = StringToIntEx(slotname, itemdef);
        if (parsed == strlen(slotname)) {
            if (!TF2Econ_IsValidItemDefinition(itemdef))
                SetFailState("Unknown weapon definition index %i", itemdef);
            if (kind == LEK_Drop)
                loadItemPerms(permission_itemdef_drop, kvs, itemdef);
            else
                loadItemPerms(permission_itemdef_pickup, kvs, itemdef);
        } else {
            int idx = LoadoutSlotToIndex(TF2Econ_TranslateLoadoutSlotNameToIndex(slotname));
            if (idx == -1 || idx >= WPN_SLOT_CNT)
                SetFailState("Unknown or unsupported slot name \"%s\"", slotname);
            if (kind == LEK_Drop)
                loadSlotPerms(permission_buffer_drop, kvs, idx);
            else
                loadSlotPerms(permission_buffer_pickup, kvs, idx);
        }
    } while (kvs.GotoNextKey(false));
    kvs.GoBack();
}

void LoadPermissionsFromFile() {
    if (permission_itemdef_drop == null)
        permission_itemdef_drop = new ArrayList(sizeof(ItemDropPerm));
    else
        permission_itemdef_drop.Clear();
    if (permission_itemdef_pickup == null)
        permission_itemdef_pickup = new ArrayList(sizeof(ItemDropPerm));
    else
        permission_itemdef_pickup.Clear();

    KeyValues kvs = new KeyValues("DropWeapon");
    char buffer[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, buffer, sizeof(buffer), "configs/dropweapon.cfg");
    if (FileExists(buffer)) {
        kvs.ImportFromFile(buffer);
        if (kvs.JumpToKey("action_drop")) {
            loadPermEntries(kvs, LEK_Drop);
            kvs.GoBack();
        } else {
            SetFailState("Configuration is missing block action_drop");
        }
        if (kvs.JumpToKey("action_pickup")) {
            loadPermEntries(kvs, LEK_Pickup);
            kvs.GoBack();
        } else {
            SetFailState("Configuration is missing block action_pickup");
        }
    } else {
        kvs.JumpToKey("action_drop", true);
        {
            kvs.SetString("primary", "everyone");
            kvs.SetString("secondary", "everyone");
            kvs.SetString("melee", "everyone");
            kvs.SetString("pda", "everyone");
            kvs.SetString("pda2", "everyone");
            kvs.SetString("building", "everyone");
            kvs.SetString("1152", "nobody");
        }
        kvs.GoBack();
        kvs.JumpToKey("action_pickup", true);
        {
            kvs.SetString("primary", "everyone");
            kvs.SetString("secondary", "everyone");
            kvs.SetString("melee", "everyone");
            kvs.SetString("pda", "everyone");
            kvs.SetString("pda2", "everyone");
            kvs.SetString("action", "everyone");
            kvs.SetString("building", "everyone");
        }
        kvs.GoBack();
        kvs.Rewind();
        kvs.ExportToFile(buffer);
        SetFailState("Generated configuration, please check it and reload the plugin");
    }
    delete kvs;
}

// ----- Utilities -----

/** quicker ArrayList search for unique, sorted lists using binary search */
static int BSearchList(ArrayList list, int value) {
    if (list.Length == 0) return -1;
    if (list.Length < 5) return list.FindValue(value);
    int max = list.Length-1;
    int min = 0;
    while (min <= max) {
        int center = (max+min)/2;
        int vat = list.Get(center);
        if (vat == value)
            return center;
        else if (vat < value)
            min = center+1;
        else
            max = center-1;
    }
    return -1;
}

static float hudspam_cooldown[MAXPLAYERS+1];
bool checkHudSpam(int client) {
    float now = GetGameTime();
    if (now - hudspam_cooldown[client] > 1.5) {
        hudspam_cooldown[client] = now;
        return true;
    }
    return false;
}

/** maps a weapons loadout slot to an arbitrary index, not related to weapon slots.
 * skips indices for cosmetics and stuff.
 * @return index [0..7] or -1 if not supported
 */
int LoadoutSlotToIndex(int loadoutSlot) {
    // primary, secondary, melee, utility, building, pda, pda2, head, misc, action
    // to
    // primary, secondary, melee, building, pda, pda2, utility, action
    static int mapping[10] = { 0, 1, 2, 6, 3, 4, 5, -1, -1, 7 };
    if (0 <= loadoutSlot < 10)
        return mapping[loadoutSlot];
    else 
        return -1;
}
