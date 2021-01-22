//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define ATTRIBUTE_NAME "raygun"

//Sourcemod Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-tf>
#include <tf2-items>

//Globals
bool g_Setting_Raygun[4096];

bool g_FlippedViewmodels[MAXPLAYERS + 1];
bool g_MinViewmodels[MAXPLAYERS + 1];

Handle g_hSDKWeaponGetDamage;
Handle g_hSDKRocketSetDamage;

public Plugin myinfo = 
{
	name = "[TF2-Items] Attribute :: Raygun", 
	author = "Drixevel", 
	description = "An attribute which enables Raygun effects.", 
	version = "1.0.0", 
	url = "https://drixevel.dev/"
};

public void OnPluginStart()
{
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(484);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	g_hSDKWeaponGetDamage = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(130);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	g_hSDKRocketSetDamage = EndPrepSDKCall();

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			OnClientPutInServer(i);
}

public void OnConfigsExecuted()
{
	if (TF2Items_AllowAttributeRegisters())
		TF2Items_OnRegisterAttributesPost();
}

public void TF2Items_OnRegisterAttributesPost()
{
	if (!TF2Items_RegisterAttribute(ATTRIBUTE_NAME, OnAttributeAction))
		LogError("Error while registering the '%s' attribute.", ATTRIBUTE_NAME);
}

public void OnAttributeAction(int client, int weapon, const char[] attrib, const char[] action, StringMap attributesdata)
{
	if (StrEqual(action, "apply", false))
		g_Setting_Raygun[weapon] = true;
	else if (StrEqual(action, "remove", false))
		g_Setting_Raygun[weapon] = false;
}

public void OnClientPutInServer(int client)
{
	//cl_flipviewmodels
	QueryClientConVar(client, "cl_flipviewmodels", OnParseFlippedViewmodels);
	QueryClientConVar(client, "tf_use_min_viewmodels", OnParseUseMinViewmodels);
}

public void OnParseFlippedViewmodels(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	g_FlippedViewmodels[client] = view_as<bool>(StringToInt(cvarValue));
}

public void OnParseUseMinViewmodels(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	g_MinViewmodels[client] = view_as<bool>(StringToInt(cvarValue));
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tf_projectile_arrow"))
		SDKHook(entity, SDKHook_Spawn, OnArrowCreated);
}

public void OnArrowCreated(int entity)
{
	if (!IsValidEntity(entity))
		return;
	
	int client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

	if (client == 0)
		return;
	
	int weapon = GetActiveWeapon(client);

	if (g_Setting_Raygun[weapon])
		ReplaceArrowProjectile(client, entity, weapon);
}

void ReplaceArrowProjectile(int client, int entity, int weapon)
{
	int hLauncher = weapon;

	float vecEyePosition[3];
	GetClientEyePosition(client, vecEyePosition);

	float vecEyeAngles[3];
	GetClientEyeAngles(client, vecEyeAngles);

	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecEyePosition);

	Handle trace = TR_TraceRayFilterEx(vecEyePosition, vecEyeAngles, MASK_SHOT, RayType_Infinite, TraceFilterSelf, client);

	float vecEndPosition[3];
	TR_GetEndPosition(vecEndPosition, trace);

	delete trace;

	float vecMagic[3];
	vecMagic[0] = vecEyeAngles[0];
	vecMagic[1] = vecEyeAngles[1];
	vecMagic[2] = vecEyeAngles[2];

	if (g_FlippedViewmodels[client])
		vecMagic[1] += 45.0;
	else
		vecMagic[1] -= 45.0;
	
	if (g_MinViewmodels[client])
		vecMagic[2] -= 50.0;

	float vecProjectileOffset[3];
	GetAngleVectors(vecMagic, vecProjectileOffset, NULL_VECTOR, NULL_VECTOR);

	ScaleVector(vecProjectileOffset, 25.0);

	float vecProjectileSource[3];
	AddVectors(vecEyePosition, vecProjectileOffset, vecProjectileSource);

	bool bCloseRange = GetVectorDistance(vecEyePosition, vecEndPosition, true) < 900.0;

	float vecVelocity[3];

	if (bCloseRange)
	{
		vecProjectileSource = vecEyePosition;
		GetAngleVectors(vecEyeAngles, vecVelocity, NULL_VECTOR, NULL_VECTOR);
	}
	else
		MakeVectorFromPoints(vecProjectileSource, vecEndPosition, vecVelocity);

	NormalizeVector(vecVelocity, vecVelocity);

	float flVelocityScalar = 1.0;
	Address pAttrib;
	if ((pAttrib = TF2Attrib_GetByName(hLauncher, "Projectile speed increased")) || (pAttrib = TF2Attrib_GetByName(hLauncher, "Projectile speed decreased")))
		flVelocityScalar = TF2Attrib_GetValue(pAttrib);

	ScaleVector(vecVelocity, 1000.0 * flVelocityScalar);

	int manglerShot = CreateEntityByName("tf_projectile_energy_ball");

	if (IsValidEntity(manglerShot))
	{
		AcceptEntityInput(entity, "Kill");

		SetEntPropEnt(manglerShot, Prop_Send, "m_hLauncher", hLauncher);
		SetEntPropEnt(manglerShot, Prop_Send, "m_hOriginalLauncher", hLauncher);
		SetEntPropEnt(manglerShot, Prop_Send, "m_hOwnerEntity", client);

		SetEntProp(manglerShot, Prop_Send, "m_fEffects", 16);

		// CTFWeaponBaseGun::GetProjectileDamage
		float damage = SDKCall(g_hSDKWeaponGetDamage, hLauncher);

		// CTFBaseRocket::SetDamage(float)
		SDKCall(g_hSDKRocketSetDamage, manglerShot, damage);

		SetEntProp(manglerShot, Prop_Send, "m_iTeamNum", TF2_GetClientTeam(client));

		DispatchKeyValueVector(manglerShot, "origin", vecProjectileSource);
		DispatchKeyValueVector(manglerShot, "basevelocity", vecVelocity);
		DispatchKeyValueVector(manglerShot, "velocity", vecVelocity);
		DispatchSpawn(manglerShot);

		SDKHook(manglerShot, SDKHook_StartTouch, RocketTouch);
	}
}

#define FSOLID_TRIGGER 0x8
#define FSOLID_VOLUME_CONTENTS 0x20

void RocketTouch(int rocket, int other)
{
	int solidFlags = GetEntProp(other, Prop_Send, "m_usSolidFlags");

	if (solidFlags & (FSOLID_TRIGGER | FSOLID_VOLUME_CONTENTS))
		return;

	EmitGameSoundToAll("Weapon_CowMangler.Explode", rocket);

	int client = GetEntPropEnt(rocket, Prop_Data, "m_hOwnerEntity");

	if (client == 0)
		return;

	float vecRocketPos[3];
	GetEntPropVector(rocket, Prop_Data, "m_vecOrigin", vecRocketPos);

	int entity = INVALID_ENT_INDEX;
	while ((entity = FindEntityByClassname(entity, "tf_zombie")) != INVALID_ENT_INDEX)
	{
		float vecZombiePos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vecZombiePos);

		if (GetVectorDistance(vecZombiePos, vecRocketPos) <= 80.0)
			SDKHooks_TakeDamage(entity, 0, client, 35.0, DMG_BLAST, GetActiveWeapon(client), NULL_VECTOR, vecRocketPos);
	}
}

public bool TraceFilterSelf(int entity, int contentsMask, int client)
{
	return entity != client;
}