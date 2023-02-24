#include <sourcemod>
#include <sdkhooks>
#include <dhooks>

Handle sc_CopyAssignEconItemView;
Handle sc_DroppedWeaponCreate;
Handle sc_DroppedWeaponInit;
Handle sc_PickupOtherWeapon;
Handle sc_PickedUpWeaponInit;
Handle sc_WeaponGetWorldModel;
Handle sc_GiveNamedItem;
Handle sc_NextBestWeapon;
Handle sc_GetLoadoutItem;
Handle sc_GetBaseItem;
DynamicDetour dt_DroppedWeaponCreate;
int off_m_flSendPickupWeaponMessageTime;
int off_m_itemDefinitionIndexInEconItemView;
int off_DroppedWeapon_m_nClip;
int off_DroppedWeapon_m_nAmmo;
static Address addr_TFInventoryManager;
Handle sc_WeaponCanSwitchTo;
DynamicHook dh_WeaponDrop;


void InitHookData() {
	GameData data = new GameData("tfdropweapon.games");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(data, SDKConf_Signature, "CEconItemView::operator=()");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //Addr
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); //Addr
	if ((sc_CopyAssignEconItemView = EndPrepSDKCall()) == INVALID_HANDLE)
		SetFailState("Could not hook CEconItemView::operator=()");
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(data, SDKConf_Signature, "CTFDroppedWeapon::Create()");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //Addr
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((sc_DroppedWeaponCreate = EndPrepSDKCall()) == INVALID_HANDLE)
		SetFailState("Could not hook CTFDroppedWeapon::Create()");
	
	dt_DroppedWeaponCreate = DynamicDetour.FromConf(data, "CTFDroppedWeapon::Create()");
	if (dt_DroppedWeaponCreate == INVALID_HANDLE || !dt_DroppedWeaponCreate.Enable(Hook_Pre, DHook_WeaponCreate))
		SetFailState("Could not detour CTFDroppedWeapon::Create()");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(data, SDKConf_Signature, "CTFDroppedWeapon::InitDroppedWeapon()");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	if ((sc_DroppedWeaponInit = EndPrepSDKCall()) == INVALID_HANDLE)
		SetFailState("Could not hook CTFDroppedWeapon::InitDroppedWeapon()");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(data, SDKConf_Signature, "CTFDroppedWeapon::InitPickedUpWeapon()");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((sc_PickedUpWeaponInit = EndPrepSDKCall()) == INVALID_HANDLE)
		SetFailState("Could not hook CTFDroppedWeapon::InitPickedUpWeapon()");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(data, SDKConf_Signature, "CTFPlayer::PickupWeaponFromOther()");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((sc_PickupOtherWeapon = EndPrepSDKCall()) == INVALID_HANDLE)
		SetFailState("Could not hook CTFPlayer::PickupWeaponFromOther()");
	
	//returns on windows only?
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(data, SDKConf_Signature, "CBaseCombatCharacter::SwitchToNextBestWeapon()");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((sc_NextBestWeapon = EndPrepSDKCall()) == INVALID_HANDLE)
		SetFailState("Could not hook CBaseCombatCharacter::SwitchToNextBestWeapon()");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(data, SDKConf_Virtual, "CTFWeaponBase::GetWorldModel()");
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer, 0, VENCODE_FLAG_COPYBACK);
	if ((sc_WeaponGetWorldModel = EndPrepSDKCall()) == INVALID_HANDLE)
		SetFailState("Could not hook CTFWeaponBase::GetWorldModel()");
		
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(data, SDKConf_Virtual, "CTFPlayer::GiveNamedItem()");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //Addr
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	if ((sc_GiveNamedItem = EndPrepSDKCall()) == INVALID_HANDLE)
		SetFailState("Could not hook CTFPlayer::GiveNamedItem()");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(data, SDKConf_Signature, "CTFPlayer::GetLoadoutItem()");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); //Addr
	if ((sc_GetLoadoutItem = EndPrepSDKCall()) == INVALID_HANDLE)
		SetFailState("Could not hook CTFPlayer::GetLoadoutItem()");
	
	off_m_flSendPickupWeaponMessageTime = data.GetOffset("CTFPlayer::m_flSendPickupWeaponMessageTime");
	if (off_m_flSendPickupWeaponMessageTime < 0)
		SetFailState("Could not read CTFPlayer::m_flSendPickupWeaponMessageTime");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(data, SDKConf_Signature, "CTFInventoryManager::GetBaseItemForClass()");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); //Addr
	if ((sc_GetBaseItem = EndPrepSDKCall()) == INVALID_HANDLE)
		SetFailState("Could not hook CTFInventoryManager::GetBaseItemForClass()");
	
	{ // hack since idk the load base offset for server.dll/server_srv.so
		int relative = data.GetOffset("TFInventoryManager Offset");
		Address base = data.GetMemSig("CTFPlayer::GetLoadoutItem()");
		if (base == Address_Null || relative == -1)
			SetFailState("Could not load TFInventoryManager offset");
		addr_TFInventoryManager = base + view_as<Address>(relative);
	}
	
	off_DroppedWeapon_m_nClip = data.GetOffset("CTFDroppedWeapon::m_nClip");
	if (off_DroppedWeapon_m_nClip < 0)
		SetFailState("Could not read CTFDroppedWeapon::m_nClip");
	
	off_DroppedWeapon_m_nAmmo = data.GetOffset("CTFDroppedWeapon::m_nAmmo");
	if (off_DroppedWeapon_m_nAmmo < 0)
		SetFailState("Could not read CTFDroppedWeapon::m_nAmmo");
		
	delete data;
	
	data = new GameData("sdkhooks.games/engine.ep2v");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(data, SDKConf_Virtual, "Weapon_CanSwitchTo");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if ((sc_WeaponCanSwitchTo = EndPrepSDKCall()) == INVALID_HANDLE)
		SetFailState("Could not hook Weapon_CanSwitchTo");
	
	dh_WeaponDrop = new DynamicHook(data.GetOffset("Weapon_Drop"), HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity);
	dh_WeaponDrop.AddParam(HookParamType_CBaseEntity);
	dh_WeaponDrop.AddParam(HookParamType_VectorPtr, _, DHookPass_ByVal);
	dh_WeaponDrop.AddParam(HookParamType_VectorPtr, _, DHookPass_ByVal);
	
	delete data;
	
	// off_m_itemDefinitionIndexInEconItemView is computed from send prop info
	int off_econitemview = FindSendPropInfo("CTFWeaponBase", "m_Item");
	int off_itemdefindex = FindSendPropInfo("CTFWeaponBase", "m_iItemDefinitionIndex");
	off_m_itemDefinitionIndexInEconItemView = off_itemdefindex - off_econitemview;
	if (off_econitemview <= 0 || off_itemdefindex < 0 || off_m_itemDefinitionIndexInEconItemView < 0)
		SetFailState("Could not find CEconItemView::m_iItemDefinitionIndex");
}

