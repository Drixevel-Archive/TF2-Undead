//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define ATTRIBUTE_NAME "wunderwaffe"

//Sourcemod Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-tf>
#include <tf2-items>

//Globals
bool g_Setting_Wunderwaffe[MAX_ENTITY_LIMIT];
float g_Setting_Speed[MAX_ENTITY_LIMIT];
float g_Setting_Damage[MAX_ENTITY_LIMIT];
float g_Setting_Radius[MAX_ENTITY_LIMIT];

float g_Damage[MAX_ENTITY_LIMIT];
float g_Radius[MAX_ENTITY_LIMIT];

public Plugin myinfo = 
{
	name = "[TF2-Items] Attribute :: Wunderwaffe", 
	author = "Drixevel", 
	description = "An attribute which enables Wunderwaffe effects.", 
	version = "1.0.0", 
	url = "https://drixevel.dev/"
};

public void OnPluginStart()
{

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
	{
		g_Setting_Wunderwaffe[weapon] = true;
		attributesdata.GetValue("speed", g_Setting_Speed[weapon]);
		attributesdata.GetValue("damage", g_Setting_Damage[weapon]);
		attributesdata.GetValue("radius", g_Setting_Radius[weapon]);
	}
	else if (StrEqual(action, "remove", false))
	{
		g_Setting_Wunderwaffe[weapon] = false;
		g_Setting_Speed[weapon] = 0.0;
		g_Setting_Damage[weapon] = 0.0;
		g_Setting_Radius[weapon] = 0.0;
	}
}

public void OnEntityDestroyed(int entity)
{
	if (!IsValidEntity(entity))
		return;
	
	char sClassname[32];
	GetEntityClassname(entity, sClassname, sizeof(sClassname));

	float vecPosition[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vecPosition);

	if (StrEqual(sClassname, "tf_projectile_energy_ring"))
	{
		int client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

		if (client < 1 || client > MaxClients)
			return;

		int weapon = GetActiveWeapon(client);

		if (!IsValidEntity(weapon) || !g_Setting_Wunderwaffe[weapon])
			return;
		
		float vecAngles[3];
		GetClientEyeAngles(client, vecAngles);

		int projectile = CreateEntityByName("tf_projectile_energy_ball");

		if (IsValidEntity(projectile))
		{
			float vBuffer[3];
			GetAngleVectors(vecAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
			
			float vVelocity[3];
			vVelocity[0] = vBuffer[0] * g_Setting_Speed[weapon];
			vVelocity[1] = vBuffer[1] * g_Setting_Speed[weapon];
			vVelocity[2] = vBuffer[2] * g_Setting_Speed[weapon];

			TeleportEntity(projectile, vecPosition, vecAngles, vVelocity);

			SetEntData(projectile, FindSendPropInfo("CTFProjectile_Rocket", "m_iTeamNum"), GetClientTeam(client), true);
			SetEntData(projectile, FindSendPropInfo("CTFProjectile_Rocket", "m_bCritical"), false, true);
			SetEntPropEnt(projectile, Prop_Send, "m_hOwnerEntity", client);

			SetEntPropFloat(projectile, Prop_Data, "m_flRadius", g_Setting_Radius[weapon]);
			SetEntPropFloat(projectile, Prop_Data, "m_flModelScale", g_Setting_Radius[weapon]);

			DispatchSpawn(projectile);

			CreateParticle("critgun_weaponmodel_blu", vecPosition, 0.5);

			g_Damage[projectile] = g_Setting_Damage[weapon];
			g_Radius[projectile] = g_Setting_Radius[weapon];
		}
	}
	else if (StrEqual(sClassname, "tf_projectile_energy_ball"))
	{
		int client = GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity");

		if (client < 1 || client > MaxClients)
			return;
		
		int weapon = GetActiveWeapon(client);

		int zombie = -1; float vecZombiePos[3];
		while ((zombie = FindEntityByClassname(zombie, "base_boss")) != -1)
		{
			GetEntPropVector(zombie, Prop_Data, "m_vecOrigin", vecZombiePos);

			if (GetVectorDistance(vecPosition, vecZombiePos) <= g_Radius[entity])
				SDKHooks_TakeDamage(zombie, 0, client, g_Damage[entity], DMG_BLAST, weapon, NULL_VECTOR, vecZombiePos);
		}

		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) == GetClientTeam(client))
				continue;
			
			GetClientAbsOrigin(i, vecZombiePos);

			if (GetVectorDistance(vecPosition, vecZombiePos) <= g_Radius[entity])
				SDKHooks_TakeDamage(i, 0, client, g_Damage[entity], DMG_BLAST, weapon, NULL_VECTOR, vecZombiePos);
		}
	}
}