// ----- Hook Wrapper -----


Address GetEconItemView(int weapon, const char[] cclass) {
	int offset = FindSendPropInfo(cclass, "m_Item");
	if (offset == -1) ThrowError("Can not find m_Item on %s", cclass);
	return GetEntityAddress(weapon)+view_as<Address>(offset);
}
void SetEconItemView(int weapon, const char[] cclass, Address source) {
	if (!IsValidEdict(weapon) || source == Address_Null) return;
	int offset = FindSendPropInfo(cclass, "m_Item");
	if (offset == -1) ThrowError("Can not find m_Item on %s", cclass);
	Address destination = GetEntityAddress(weapon)+view_as<Address>(offset);
	SDKCall(sc_CopyAssignEconItemView, destination, source);
	ChangeEdictState(weapon, offset);
}

void SwitchToPreviousWeaponOr(int client, int currentWeapon, int fallbackWeapon) {
	int prev = GetEntPropEnt(client, Prop_Send, "m_hLastWeapon");
	if (prev != INVALID_ENT_REFERENCE) {
		TF2Util_SetPlayerActiveWeapon(client, prev);
	} else if (fallbackWeapon != INVALID_ENT_REFERENCE) {
		TF2Util_SetPlayerActiveWeapon(client, fallbackWeapon);
	} else if (currentWeapon != INVALID_ENT_REFERENCE)
		SDKCall(sc_NextBestWeapon, client, currentWeapon);
}

int GiveNamedItem(int client, const char[] weaponclass, int subtype=0, Address item=Address_Null, bool force=true) {
	return SDKCall(sc_GiveNamedItem, client, weaponclass, subtype, item, force);
}

bool Weapon_CanSwitchTo(int client, int weapon) {
	return SDKCall(sc_WeaponCanSwitchTo, client, weapon);
}

Address GetLoadoutItemView(int client, TFClassType class, int slot) {
	if (!(1<=client<=MaxClients) || !IsClientInGame(client) || !IsClientAuthorized(client)) ThrowError("Invalid client index %i", client);
	if (class <= TFClass_Unknown || class > TFClass_Engineer) ThrowError("Invalid class type %i", class);
	if (slot < 0 || slot >= TF2Econ_GetLoadoutSlotCount()) ThrowError("Invalid slot %i", slot);
	return SDKCall(sc_GetLoadoutItem, client, class, slot, false);
}

Address GetBaseItemView(TFClassType class, int slot) {
	if (class <= TFClass_Unknown || class > TFClass_Engineer) ThrowError("Invalid class type %i", class);
	if (slot < 0 || slot >= TF2Econ_GetLoadoutSlotCount()) ThrowError("Invalid slot %i", slot);
	return SDKCall(sc_GetBaseItem, addr_TFInventoryManager, class, slot);
}

int GetItemViewItemDef(Address pItem) {
	if (pItem == Address_Null) return -1;
	return LoadFromAddress(pItem+view_as<Address>(off_m_itemDefinitionIndexInEconItemView), NumberType_Int16);
}

void SetDroppedWeaponAmmo(int droppedWeapon, int clip, int ammo) {
	SetEntData(droppedWeapon, off_DroppedWeapon_m_nClip, clip);
	SetEntData(droppedWeapon, off_DroppedWeapon_m_nAmmo, ammo);
}

public MRESReturn Weapon_Drop_EntityCallback(int pThis, DHookParam hParams) {
	if (!IsClientInGame(pThis) || !IsPlayerAlive(pThis)) {
		PrintToServer("Weapon_Drop called on invalid player");
		return MRES_Ignored;
	}
	int weapon = hParams.Get(1);
	
	float target[3];
	if (!hParams.IsNull(2)) hParams.GetVector(2, target);
	
	float velocity[3];
	if (!hParams.IsNull(3)) hParams.GetVector(3, velocity);
	
	if (weapon != INVALID_ENT_REFERENCE) DropWeapon(pThis, weapon, true, true, target, velocity);
	return MRES_Handled;
}