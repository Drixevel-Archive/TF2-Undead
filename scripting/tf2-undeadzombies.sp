/*
- Zombies not taking damage
- Zombies inside each other walking in the same path
- Zombies stuck in the standing animation
- Sometimes can't walk into where a zombie once was
- I can repair the planks from a floor above where the window is
- I can repair the planks while dead
- Max Ammo sometimes doesn't refill any ammo
- Max Ammo doesn't refill any ammo on completely drained weapons
- Immense lag when there are a lot of zombies
- I can get stuck in a plank while repairing them
- No zombies spawning after a player joins spectator; upon joining back will fix
- Zombies go invisible and are stuck sometimes instead of dying
- Game told me how to revive myself after I was revived
*/

/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[TF2] Undead Zombies"
#define PLUGIN_DESCRIPTION "Undead Zombies is a gamemode which pits players vs AI and player controlled zombies."
#define PLUGIN_VERSION "1.0.4"

#define PHASE_HIBERNATION 0
#define PHASE_STARTING 1
#define PHASE_WAITING 2
#define PHASE_ACTIVE 3
#define PHASE_ENDING 4

#define LOBBY_TIME 20
#define MAX_ZOMBIES 25

#define ZOMBIE_HIT_DISTANCE 75.0
#define ZOMBIE_FACE_DISTANCE 300.0

#define ZOMBIE_MIN_DAMAGE 2.0
#define ZOMBIE_MAX_DAMAGE 8.0

/*****************************/
//Includes
#include <sourcemod>
#include <misc-sm>
#include <misc-tf>
#include <misc-colors>

#include <cbasenpc>
#include <cbasenpc/util>
#include <customkeyvalues>
#include <tf2-items>
#include <tf_econ_data>

/*****************************/
//ConVars

/*****************************/
//Globals
bool g_Late;

char sModels[10][PLATFORM_MAX_PATH] =
{
	"",
	"models/player/scout.mdl",
	"models/player/sniper.mdl",
	"models/player/soldier.mdl",
	"models/player/demo.mdl",
	"models/player/medic.mdl",
	"models/player/heavy.mdl",
	"models/player/pyro.mdl",
	"models/player/spy.mdl",
	"models/player/engineer.mdl"
};

char sZombieItems[10][PLATFORM_MAX_PATH] =
{
	"",
	"models/player/items/scout/scout_zombie.mdl",
	"models/player/items/sniper/sniper_zombie.mdl",
	"models/player/items/soldier/soldier_zombie.mdl",
	"models/player/items/demo/demo_zombie.mdl",
	"models/player/items/medic/medic_zombie.mdl",
	"models/player/items/heavy/heavy_zombie.mdl",
	"models/player/items/pyro/pyro_zombie.mdl",
	"models/player/items/spy/spy_zombie.mdl",
	"models/player/items/engineer/engineer_zombie.mdl"
};

char sBloodParticles[5][64] =
{
	"blood_impact_red_01",
	"blood_impact_red_01_chunk",
	"blood_impact_red_01_droplets",
	"blood_impact_red_01_goop",
	"blood_impact_red_01_smalldroplets",
};

char sHints[17][128] =
{
	"Revive your teammates by holding alt-fire near their revive markers.",
	"Interact with weapons, machines and the secret weapons chest by pressing 'MEDIC!' near them.",
	"Powerups sometimes drop when you kill zombies, pick them up to receive perks.",
	"Walk up to planks and press 'MEDIC!' to rebuild planks and gain points.",
	"Gain 10 points by hurting zombies and 100 points by killing zombies.",
	"Interact with a secret box to gain a random weapon, press 'MEDIC!' once a weapon is chosen to pick it up... or not.",
	"The machine 'Quick Revive' perk allows you to revive players at double the speeds.",
	"The machine 'Speed Cola' perk allows you to reload and deploy your weapons faster.",
	"The machine 'Juggernog' perk allows you to double your health pool.",
	"The machine 'Packapunch' perk allows you to buff one specific weapons damage, fire rate, reload speed and reload speeds.",
	"The machine 'Staminup' perk allows you to buff your movement speed.",
	"The machine 'Deadshot' perk allows you to fire penetrating projectiles.",
	"The machine 'Doubletap' perk allows you to increase the amount of bullets fired in single shots.",
	"The powerup 'Double Points' allows you to gain double the points for 20 seconds.",
	"The powerup 'Instant Kill' allows you to instantly kill all zombies for 20 seconds.",
	"The powerup 'Nuke' allows you to instantly nuke all zombies into oblivion... until they come back.",
	"The powerup 'Max Ammo' allows you to refill all your weapons mags and ammunition.",
};

//Match Data
enum struct Match
{
	int roundtime;
	Handle roundtimer;
	int roundphase;
	Hud hud_timer;
	int round;
	int difficulty;

	bool pausetimer;
	bool pausezombies;

	bool secret_unlocked;
	bool secret_found;

	void Initialize()
	{
		this.roundtime = 0;
		this.roundtimer = null;
		this.roundphase = PHASE_HIBERNATION;
		this.hud_timer = null;
		this.round = 0;
		
		this.pausetimer = false;
		this.pausezombies = false;

		this.secret_unlocked = false;
		this.secret_found = false;
	}
}

Match g_Match;

//Player Data
enum struct PlayerData
{
	int points;
	bool playing;

	bool zombie;
	float zombie_sounds;

	int revivemarker;
	int glow;
	int wearable;

	int interact;
	float delayhint;

	//interactables
	int nearmachine;
	int nearweapon;
	int nearbox;
	int nearplank;
	int nearsentry;

	//machines
	bool quickrevive;
	bool speedcola;
	bool juggernog;
	bool packapunch;
	bool staminup;
	bool deadshot;
	bool doubletap;

	//powerups
	int doublepoints;
	int instakill;

	//Cache
	int primary;
	int secondary;
	int melee;

	void Initialize()
	{
		this.revivemarker = INVALID_ENT_REFERENCE;
		this.glow = INVALID_ENT_REFERENCE;
		this.wearable = INVALID_ENT_REFERENCE;

		this.interact = -1;
		this.delayhint = -1.0;

		this.primary = -1;
		this.secondary = -1;
		this.melee = -1;
	}

	void Reset()
	{
		this.points = 500;

		this.zombie = false;
		this.zombie_sounds = -1.0;

		this.interact = -1;
		this.delayhint = -1.0;

		this.nearmachine = -1;
		this.nearweapon = -1;
		this.nearbox = -1;
		this.nearplank = -1;
		this.nearsentry = -1;

		this.quickrevive = false;
		this.speedcola = false;
		this.juggernog = false;
		this.packapunch = false;
		this.staminup = false;
		this.deadshot = false;
		this.doubletap = false;

		this.doublepoints = -1;
		this.instakill = -1;

		this.primary = -1;
		this.secondary = -1;
		this.melee = -1;
	}

	void SetPoints(int value)
	{
		this.points = value;
	}

	void AddPoints(int value)
	{
		this.points += value;

		if (this.points > 100000)
			this.points = 100000;
	}

	bool RemovePoints(int value)
	{
		if (this.points < value)
			return false;
		
		this.points -= value;
		return true;
	}
}

PlayerData g_PlayerData[MAXPLAYERS + 1];
Handle g_RegenTimer[MAXPLAYERS + 1];

//Zombies
enum struct ZombiesData
{
	int entity;
	PathFollower pPath;
	float g_flLastAttackTime;
	int g_Class;
	int g_Target;
	float g_TargetTicks;
	float g_ZombieSounds;
	bool spawnpowerups;

	void Reset()
	{
		this.entity = -1;
		this.g_flLastAttackTime = -1.0;
		this.g_Class = 0;
		this.g_Target = 0;
		this.g_TargetTicks = -1.0;
		this.g_ZombieSounds = -1.0;
		this.spawnpowerups = false;
	}
}

ZombiesData g_ZombiesData[MAX_NPCS];
int g_BreakingSounds[MAX_ENTITY_LIMIT + 1] = {-1, ...};

//Waves Timer
int g_WaveTime;
Handle g_WaveTimer;

Hud g_Sync_NearInteractable;

//MachinesData
enum struct MachinesData
{
	char name[64];
	char display[64];
	char description[128];
	char model[PLATFORM_MAX_PATH];
	float offsets[3];
}

MachinesData g_MachinesData[32];
int g_TotalMachines;

//Machines
enum struct Machines
{
	int index;
	int price;
	int unlock;
	
	void Reset()
	{
		this.index = -1;
		this.price = 0;
		this.unlock = -1;
	}
}

Machines g_Machines[MAX_ENTITY_LIMIT + 1];

//CustomWeaponsData
enum struct CustomWeaponsData
{
	char name[64];
	bool secret_box;
}

CustomWeaponsData g_CustomWeapons[128];
int g_TotalCustomWeapons;

//CUstomWeapons
enum struct CustomWeapons
{
	int index;
	int price;
	int unlock;
	float particle;
	int ammocost;
	int ammoupgrade;
	
	void Reset()
	{
		this.index = -1;
		this.price = 0;
		this.unlock = -1;
		this.particle = -1.0;
		this.ammocost = -1;
		this.ammoupgrade = -1;
	}
}

CustomWeapons g_SpawnedWeapons[MAX_ENTITY_LIMIT + 1];
int g_WeaponIndex[MAX_ENTITY_LIMIT + 1] = {-1, ...};
float g_RebuildDelay[MAX_ENTITY_LIMIT + 1] = {-1.0, ...};

//SecretBox
enum struct SecretBox
{
	bool status;
	int price;
	bool inuse;
	int glow;
	int unlock;

	void Reset()
	{
		this.status = false;
		this.price = 0;
		this.inuse = false;
		this.glow = -1;
		this.unlock = -1;
	}
}

SecretBox g_SecretBox[MAX_ENTITY_LIMIT + 1];

//Powerups
enum struct Powerups
{
	char name[64];
	char model[PLATFORM_MAX_PATH];
	char sound[PLATFORM_MAX_PATH];
	float timer;
}

Powerups g_Powerups[32];
int g_PowerupsCount;
int g_PowerupIndex[MAX_ENTITY_LIMIT + 1];

//Buildings
int g_RechargeBuilding[MAX_ENTITY_LIMIT + 1] = {-1, ...};
int g_DisableBuilding[MAX_ENTITY_LIMIT + 1] = {-1, ...};

/*****************************/
//Plugin Info
public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = "Drixevel", 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = "https://drixevel.dev/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_Late = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	CSetPrefix("{haunted}[{lawngreen}Undead{haunted}]");

	RegAdminCmd("sm_zombie", Command_SpawnZombie, ADMFLAG_GENERIC);
	RegAdminCmd("sm_spawnzombie", Command_SpawnZombie, ADMFLAG_GENERIC);
	RegAdminCmd("sm_randomzombie", Command_RandomZombie, ADMFLAG_GENERIC);
	RegAdminCmd("sm_spawnwave", Command_SpawnWave, ADMFLAG_GENERIC);

	RegAdminCmd("sm_start", Command_StartMatch, ADMFLAG_GENERIC);
	RegAdminCmd("sm_startmatch", Command_StartMatch, ADMFLAG_GENERIC);
	RegAdminCmd("sm_pausetimer", Command_PauseTimer, ADMFLAG_GENERIC);
	RegAdminCmd("sm_pausezombies", Command_PauseZombies, ADMFLAG_GENERIC);
	RegConsoleCmd("sm_playzombie", Command_PlayZombie);

	RegAdminCmd("sm_addpoints", Command_AddPoints, ADMFLAG_GENERIC);
	RegAdminCmd("sm_powerup", Command_SpawnPowerup, ADMFLAG_GENERIC);
	RegAdminCmd("sm_powerups", Command_SpawnPowerup, ADMFLAG_GENERIC);
	RegAdminCmd("sm_spawnpowerup", Command_SpawnPowerup, ADMFLAG_GENERIC);

	RegAdminCmd("sm_setangles", Command_SetAngles, ADMFLAG_GENERIC);
	RegAdminCmd("sm_setanglesnear", Command_SetAnglesNear, ADMFLAG_GENERIC);

	RegAdminCmd("sm_synclobby", Command_SyncLobby, ADMFLAG_GENERIC);

	g_Sync_NearInteractable = new Hud();

	AddNormalSoundHook(OnSoundPlay);

	for (int i = 0; i < MAX_NPCS; i++)
		g_ZombiesData[i].pPath = PathFollower(_, Path_FilterIgnoreActors, Path_FilterOnlyActors);
	
	int entity = -1; char class[64];
	while ((entity = FindEntityByClassname(entity, "*")) != -1)
	{
		GetEntityClassname(entity, class, sizeof(class));
		OnEntityCreated(entity, class);
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i))
			OnClientConnected(i);
		
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}
	
	SetupMachines();
	SetupCustomWeapons();
	SetupPowerups();

	g_Match.Initialize();
	g_Match.hud_timer = new Hud();

	HookEntityOutput("math_counter", "OutValue", OutValue);
	
	ConVar nb_update_frequency = FindConVar("nb_update_frequency");
	nb_update_frequency.FloatValue = 0.01;
	HookConVarChange(nb_update_frequency, Hook_BlockCvarValue);
	
	CreateTimer(0.6, Timer_ZombieTicks, _, TIMER_REPEAT);
}

public void Hook_BlockCvarValue(ConVar convar, const char[] oldValue, const char[] newValue)
{
	float flnewvalue = StringToFloat(newValue);
	
	if (flnewvalue > 0.01)
		convar.FloatValue = 0.01;
	else
		convar.FloatValue = flnewvalue;
}

public Action Command_SetAngles(int client, int args)
{
	int target = GetClientAimTarget(client, false);

	if (target == -1)
	{
		CPrintToChat(client, "Target not found, please aim your crosshair.");
		return Plugin_Handled;
	}

	float vecAngles[3];
	vecAngles[0] = GetCmdArgFloat(1);
	vecAngles[1] = GetCmdArgFloat(2);
	vecAngles[2] = GetCmdArgFloat(3);

	TeleportEntity(target, NULL_VECTOR, vecAngles, NULL_VECTOR);
	CPrintToChat(client, "Target angles set to: %.2f/%.2f/%.2f", vecAngles[0], vecAngles[1], vecAngles[2]);

	return Plugin_Handled;
}

public Action Command_SetAnglesNear(int client, int args)
{
	int target = GetNearestEntity(client, "prop_*");

	if (target == -1)
	{
		CPrintToChat(client, "Target not found, please aim your crosshair.");
		return Plugin_Handled;
	}

	float vecAngles[3];
	vecAngles[0] = GetCmdArgFloat(1);
	vecAngles[1] = GetCmdArgFloat(2);
	vecAngles[2] = GetCmdArgFloat(3);

	TeleportEntity(target, NULL_VECTOR, vecAngles, NULL_VECTOR);
	CPrintToChat(client, "Target angles set to: %.2f/%.2f/%.2f", vecAngles[0], vecAngles[1], vecAngles[2]);

	return Plugin_Handled;
}

public void OutValue(const char[] output, int caller, int activator, float delay)
{
	if (!IsName(caller, "secret_math_counter"))
		return;
	
	static int offset = -1;
    
	if (offset == -1)
		offset = FindDataMapInfo(caller, "m_OutValue");
	
	if (GetEntDataFloat(caller, offset) >= 4.0)
		g_Match.secret_found = false;
}

public void OnConfigsExecuted()
{
	FindConVar("mp_autoteambalance").IntValue = 0;

	FindConVar("mp_respawnwavetime").Flags = FindConVar("mp_respawnwavetime").Flags &= ~FCVAR_NOTIFY;
	FindConVar("mp_respawnwavetime").IntValue = 0;
	FindConVar("mp_scrambleteams_auto").IntValue = 0;

	if (g_Late)
	{
		g_Late = false;
		StartMatch();
	}
}

public void OnPluginEnd()
{
	g_Match.hud_timer.ClearAll();
	g_Sync_NearInteractable.ClearAll();

	KillAllZombies();
	DestroyMachines();
	DestroyWeapons();
	DestroySecretBoxes();
	DestroyPowerups();

	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			ClearGlow(i);
	
	LockRelays();
}

public void OnMapStart()
{
	for (int i = 0; i < 5; i++)
		PrecacheParticle(sBloodParticles[i]);
	
	PrecacheSound("weapons/fist_hit_world1.wav");
	PrecacheSound("weapons/fist_hit_world2.wav");
	
	PrecacheModel("models/props_lakeside_event/bomb_temp.mdl");
	PrecacheSound("weapons/pipe_bomb1.wav");
	PrecacheParticle("skull_island_explosion");
	
	//Zombie Sounds
	PrecacheSound("undead/zombies/undead_zombie01.wav");
	AddFileToDownloadsTable("sound/undead/zombies/undead_zombie01.wav");
	PrecacheSound("undead/zombies/undead_zombie02.wav");
	AddFileToDownloadsTable("sound/undead/zombies/undead_zombie02.wav");
	PrecacheSound("undead/zombies/undead_zombie03.wav");
	AddFileToDownloadsTable("sound/undead/zombies/undead_zombie03.wav");
	PrecacheSound("undead/zombies/undead_zombie05.wav");
	AddFileToDownloadsTable("sound/undead/zombies/undead_zombie04.wav");
	PrecacheSound("undead/zombies/undead_zombie04.wav");
	AddFileToDownloadsTable("sound/undead/zombies/undead_zombie05.wav");
	PrecacheSound("undead/zombies/undead_zombie06.wav");
	AddFileToDownloadsTable("sound/undead/zombies/undead_zombie06.wav");
	PrecacheSound("undead/zombies/undead_zombie07.wav");
	AddFileToDownloadsTable("sound/undead/zombies/undead_zombie07.wav");

	//Rounds
	PrecacheSound("undead/round_start.wav");
	AddFileToDownloadsTable("sound/undead/round_start.wav");

	PrecacheSound("undead/round_end.wav");
	AddFileToDownloadsTable("sound/undead/round_end.wav");
	
	//////////
	//Machines

	//Deadshot
	PrecacheModel("models/undead/machines/deadshot/deadshot.mdl");
	AddFileToDownloadsTable("models/undead/machines/deadshot/deadshot.mdl");
	AddFileToDownloadsTable("models/undead/machines/deadshot/deadshot.dx80.vtx");
	AddFileToDownloadsTable("models/undead/machines/deadshot/deadshot.dx90.vtx");
	AddFileToDownloadsTable("models/undead/machines/deadshot/deadshot.phy");
	AddFileToDownloadsTable("models/undead/machines/deadshot/deadshot.sw.vtx");
	AddFileToDownloadsTable("models/undead/machines/deadshot/deadshot.vvd");
	AddFileToDownloadsTable("materials/models/deadshot/zombie_vending_ads_c.vmt");
	AddFileToDownloadsTable("materials/models/deadshot/zombie_vending_ads_c.vtf");
	AddFileToDownloadsTable("materials/models/deadshot/zombie_vending_ads_glass.vmt");
	AddFileToDownloadsTable("materials/models/deadshot/zombie_vending_ads_glass.vtf");
	AddFileToDownloadsTable("materials/models/deadshot/zombie_vending_ads_logo_c.vmt");
	AddFileToDownloadsTable("materials/models/deadshot/zombie_vending_ads_logo_c.vtf");
	AddFileToDownloadsTable("materials/models/deadshot/zombie_vending_ads_logo_normal.vtf");
	AddFileToDownloadsTable("materials/models/deadshot/zombie_vending_ads_normal.vtf");

	//Doubletap
	PrecacheModel("models/undead/machines/doubletap/doubletap2.mdl");
	AddFileToDownloadsTable("models/undead/machines/doubletap/doubletap2.mdl");
	AddFileToDownloadsTable("models/undead/machines/doubletap/doubletap2.dx80.vtx");
	AddFileToDownloadsTable("models/undead/machines/doubletap/doubletap2.dx90.vtx");
	AddFileToDownloadsTable("models/undead/machines/doubletap/doubletap2.phy");
	AddFileToDownloadsTable("models/undead/machines/doubletap/doubletap2.sw.vtx");
	AddFileToDownloadsTable("models/undead/machines/doubletap/doubletap2.vvd");
	AddFileToDownloadsTable("materials/models/doubletap2/doubletap2_colour.vmt");
	AddFileToDownloadsTable("materials/models/doubletap2/doubletap2_colour.vtf");
	AddFileToDownloadsTable("materials/models/doubletap2/doubletap2_normal.vtf");
	AddFileToDownloadsTable("materials/models/doubletap2/doubletap2_vent.vmt");
	AddFileToDownloadsTable("materials/models/doubletap2/doubletap2_vent.vtf");

	//Juggernog
	PrecacheModel("models/undead/machines/juggernog/juggernog .mdl");
	AddFileToDownloadsTable("models/undead/machines/juggernog/juggernog .mdl");
	AddFileToDownloadsTable("models/undead/machines/juggernog/juggernog .dx80.vtx");
	AddFileToDownloadsTable("models/undead/machines/juggernog/juggernog .dx90.vtx");
	AddFileToDownloadsTable("models/undead/machines/juggernog/juggernog .phy");
	AddFileToDownloadsTable("models/undead/machines/juggernog/juggernog .sw.vtx");
	AddFileToDownloadsTable("models/undead/machines/juggernog/juggernog .vvd");
	AddFileToDownloadsTable("models/undead/machines/juggernog/juggernog .xbox.vtx");

	//Packapunch
	PrecacheModel("models/undead/machines/packapunch/packapunch.mdl");
	AddFileToDownloadsTable("models/undead/machines/packapunch/packapunch.mdl");
	AddFileToDownloadsTable("models/undead/machines/packapunch/packapunch.dx80.vtx");
	AddFileToDownloadsTable("models/undead/machines/packapunch/packapunch.dx90.vtx");
	AddFileToDownloadsTable("models/undead/machines/packapunch/packapunch.phy");
	AddFileToDownloadsTable("models/undead/machines/packapunch/packapunch.sw.vtx");
	AddFileToDownloadsTable("models/undead/machines/packapunch/packapunch.vvd");

	//Quickrevive
	PrecacheModel("models/undead/machines/quickrevive/quickrevive.mdl");
	AddFileToDownloadsTable("models/undead/machines/quickrevive/quickrevive.mdl");
	AddFileToDownloadsTable("models/undead/machines/quickrevive/quickrevive.dx80.vtx");
	AddFileToDownloadsTable("models/undead/machines/quickrevive/quickrevive.dx90.vtx");
	AddFileToDownloadsTable("models/undead/machines/quickrevive/quickrevive.phy");
	AddFileToDownloadsTable("models/undead/machines/quickrevive/quickrevive.sw.vtx");
	AddFileToDownloadsTable("models/undead/machines/quickrevive/quickrevive.vvd");

	//Speedcola
	PrecacheModel("models/undead/machines/speedcola/speedcola.mdl");
	AddFileToDownloadsTable("models/undead/machines/speedcola/speedcola.mdl");
	AddFileToDownloadsTable("models/undead/machines/speedcola/speedcola.dx80.vtx");
	AddFileToDownloadsTable("models/undead/machines/speedcola/speedcola.dx90.vtx");
	AddFileToDownloadsTable("models/undead/machines/speedcola/speedcola.phy");
	AddFileToDownloadsTable("models/undead/machines/speedcola/speedcola.sw.vtx");
	AddFileToDownloadsTable("models/undead/machines/speedcola/speedcola.vvd");
	AddFileToDownloadsTable("materials/models/perkacola/pack_a_punch_c.vmt");
	AddFileToDownloadsTable("materials/models/perkacola/pack_a_punch_c.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/pack_a_punch_moving_c.vmt");
	AddFileToDownloadsTable("materials/models/perkacola/pack_a_punch_moving_c.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/pack_a_punch_moving_n.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/pack_a_punch_n.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_perkbottle_jugg_n.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_perkbottle_sleight_c.vmt");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_perkbottle_sleight_c.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_doubletap_c.vmt");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_doubletap_c.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_doubletap_n.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_jugg_col.vmt");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_jugg_col.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_jugg_norm.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_revive_c.vmt");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_revive_c.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_revive_n.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_revsign_c.vmt");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_revsign_c.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_revsign_n.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_sleight_c.vmt");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_sleight_c.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_sleight_gc.vmt");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_sleight_gc.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_sleight_logo_c.vmt");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_sleight_logo_c.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_sleight_n.vtf");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_vent_power_on_c.vmt");
	AddFileToDownloadsTable("materials/models/perkacola/zombie_vending_vent_power_on_c.vtf");

	//Staminup
	PrecacheModel("models/undead/machines/staminup/staminup.mdl");
	AddFileToDownloadsTable("models/undead/machines/staminup/staminup.mdl");
	AddFileToDownloadsTable("models/undead/machines/staminup/staminup.dx80.vtx");
	AddFileToDownloadsTable("models/undead/machines/staminup/staminup.dx90.vtx");
	AddFileToDownloadsTable("models/undead/machines/staminup/staminup.phy");
	AddFileToDownloadsTable("models/undead/machines/staminup/staminup.sw.vtx");
	AddFileToDownloadsTable("models/undead/machines/staminup/staminup.vvd");
	AddFileToDownloadsTable("materials/models/staminup/_-gzombie_vending_marathon_c.vmt");
	AddFileToDownloadsTable("materials/models/staminup/_-gzombie_vending_marathon_c.vtf");
	AddFileToDownloadsTable("materials/models/staminup/zombie_vending_marathon_glass.vmt");
	AddFileToDownloadsTable("materials/models/staminup/zombie_vending_marathon_glass.vtf");
	AddFileToDownloadsTable("materials/models/staminup/zombie_vending_marathon_normal.vtf");

	//////////
	//Weapons

	//////////
	//Powerups
	AddFileToDownloadsTable("materials/models/undead/powerups/powerups.vmt");
	AddFileToDownloadsTable("materials/models/undead/powerups/powerups.vtf");
	AddFileToDownloadsTable("materials/models/undead/powerups/pyro_lightwarp.vtf");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_instant_kill.dx80.vtx");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_instant_kill.dx90.vtx");
	PrecacheModel("models/undead/powerups/undead_powerup_instant_kill.mdl");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_instant_kill.mdl");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_instant_kill.phy");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_instant_kill.sw.vtx");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_instant_kill.vvd");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_max_ammo.dx80.vtx");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_max_ammo.dx90.vtx");
	PrecacheModel("models/undead/powerups/undead_powerup_max_ammo.mdl");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_max_ammo.mdl");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_max_ammo.phy");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_max_ammo.sw.vtx");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_max_ammo.vvd");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_nuke.dx80.vtx");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_nuke.dx90.vtx");
	PrecacheModel("models/undead/powerups/undead_powerup_nuke.mdl");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_nuke.mdl");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_nuke.phy");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_nuke.sw.vtx");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_nuke.vvd");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_x2.dx80.vtx");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_x2.dx90.vtx");
	PrecacheModel("models/undead/powerups/undead_powerup_x2.mdl");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_x2.mdl");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_x2.phy");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_x2.sw.vtx");
	AddFileToDownloadsTable("models/undead/powerups/undead_powerup_x2.vvd");
	
	PrecacheSound("undead/powerups/powerup_double_points.wav");
	AddFileToDownloadsTable("sound/undead/powerups/powerup_double_points.wav");
	PrecacheSound("undead/powerups/powerup_grab.wav");
	AddFileToDownloadsTable("sound/undead/powerups/powerup_grab.wav");
	PrecacheSound("undead/powerups/powerup_instant_kill.wav");
	AddFileToDownloadsTable("sound/undead/powerups/powerup_instant_kill.wav");
	PrecacheSound("undead/powerups/powerup_loop.wav");
	AddFileToDownloadsTable("sound/undead/powerups/powerup_loop.wav");
	PrecacheSound("undead/powerups/powerup_max_ammo.wav");
	AddFileToDownloadsTable("sound/undead/powerups/powerup_max_ammo.wav");
	PrecacheSound("undead/powerups/powerup_nuke.wav");
	AddFileToDownloadsTable("sound/undead/powerups/powerup_nuke.wav");
	PrecacheSound("undead/powerups/powerup_spawn.wav");
	AddFileToDownloadsTable("sound/undead/powerups/powerup_spawn.wav");

	//////////
	//Secret Boxes
	PrecacheModel("models/noobis/mystery_box/mystery_box.mdl");
	AddFileToDownloadsTable("models/noobis/mystery_box/mystery_box.mdl");
	AddFileToDownloadsTable("models/noobis/mystery_box/mystery_box.dx80.vtx");
	AddFileToDownloadsTable("models/noobis/mystery_box/mystery_box.dx90.vtx");
	AddFileToDownloadsTable("models/noobis/mystery_box/mystery_box.phy");
	AddFileToDownloadsTable("models/noobis/mystery_box/mystery_box.sw.vtx");
	AddFileToDownloadsTable("models/noobis/mystery_box/mystery_box.vvd");
	AddFileToDownloadsTable("materials/noobis/mystery_box/box.vmt");
	AddFileToDownloadsTable("materials/noobis/mystery_box/box.vtf");
	AddFileToDownloadsTable("materials/noobis/mystery_box/box_n.vtf");
	AddFileToDownloadsTable("materials/noobis/mystery_box/hay.vmt");
	AddFileToDownloadsTable("materials/noobis/mystery_box/hay.vtf");
	AddFileToDownloadsTable("materials/noobis/mystery_box/hay_n.vtf");
	AddFileToDownloadsTable("materials/noobis/mystery_box/y1.vmt");
	AddFileToDownloadsTable("materials/noobis/mystery_box/y1.vtf");

	PrecacheSound("undead/mystery_box.wav");
	AddFileToDownloadsTable("sound/undead/mystery_box.wav");

	PrecacheSound("physics/wood/wood_crate_break4.wav");
}

public void OnMapEnd()
{
	StopTimer(g_Match.roundtimer);
	StopTimer(g_WaveTimer);
}

public void TF2_OnRoundStart(bool full_reset)
{
	if (g_Match.secret_unlocked)
	{
		int secret_door = FindEntityByName("bonus_level_door");

		if (IsValidEntity(secret_door))
			AcceptEntityInput(secret_door, "Open");
	}

	g_Match.roundphase = PHASE_HIBERNATION;

	if (GetTeamAbsCount(3) > 0)
		StartMatch();
}

void StartMatch()
{
	if (g_Match.roundphase != PHASE_HIBERNATION)
		return;
	
	TF2_RespawnAll();
	FindConVar("mp_disable_respawn_times").IntValue = 0;
	
	g_Match.roundtime = LOBBY_TIME;
	g_Match.round = 1;
	g_Match.roundphase = PHASE_STARTING;
	StopTimer(g_Match.roundtimer);
	g_Match.roundtimer = CreateTimer(1.0, Timer_RoundTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	for (int i = 1; i <= MaxClients; i++)
		g_PlayerData[i].Reset();
}

public Action Timer_RoundTimer(Handle timer)
{
	if (g_Match.roundtime > 1)
	{
		char sPaused[16];
		if (g_Match.pausetimer)
			strcopy(sPaused, sizeof(sPaused), " (Paused)");
		else
			g_Match.roundtime--;

		g_Match.hud_timer.SetParams(0.2, 0.8, 2.0, 255, 255, 255, 255);
		
		char sSpec[64];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;
			
			if (GetClientTeam(i) < 2)
				Format(sSpec, sizeof(sSpec), "\n(Please move from spectator to play)");
			else if (GetClientTeam(i) > 1 && !IsPlayerAlive(i))
				Format(sSpec, sizeof(sSpec), "\n(Respawning next round)");
			else
				sSpec[0] = '\0';
			
			char sTime[32];
			if (g_Match.roundtime > 60)
				FormatSeconds(float(g_Match.roundtime), sTime, sizeof(sTime), "%M:%S");
			else
				FormatSeconds(float(g_Match.roundtime), sTime, sizeof(sTime), "%S");
			
			switch (g_Match.roundphase)
			{
				case PHASE_STARTING:
					g_Match.hud_timer.Send(i, "Match is Starting: %s%s%s", sTime, sPaused, sSpec);
				case PHASE_WAITING:
					g_Match.hud_timer.Send(i, "Round %i - Next Round: %s%s\nPoints: %i%s", g_Match.round, sTime, sPaused, g_PlayerData[i].points, sSpec);
				case PHASE_ACTIVE:
					g_Match.hud_timer.Send(i, "Round %i - Round End: %s%s\nPoints: %i%s", g_Match.round, sTime, sPaused, g_PlayerData[i].points, sSpec);
			}
		}

		return Plugin_Continue;
	}

	switch (g_Match.roundphase)
	{
		case PHASE_STARTING:
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i))
					continue;
				
				if (GetClientTeam(i) == 3)
				{
					if (!IsPlayerAlive(i))
						TF2_RespawnPlayer(i);
					
					StripPlayer(i);
					SpeakResponseConcept(i, "TLK_MVM_WAVE_START");
				}
				else if (g_PlayerData[i].zombie && IsPlayerAlive(i))
					ForcePlayerSuicide(i);
			}

			TelePlayersToMap();
			FindConVar("mp_respawnwavetime").IntValue = 99999999;

			SpawnMachines();
			SpawnWeapons();
			SpawnSecretBoxes();
			SpawnRandomWeapons();
			SpawnPlanks();
			SetupSentries();

			g_WaveTime = GetRandomInt(15, 25);
			g_WaveTimer = CreateTimer(1.0, Timer_SpawnWave, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

			g_Match.roundtime = 120;
			g_Match.roundphase = PHASE_ACTIVE;
			EmitSoundToAll("undead/round_start.wav");

			return Plugin_Continue;
		}

		case PHASE_ACTIVE:
		{
			KillAllZombies();

			g_Match.roundtime = 30;
			g_Match.roundphase = PHASE_WAITING;
			EmitSoundToAll("undead/round_end.wav");

			TelePlayersToMap();
			UnlockRelays();
		}

		case PHASE_WAITING:
		{
			g_Match.roundtime = 120;
			g_Match.roundphase = PHASE_ACTIVE;
			EmitSoundToAll("undead/round_start.wav");
			g_Match.round++;

			if (g_Match.round > 10)
				g_Match.secret_unlocked = true;

			TelePlayersToMap();
		}
	}

	return Plugin_Continue;
}

void UnlockRelays()
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "logic_relay")) != -1)
		if (HasName(entity, "unlock_obstacle") && GetWaveUnlockInt(entity) <= (g_Match.round + 1))
			AcceptEntityInput(entity, "Trigger");
}

void LockRelays()
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "logic_relay")) != -1)
		if (HasName(entity, "lock_obstacle"))
			AcceptEntityInput(entity, "Trigger");
}

int GetWaveUnlockInt(int entity)
{
	if (!IsValidEntity(entity))
		return -1;
	
	char sWave[32];
	if (!GetCustomKeyValue(entity, "und_unlock_on_wave", sWave, sizeof(sWave)))
		return -1;
	
	int wave = StringToInt(sWave);
	
	if (wave == 0)
		wave = -1;

	return wave;
}

public Action Timer_SpawnWave(Handle timer)
{
	if (g_Match.roundphase != PHASE_ACTIVE || g_Match.pausetimer)
		return Plugin_Continue;
	
	if (g_WaveTime > 0)
	{
		g_WaveTime--;
		return Plugin_Continue;
	}

	int min = 1 + g_Match.round * (GetTeamAbsCount(3) / 2);
	int max = 2 + g_Match.round * (GetTeamAbsCount(3) / 2);

	SpawnWave(GetRandomInt(min, max));
	g_WaveTime = GetRandomInt(15, 25);

	return Plugin_Continue;
}

void TelePlayersToMap()
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "trigger_teleport")) != -1)
	{
		char sName[128];
		GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));

		if (StrEqual(sName, "game_start_teleport"))
		{
			SDKHook(entity, SDKHook_StartTouch, OnTeleTouch);
			AcceptEntityInput(entity, "Enable");
			AcceptEntityInput(entity, "Disable");
			SDKUnhook(entity, SDKHook_StartTouch, OnTeleTouch);
		}
	}
}

public Action OnTeleTouch(int entity, int other)
{
	if (other > 0 && other <= MaxClients && IsPlayerAlive(other))
		PrintHintText(other, "[Hint] %s", sHints[GetRandomInt(0, 16)]);
}

public void TF2_OnRoundEnd(int team, int winreason, int flagcaplimit, bool full_round, float round_time, int losing_team_num_caps, bool was_sudden_death)
{
	g_Match.roundphase = PHASE_ENDING;
	StopTimer(g_Match.roundtimer);
	StopTimer(g_WaveTimer);
	FindConVar("mp_respawnwavetime").IntValue = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		if (IsPlayerAlive(i) && team == 3 && GetClientTeam(i) == team)
			SpeakResponseConcept(i, "TLK_GAME_OVER_COMP");
		
		TF2Attrib_RemoveAll(i);

		int weapon;
		for (int x = 0; x < 5; x++)
			if ((weapon = GetPlayerWeaponSlot(i, x)) != -1)
				TF2Attrib_RemoveAll(weapon);
	}
}

public void TF2_OnPlayerDeath(int client, int attacker, int assister, int inflictor, int damagebits, int stun_flags, int death_flags, int customkill)
{
	if (g_Match.roundphase == PHASE_WAITING || g_Match.roundphase == PHASE_ACTIVE)
	{
		if (GetClientTeam(client) == 3)
		{
			int entity = CreateEntityByName("entity_revive_marker");

			if (IsValidEntity(entity))
			{
				float vecOrigin[3];
				GetClientAbsOrigin(client, vecOrigin);

				DispatchKeyValueVector(entity, "origin", vecOrigin);

				SetEntPropEnt(entity, Prop_Send, "m_hOwner", client);
				SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
				SetEntProp(entity, Prop_Send, "m_usSolidFlags", 8);
				SetEntProp(entity, Prop_Send, "m_fEffects", 16);
				SetEntProp(entity, Prop_Send, "m_iTeamNum", GetClientTeam(client));
				SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);
				SetEntProp(entity, Prop_Send, "m_bSimulatedEveryTick", 1);
				SetEntDataEnt2(client, FindSendPropInfo("CTFPlayer", "m_nForcedSkin") + 4, entity);
				SetEntProp(entity, Prop_Send, "m_nBody", view_as<int>(TF2_GetPlayerClass(client)) - 1);
				SetEntProp(entity, Prop_Send, "m_nSequence", 1);
				SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 1.0);
				SetEntProp(entity, Prop_Data, "m_iInitialTeamNum", GetClientTeam(client));

				DispatchSpawn(entity);

				g_PlayerData[client].revivemarker = EntIndexToEntRef(entity);

				g_PlayerData[client].primary = GetWeaponIndexBySlot(client, 0);
				g_PlayerData[client].secondary = GetWeaponIndexBySlot(client, 1);
				g_PlayerData[client].melee = GetWeaponIndexBySlot(client, 2);
			}
		}

		CreateTimer(0.5, Timer_ParseRoundEnd, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_ParseRoundEnd(Handle timer)
{
	if (GetTeamAliveCount(3) < 1)
		TF2_ForceWin(TFTeam_Red);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "item_currencypack_custom"))
		SDKHook(entity, SDKHook_Spawn, OnCurrencySpawn);
	
	if (StrEqual(classname, "trigger_teleport_relative", false) && IsName(entity, "survivor_blocker"))
	{
		SDKHook(entity, SDKHook_StartTouch, OnTeleportTouch);
		SDKHook(entity, SDKHook_Touch, OnTeleportTouch);
		SDKHook(entity, SDKHook_EndTouch, OnTeleportTouch);
	}

	if (StrEqual(classname, "func_brush") && IsName(entity, "player_blocker"))
		SDKHook(entity, SDKHook_Touch, OnBlockerTouch);
	
	if (entity > 0)
	{
		g_Machines[entity].Reset();
		g_SpawnedWeapons[entity].Reset();
	}
}

public Action OnCurrencySpawn(int entity)
{
	return Plugin_Stop;
}

public Action OnBlockerTouch(int entity, int other)
{
	if (other > MaxClients && IsClassname(other, "base_boss"))
		g_ZombiesData[other].spawnpowerups = true;
}

public Action OnTeleportTouch(int entity, int other)
{
	if (IsPlayerIndex(other) && GetClientTeam(other) == 2)
		return Plugin_Stop;
	
	return Plugin_Continue;
}

public void OnEntityDestroyed(int entity)
{
	if (entity > MaxClients)
		g_WeaponIndex[entity] = -1;
}

public Action Command_RandomZombie(int client, int args)
{
	SpawnRandomZombie();
	CPrintToChat(client, "A random zombie has been spawned.");
	return Plugin_Handled;
}

public Action Command_SpawnWave(int client, int args)
{
	int count = 5;

	if (args > 0)
		count = GetCmdArgInt(1);
	
	SpawnWave(count);
	CPrintToChat(client, "You have spawned a wave of %i zombies.", count);

	return Plugin_Handled;
}

void SpawnWave(int amount)
{
	int total = amount;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsPlayerAlive(i) || GetClientTeam(i) != 2 || !g_PlayerData[i].zombie || total <= 0)
			continue;
		
		TF2_RespawnPlayer(i);

		float origin[3]; float angles[3];
		GetRandomSpawn(origin, angles);
		TeleportEntity(i, origin, angles, NULL_VECTOR);

		total--;
	}

	for (int i = 0; i < total; i++)
		SpawnRandomZombie();
}

CBaseNPC SpawnRandomZombie(int pHealth = -1, int pClass = -1, int pTeam = -1)
{
	float origin[3]; float angles[3];
	GetRandomSpawn(origin, angles);

	GetGroundCoordinates(origin, origin);
	CBaseNPC zombie = SpawnZombie(origin, angles, pHealth, pClass, pTeam);

	return zombie;
}

bool GetRandomSpawn(float origin[3], float angles[3])
{
	int entities[MAX_ENTITY_LIMIT + 1];
	int count;

	int entity = -1; int unlock;
	while ((entity = FindEntityByClassname(entity, "info_target")) != -1)
	{
		if (!HasName(entity, "und_zombie"))
			continue;
		
		unlock = GetWaveUnlockInt(entity);
		
		if (unlock != -1 && unlock > g_Match.round)
			continue;
		
		entities[count++] = entity;
	}

	if (count < 1)
		return false;
	
	int chosen = entities[GetRandomInt(0, count - 1)];

	GetEntityOrigin(chosen, origin);
	GetEntityAngles(chosen, angles);

	return true;
}

public Action Command_SpawnZombie(int client, int args)
{
	int class = -1;

	if (args > 0)
		class = GetCmdArgInt(1);

	float origin[3];
	GetClientLookOrigin(client, origin);

	SpawnZombie(origin, NULL_VECTOR, -1, class);
	CPrintToChat(client, "You have spawned a zombie.");

	return Plugin_Handled;
}

CBaseNPC SpawnZombie(float origin[3], float angle[3] = NULL_VECTOR, int pHealth = -1, int pClass = -1, int pTeam = -1)
{
	int count = GetEntityCountEx("base_boss");
	
	if (count >= MAX_ZOMBIES)
	{
		PrintToServer("Failed to spawn zombie: Max Reached [%i/%i]", count, MAX_ZOMBIES);
		return INVALID_NPC;
	}
	
	origin[2] += 10.0;

	int class = pClass;

	if (class == -1)
		class = GetRandomInt(1, 9);
	else if (class < 1)
		class = 1;
	else if (class > 9)
		class = 9;
	
	if (angle[0]) {}

	CBaseNPC zombie = new CBaseNPC();
	zombie.Teleport(origin);
	zombie.SetModel(sModels[class]);
	zombie.Spawn();
	zombie.SetThinkFunction(Hook_NPCThink);
	zombie.SetOnTakeDamageAliveFunction(Hook_NPCDamage);
	zombie.SetOnTakeDamageAlivePostFunction(Hook_NPCDamagePost);
	zombie.nSkin = (class == 8) ? 22 : 4;
	
	zombie.EquipItem("head", sZombieItems[class]);
	
	//CBaseNPC_HookEventKilled(zombie.GetEntity());

	if (g_Match.secret_found)
		zombie.EquipItem("mvm", "models/props_lakeside_event/bomb_temp.mdl");
	
	int team = pTeam;

	if (team == -1)
		team = 2;
	
	zombie.iTeamNum = team;

	zombie.flStepSize = 18.0;
	zombie.flGravity = 800.0;
	zombie.flAcceleration = 4000.0;
	zombie.flJumpHeight = 85.0;
	zombie.flWalkSpeed = 150.0 * (1.0 + (g_Match.round * 0.05));
	zombie.flRunSpeed = 150.0 * (1.0 + (g_Match.round * 0.05));
	zombie.flDeathDropHeight = 2000.0;

	int basehealth = 75;

	if (class == view_as<int>(TFClass_Heavy))
		basehealth = 150;

	int health = pHealth;

	if (health == -1)
		health = (basehealth + (g_Match.round * 2));
	
	zombie.iMaxHealth = health;
	zombie.iHealth = health;
	
	zombie.Run();

	CBaseAnimatingOverlay animationEntity = CBaseAnimatingOverlay(zombie.GetEntity());
	animationEntity.PlayAnimation("Stand_MELEE");

	g_ZombiesData[zombie.Index].entity = zombie.GetEntity();
	g_ZombiesData[zombie.Index].g_flLastAttackTime = 0.0;
	g_ZombiesData[zombie.Index].g_Class = class;
	g_ZombiesData[zombie.Index].g_Target = -1;
	g_ZombiesData[zombie.Index].g_TargetTicks = -1.0;
	g_ZombiesData[zombie.Index].g_ZombieSounds = GetGameTime() + GetRandomFloat(10.0, 30.0);
	g_ZombiesData[zombie.Index].spawnpowerups = true;

	return zombie;
}

public Action Timer_ZombieTicks(Handle timer)
{
	int entity; CBaseNPC zombie; INextBot bot;
	for (int i = 0; i < MAX_NPCS; i++)
	{
		entity = g_ZombiesData[i].entity;
		zombie = TheNPCs.FindNPCByEntIndex(entity);
		
		if (zombie == INVALID_NPC)
			continue;
		
		bot = zombie.GetBot();
		
		if (g_Match.pausezombies)
		{
			g_ZombiesData[zombie.Index].pPath.ComputeToTarget(bot, entity);
			g_ZombiesData[zombie.Index].pPath.SetMinLookAheadDistance(ZOMBIE_FACE_DISTANCE);
		}
		else
		{
			int target = g_ZombiesData[zombie.Index].g_Target;

			if (target == -1 || !IsClientConnected(target) || !IsClientInGame(target) || !IsPlayerAlive(target) || GetClientTeam(target) != 3)
				g_ZombiesData[zombie.Index].g_Target = GetZombieTarget();
			
			if (g_ZombiesData[zombie.Index].g_Target != -1)
			{
				g_ZombiesData[zombie.Index].pPath.ComputeToTarget(bot, g_ZombiesData[zombie.Index].g_Target);
				g_ZombiesData[zombie.Index].pPath.SetMinLookAheadDistance(ZOMBIE_FACE_DISTANCE);
			}
			else
			{
				g_ZombiesData[zombie.Index].pPath.ComputeToTarget(bot, entity);
				g_ZombiesData[zombie.Index].pPath.SetMinLookAheadDistance(ZOMBIE_FACE_DISTANCE);
			}
		}
	}
}

public void Hook_NPCThink(int entity)
{
	CBaseNPC zombie = TheNPCs.FindNPCByEntIndex(entity);

	if (zombie == INVALID_NPC)
		return;

	INextBot bot = zombie.GetBot();
	NextBotGroundLocomotion loco = zombie.GetLocomotion();
	
	float vecNPCPos[3];
	bot.GetPosition(vecNPCPos);

	float vecNPCAng[3];
	GetEntPropVector(entity, Prop_Data, "m_angAbsRotation", vecNPCAng);

	float flMaxDistance = 9999999999999999.0;
	int iBestTarget = -1;
	
	float vecBuffer[3]; float flDistance;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) == zombie.iTeamNum)
			continue;
		
		GetClientAbsOrigin(i, vecBuffer);
		flDistance = GetVectorDistance(vecBuffer, vecNPCPos);
		
		if (flDistance < flMaxDistance)
		{
			flMaxDistance = flDistance;
			iBestTarget = i;
		}
	}
	
	float time = GetGameTime();
	if (g_ZombiesData[zombie].g_ZombieSounds != -1.0 && g_ZombiesData[zombie.Index].g_ZombieSounds <= time)
	{
		char sSound[PLATFORM_MAX_PATH];
		FormatEx(sSound, sizeof(sSound), "undead/zombies/undead_zombie0%i.wav", GetRandomInt(1, 7));
		EmitSoundToAll(sSound, entity);

		g_ZombiesData[zombie.Index].g_ZombieSounds = time + GetRandomFloat(5.0, 30.0);
	}

	CBaseAnimatingOverlay animationEntity = CBaseAnimatingOverlay(entity);

	if (iBestTarget == -1)
	{
		animationEntity.PlayAnimation("Stand_MELEE");
		return;
	}
	
	float vecTargetPos[3];
	GetClientAbsOrigin(iBestTarget, vecTargetPos);
	
	if (GetVectorDistance(vecNPCPos, vecTargetPos) > ZOMBIE_HIT_DISTANCE)
		g_ZombiesData[zombie.Index].pPath.Update(bot);
	else if (g_ZombiesData[zombie.Index].g_flLastAttackTime <= GetGameTime())
	{
		g_ZombiesData[zombie.Index].g_flLastAttackTime = GetGameTime() + 0.5;
		animationEntity.AddGestureSequence(animationEntity.LookupSequence("Melee_Swing"));
		
		SDKHooks_TakeDamage(iBestTarget, entity, entity, GetRandomFloat(ZOMBIE_MIN_DAMAGE, ZOMBIE_MAX_DAMAGE), DMG_SLASH);
		SpeakResponseConcept(iBestTarget, "TLK_PLAYER_PAIN");
		
		EmitSoundToAll(GetRandomInt(0, 1) == 0 ? "weapons/fist_hit_world1.wav" : "weapons/fist_hit_world2.wav", iBestTarget);

		StopTimer(g_RegenTimer[iBestTarget]);
		g_RegenTimer[iBestTarget] = CreateTimer(4.0, Timer_Regen, iBestTarget, TIMER_FLAG_NO_MAPCHANGE);
	}

	loco.FaceTowards(vecTargetPos);
	loco.Run();
	
	int iSequence = GetEntProp(entity, Prop_Send, "m_nSequence");
	
	int sequence_idle = animationEntity.LookupSequence("Stand_MELEE");
	int sequence_air_walk = animationEntity.LookupSequence("Airwalk_MELEE");
	int sequence_run = animationEntity.LookupSequence("run_MELEE");
	Address pModelptr = animationEntity.GetModelPtr();
	
	int iPitch = animationEntity.LookupPoseParameter(pModelptr, "body_pitch");
	int iYaw = animationEntity.LookupPoseParameter(pModelptr, "body_yaw");

	float vecNPCCenter[3];	
	animationEntity.WorldSpaceCenter(vecNPCCenter);
	
	float vecPlayerCenter[3];
	CBaseAnimating(iBestTarget).WorldSpaceCenter(vecPlayerCenter);
	
	float vecDir[3];
	SubtractVectors(vecNPCCenter, vecPlayerCenter, vecDir); 
	
	NormalizeVector(vecDir, vecDir);

	float vecAng[3];
	GetVectorAngles(vecDir, vecAng);
	
	float flPitch = animationEntity.GetPoseParameter(iPitch);
	float flYaw = animationEntity.GetPoseParameter(iYaw);
	
	vecAng[0] = UTIL_Clamp(UTIL_AngleNormalize(vecAng[0]), -44.0, 89.0);
	animationEntity.SetPoseParameter(pModelptr, iPitch, UTIL_ApproachAngle(vecAng[0], flPitch, 1.0));
	
	vecAng[1] = UTIL_Clamp(-UTIL_AngleNormalize(UTIL_AngleDiff(UTIL_AngleNormalize(vecAng[1]), UTIL_AngleNormalize(vecNPCAng[1] + 180.0))), -44.0,  44.0);
	animationEntity.SetPoseParameter(pModelptr, iYaw, UTIL_ApproachAngle(vecAng[1], flYaw, 1.0));
	
	int iMoveX = animationEntity.LookupPoseParameter(pModelptr, "move_x");
	int iMoveY = animationEntity.LookupPoseParameter(pModelptr, "move_y");
	
	if (iMoveX < 0 || iMoveY < 0)
		return;
	
	float flGroundSpeed = loco.GetGroundSpeed();

	if (flGroundSpeed != 0.0)
	{
		if (!(GetEntityFlags(entity) & FL_ONGROUND))
		{
			if (iSequence != sequence_air_walk)
				animationEntity.ResetSequence(sequence_air_walk);
		}
		else
		{			
			if (iSequence != sequence_run)
				animationEntity.ResetSequence(sequence_run);
		}

		float vecForward[3]; float vecRight[3]; float vecUp[3];
		zombie.GetVectors(vecForward, vecRight, vecUp);

		float vecMotion[3];
		loco.GetGroundMotionVector(vecMotion);

		float newMoveX = (vecForward[1] * vecMotion[1]) + (vecForward[0] * vecMotion[0]) +  (vecForward[2] * vecMotion[2]);
		float newMoveY = (vecRight[1] * vecMotion[1]) + (vecRight[0] * vecMotion[0]) + (vecRight[2] * vecMotion[2]);
		
		animationEntity.SetPoseParameter(pModelptr, iMoveX, newMoveX);
		animationEntity.SetPoseParameter(pModelptr, iMoveY, newMoveY);
	}
	else
	{
		if (iSequence != sequence_idle)
			animationEntity.ResetSequence(sequence_idle);
	}
}

int GetZombieTarget()
{
	int[] clients = new int[MaxClients];
	int amount;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || !IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != 3)
			continue;
		
		clients[amount++] = i;
	}

	return (amount == 0) ? -1 : clients[GetRandomInt(0, amount - 1)];
}

public Action Hook_NPCDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	CBaseNPC zombie = TheNPCs.FindNPCByEntIndex(victim);

	if (zombie == INVALID_NPC)
		return Plugin_Continue;

	if (IsPlayerIndex(attacker) && GetClientTeam(attacker) == zombie.iTeamNum)
		return Plugin_Continue;

	bool changed;
	if (IsPlayerIndex(attacker) && g_PlayerData[attacker].instakill != -1 && g_PlayerData[attacker].instakill > GetTime())
	{
		damage = 999999.0;
		changed = true;
	}
	
	return changed ? Plugin_Changed : Plugin_Continue;
}

public void Hook_NPCDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], float damagePosition[3], int damagecustom)
{
	CBaseNPC zombie = TheNPCs.FindNPCByEntIndex(victim);

	if (zombie == INVALID_NPC)
		return;

	if (GetRandomFloat(0.0, 100.0) >= 50.0)
		TE_Particle(sBloodParticles[GetRandomInt(0, 4)], damagePosition, victim);
	
	if (GetRandomFloat(0.0, 100.0) >= 75.0)
	{
		char sSound[PLATFORM_MAX_PATH];
		FormatEx(sSound, sizeof(sSound), "undead/zombies/undead_zombie0%i.wav", GetRandomInt(1, 7));
		EmitSoundToAll(sSound, victim);
	}

	if (IsPlayerIndex(attacker) && GetClientTeam(attacker) == zombie.iTeamNum)
		return;
	
	bool doublepoints;
	if (IsPlayerIndex(attacker))
		doublepoints = g_PlayerData[attacker].doublepoints != -1 && g_PlayerData[attacker].doublepoints > GetTime();
	
	if (RoundFloat(damage) >= zombie.iHealth)
	{
		float vecOrigin[3];
		GetEntityOrigin(victim, vecOrigin);

		if (GetRandomFloat(0.0, 100.0) <= 10.0 && g_ZombiesData[zombie].spawnpowerups)
			SpawnPowerup(vecOrigin);

		if (IsPlayerIndex(attacker))
			g_PlayerData[attacker].AddPoints(doublepoints ? 200 : 100);

		float vecAngles[3];
		GetEntityAngles(victim, vecAngles);
			
		TF2_CreateRagdoll(vecOrigin, vecAngles, g_ZombiesData[zombie].g_Class, zombie.iTeamNum, zombie.nSkin, 2.0, RAG_BECOMEASH);
		
		zombie.SetCollisionBounds(view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}));
		AcceptEntityInput(victim, "Kill");
	}
	else if (IsPlayerIndex(attacker))
		g_PlayerData[attacker].AddPoints(doublepoints ? 20 : 10);
}

public Action Command_StartMatch(int client, int args)
{
	StartMatch();
	return Plugin_Handled;
}

public void TF2_OnPlayerSpawn(int client, int team, int class)
{
	CreateTimer(0.2, Timer_DelaySpawn, GetClientUserId(client));
}

public Action Timer_DelaySpawn(Handle timer, any data)
{
	int client = GetClientOfUserId(data);

	if (!IsPlayerIndex(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	if (g_Match.roundphase == PHASE_STARTING)
		PrintHintText(client, "Type '!playzombie' in chat to plays as a Zombie next match.");
	
	ClearGlow(client);

	TF2Attrib_RemoveMoveSpeedBonus(client);
	TF2Attrib_RemoveMoveSpeedPenalty(client);

	if (g_PlayerData[client].zombie)
	{
		TF2_RemoveAllWearables(client);

		if (TF2_GetClientTeam(client) != TFTeam_Red)
			ChangeClientTeam_Alive(client, 2);
		
		int index;
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Scout: index = 5617;
			case TFClass_Soldier: index = 5618;
			case TFClass_Pyro: index = 5624;
			case TFClass_DemoMan: index = 5620;
			case TFClass_Heavy: index = 5619;
			case TFClass_Engineer: index = 5621;
			case TFClass_Medic: index = 5622;
			case TFClass_Sniper: index = 5625;
			case TFClass_Spy: index = 5623;
		}

		TF2Attrib_SetByName(client, "player skin override", 1.0);
		TF2_RegeneratePlayer(client);
		TF2_RemoveAllWearables(client);

		int wearable = -1;
		if ((wearable = TF2Items_EquipWearable(client, "tf_wearable", index, 0, 10)) != -1)
		{
			g_PlayerData[client].wearable = EntIndexToEntRef(wearable);
			TF2Attrib_SetByName(wearable, "player skin override", 1.0);
		}

		OverlayCommand(client, "effects/combine_binocoverlay");
		StripPlayer(client, true);

		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Scout:
				TF2Attrib_ApplyMoveSpeedPenalty(client, 0.5);
			case TFClass_Heavy:
				TF2Attrib_ApplyMoveSpeedPenalty(client, 0.13);
			case TFClass_Engineer:
				TF2Attrib_ApplyMoveSpeedPenalty(client, 0.34);
			case TFClass_Sniper:
				TF2Attrib_ApplyMoveSpeedPenalty(client, 0.34);
		}
	}
	else
	{
		TF2Attrib_RemoveByName(client, "player skin override");

		if (TF2_GetClientTeam(client) != TFTeam_Blue)
			ChangeClientTeam_Alive(client, 3);
		
		TFClassType class = TF2_GetPlayerClass(client);

		if (class != TFClass_Scout && class != TFClass_Heavy && class != TFClass_Engineer && class != TFClass_Sniper)
			TF2_SetPlayerClass(client, TFClass_Scout);
		
		TF2_RemoveAllWearables(client);
		TF2_RegeneratePlayer(client);

		OverlayCommand(client, "\"\"");
		StripPlayer(client, false);

		int glow = TF2_AttachBasicGlow(client);

		if (IsValidEntity(glow))
		{
			g_PlayerData[client].glow = EntIndexToEntRef(glow);
			SDKHook(glow, SDKHook_SetTransmit, OnGlowTransmit);
		}

		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Scout:
				TF2Attrib_ApplyMoveSpeedPenalty(client, 0.3);
			case TFClass_Heavy:
				TF2Attrib_ApplyMoveSpeedBonus(client, 0.2);
			case TFClass_Engineer:
				TF2Attrib_ApplyMoveSpeedPenalty(client, 0.1);
			case TFClass_Sniper:
				TF2Attrib_ApplyMoveSpeedPenalty(client, 0.1);
		}
	}
	
	if (g_Match.roundphase == PHASE_HIBERNATION)
		StartMatch();

	return Plugin_Stop;
}

int TF2_AttachBasicGlow(int entity)
{
	char model[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_ModelName", model, PLATFORM_MAX_PATH);
	
	if (strlen(model) != 0)
	{
		int prop = CreateEntityByName("tf_taunt_prop");
		
		if (IsValidEntity(prop))
		{
			DispatchSpawn(prop);

			SetEntityModel(prop, model);

			SetEntPropEnt(prop, Prop_Data, "m_hEffectEntity", entity);
			SetEntProp(prop, Prop_Send, "m_bGlowEnabled", 1);
			
			int iFlags = GetEntProp(prop, Prop_Send, "m_fEffects");
			
			SetEntProp(prop, Prop_Send, "m_fEffects", iFlags | EF_BONEMERGE | EF_NOSHADOW | EF_NOINTERP);

			SetVariantString("!activator");
			AcceptEntityInput(prop, "SetParent", entity);
			
			SetEntityRenderMode(prop, RENDER_TRANSCOLOR);
			SetEntityRenderColor(prop, 255, 0, 0, 0);
		}

		return prop;
	}

	return -1;
}

public Action OnGlowTransmit(int entity, int client)
{
	if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
		return Plugin_Continue;
	
	return Plugin_Stop;
}

void OverlayCommand(int client, char[] overlay) 
{    
	if (IsClientInGame(client)) 
	{
		SetCommandFlags("r_screenoverlay", GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT));
		ClientCommand(client, "r_screenoverlay %s", overlay);
	}
}

public void TF2_OnClassChangePost(int client, TFClassType class)
{
	StripPlayer(client);

	TF2Attrib_RemoveMoveSpeedBonus(client);
	TF2Attrib_RemoveMoveSpeedPenalty(client);
}

public Action Command_PauseTimer(int client, int args)
{
	g_Match.pausetimer = !g_Match.pausetimer;
	CPrintToChatAll("%N has %spaused the round timer.", client, g_Match.pausetimer ? "" : "un");
	return Plugin_Handled;
}

public Action Command_PauseZombies(int client, int args)
{
	g_Match.pausezombies = !g_Match.pausezombies;
	CPrintToChatAll("%N has %sfrozen the zombies.", client, g_Match.pausezombies ? "" : "un");
	return Plugin_Handled;
}

public void OnClientConnected(int client)
{
	g_PlayerData[client].Initialize();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_GetMaxHealth, OnGetMaxHealth);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_ThinkPost, OnClientThink);

	if (!g_Late)
	{
		ClientCommand(client, "jointeam blue");
		ClientCommand(client, "joinclass scout");
	}
}

public Action OnGetMaxHealth(int client, int &MaxHealth)
{
	if (IsPlayerIndex(client) && IsClientInGame(client))
	{
		if (g_PlayerData[client].zombie)
			MaxHealth = (15 + (g_Match.round * 2));
		else
			MaxHealth = g_PlayerData[client].juggernog ? 300 : 150;
		
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if (g_Match.roundphase == PHASE_STARTING)
	{
		damage = 0.0;
		return Plugin_Changed;
	}

	if (attacker > 0 && attacker <= MaxClients && g_PlayerData[attacker].zombie)
	{
		StopTimer(g_RegenTimer[victim]);
		g_RegenTimer[victim] = CreateTimer(4.0, Timer_Regen, victim, TIMER_FLAG_NO_MAPCHANGE);

		damage = GetRandomFloat(5.0, 15.0);
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public void OnClientThink(int client)
{
	if (g_PlayerData[client].zombie)
	{
		float time = GetGameTime();
		if (g_PlayerData[client].zombie_sounds != -1.0 && g_PlayerData[client].zombie_sounds <= time)
		{
			char sSound[PLATFORM_MAX_PATH];
			FormatEx(sSound, sizeof(sSound), "undead/zombies/undead_zombie0%i.wav", GetRandomInt(1, 7));
			EmitSoundToAll(sSound, client);

			g_PlayerData[client].zombie_sounds = time + GetRandomFloat(5.0, 30.0);
		}
	}
}

public Action Timer_Regen(Handle timer, any data)
{
	int victim = data;
	g_RegenTimer[victim] = null;

	if (IsClientInGame(victim) && IsPlayerAlive(victim))
		SetEntityHealth(victim, g_PlayerData[victim].juggernog ? 300 : 150);
}

public void OnClientDisconnect(int client)
{
	ClearGlow(client);
	CreateTimer(0.2, Timer_CheckPlayerCount, _, TIMER_FLAG_NO_MAPCHANGE);

	if (IsValidEntity(g_PlayerData[client].revivemarker))
		AcceptEntityInput(g_PlayerData[client].revivemarker, "Kill");
}

public Action Timer_CheckPlayerCount(Handle timer)
{
	if (GetTeamAbsCount(3) < 1)
	{
		g_Match.roundphase = PHASE_HIBERNATION;
		StopTimer(g_Match.roundtimer);
		StopTimer(g_WaveTimer);
	}
}

public void OnClientDisconnect_Post(int client)
{
	g_PlayerData[client].Reset();
	StopTimer(g_RegenTimer[client]);
}

public Action OnClientCommand(int client, int args)
{
	char sCommand[32];
	GetCmdArg(0, sCommand, sizeof(sCommand));

	char sArguments[32];
	GetCmdArgString(sArguments, sizeof(sArguments));

	if (StrEqual(sCommand, "joinclass", false) && !g_PlayerData[client].zombie)
	{
		//Scout, Heavy, Engineer, and Sniper
		if (StrContains(sArguments, "scout", false) == -1 && StrContains(sArguments, "heavy", false) == -1 && StrContains(sArguments, "engineer", false) == -1 && StrContains(sArguments, "sniper", false) == -1)
		{
			CPrintToChat(client, "You must be either a Scout, Heavy, Engineer or Sniper.");
			return Plugin_Stop;
		}
	}
	else if (StrEqual(sCommand, "eureka_teleport", false))
	{
		EmitGameSoundToClient(client, "Player.DenyWeaponSelection");
		CPrintToChat(client, "You are not allowed to use the Eureka Effect.");
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void OnGameFrame()
{
	if (g_Match.pausetimer)
		return;
	
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_dynamic")) != -1)
	{
		if (g_Machines[entity].index != -1)
			OnMachineTick(entity);
		
		if (g_SpawnedWeapons[entity].index != -1)
			OnWeaponTick(entity);
		
		if (g_SecretBox[entity].status)
			OnSecretBoxTick(entity);
	}

	entity = -1;
	while ((entity = FindEntityByClassname(entity, "func_brush")) != -1)
		if (HasName(entity, "plank_"))
			OnPlankTick(entity);

	entity = -1;
	while ((entity = FindEntityByClassname(entity, "obj_sentrygun")) != -1)
		OnSentryTick(entity);
}

public Action TF2_OnCallMedic(int client)
{
	if (g_Match.pausetimer)
		return Plugin_Stop;
	
	g_PlayerData[client].interact = GetTime() + 2;
	
	if (g_PlayerData[client].nearmachine != -1)
	{
		int entity = g_PlayerData[client].nearmachine;

		if (!g_PlayerData[client].RemovePoints(g_Machines[entity].price))
		{
			SpeakResponseConcept(client, "TLK_PLAYER_JEERS");
			EmitGameSoundToClient(client, "Player.DenyWeaponSelection");
		}
		else
		{
			SpeakResponseConcept(client, "TLK_PLAYER_CHEERS");
			EmitGameSoundToClient(client, "MVM.PlayerUpgraded");

			int index = g_Machines[entity].index;
			ApplyMachineEffects(client, index);
			CPrintToChat(client, "You have purchased the Machine perk: %s", g_MachinesData[index].display);

			g_PlayerData[client].nearmachine = -1;
			g_Sync_NearInteractable.Clear(client);
		}
	}

	if (g_PlayerData[client].nearweapon != -1)
	{
		int entity = g_PlayerData[client].nearweapon;
		int index = g_SpawnedWeapons[entity].index;

		char sClasses[2048];
		TF2Items_GetWeaponKeyString(g_CustomWeapons[index].name, "classes", sClasses, sizeof(sClasses));

		char sClass[32];
		TF2_GetClientClassName(client, sClass, sizeof(sClass));

		int price = g_SpawnedWeapons[entity].price;
		int slot = TF2Items_GetWeaponKeyInt(g_CustomWeapons[index].name, "slot");

		int weapon = GetPlayerWeaponSlot(client, slot);
		if (IsValidEntity(weapon) && g_WeaponIndex[weapon] == index)
			price *= 2;

		if (StrContains(sClasses, sClass, false) == -1 || !g_PlayerData[client].RemovePoints(price))
		{
			SpeakResponseConcept(client, "TLK_PLAYER_JEERS");
			EmitGameSoundToClient(client, "Player.DenyWeaponSelection");
		}
		else
		{
			SpeakResponseConcept(client, "TLK_MVM_LOOT_COMMON");
			EmitGameSoundToClient(client, "MVM.PlayerUpgraded");

			GiveWallWeapon(client, index);
			CPrintToChat(client, "You have purchased the Weapon: %s", g_CustomWeapons[index].name);

			g_PlayerData[client].nearweapon = -1;
			g_Sync_NearInteractable.Clear(client);
		}
	}

	if (g_PlayerData[client].nearbox != -1)
	{
		int entity = g_PlayerData[client].nearbox;

		if (g_SecretBox[entity].inuse || !g_PlayerData[client].RemovePoints(g_SecretBox[entity].price))
		{
			SpeakResponseConcept(client, "TLK_PLAYER_JEERS");
			EmitGameSoundToClient(client, "Player.DenyWeaponSelection");
		}
		else
		{
			EmitGameSoundToClient(client, "MVM.PlayerUpgraded");

			StartSecretBoxEvent(client, entity);
			CPrintToChat(client, "You have started a secret box event.");

			g_Sync_NearInteractable.Clear(client);
		}
	}

	if (g_PlayerData[client].nearplank != -1)
	{
		int entity = g_PlayerData[client].nearplank;

		if (!GetEntProp(entity, Prop_Data, "m_iDisabled") || (g_RebuildDelay[entity] != -1 && g_RebuildDelay[entity] > GetGameTime()) /*|| !g_PlayerData[client].RemovePoints(75)*/)
		{
			EmitGameSoundToClient(client, "Player.DenyWeaponSelection");
		}
		else
		{
			g_PlayerData[client].AddPoints(75);
			EmitGameSoundToClient(client, "MVM.PlayerUpgraded");

			SetPlankStatus(entity);
			CPrintToChat(client, "You have rebuilt a plank.");

			g_Sync_NearInteractable.Clear(client);
		}
	}
	
	if (g_PlayerData[client].nearsentry != -1)
	{
		int entity = g_PlayerData[client].nearsentry;
	
		char sCost[64];
		GetCustomKeyValue(entity, "udm_cost", sCost, sizeof(sCost));
	
		char sDuration[64];
		GetCustomKeyValue(entity, "udm_duration", sDuration, sizeof(sDuration));
		
		if (GetEntProp(entity, Prop_Send, "m_bDisabled") == 0 || g_RechargeBuilding[entity] != -1 && g_RechargeBuilding[entity] > GetTime() || !g_PlayerData[client].RemovePoints(StringToInt(sCost)))
		{
			EmitGameSoundToClient(client, "Player.DenyWeaponSelection");
		}
		else
		{
			EmitGameSoundToClient(client, "MVM.PlayerUpgraded");

			SetEntProp(entity, Prop_Send, "m_bDisabled", 0);
			g_DisableBuilding[entity] = GetTime() + StringToInt(sDuration);
			CPrintToChat(client, "You have rented this sentry.");
			
			g_Sync_NearInteractable.Clear(client);
		}
	}

	return Plugin_Stop;
}

/****************************************/
//Machines
/****************************************/

void SetupMachines()
{
	g_TotalMachines = 0;
	g_MachinesData[g_TotalMachines].name = "quickrevive";
	g_MachinesData[g_TotalMachines].display = "Quick Revive";
	g_MachinesData[g_TotalMachines].description = "Respawn players faster.";
	g_MachinesData[g_TotalMachines].model = "models/undead/machines/quickrevive/quickrevive.mdl";
	g_MachinesData[g_TotalMachines].offsets[2] -= 75.0;

	g_TotalMachines++;
	g_MachinesData[g_TotalMachines].name = "speedcola";
	g_MachinesData[g_TotalMachines].display = "Speed Cola";
	g_MachinesData[g_TotalMachines].description = "Decrease reload and switch time for weapons.";
	g_MachinesData[g_TotalMachines].model = "models/undead/machines/speedcola/speedcola.mdl";
	g_MachinesData[g_TotalMachines].offsets[2] -= 85.0;

	g_TotalMachines++;
	g_MachinesData[g_TotalMachines].name = "juggernog";
	g_MachinesData[g_TotalMachines].display = "Juggernog";
	g_MachinesData[g_TotalMachines].description = "Increase your healthpool.";
	g_MachinesData[g_TotalMachines].model = "models/undead/machines/juggernog/juggernog .mdl";
	g_MachinesData[g_TotalMachines].offsets[2] -= 80.0;

	g_TotalMachines++;
	g_MachinesData[g_TotalMachines].name = "packapunch";
	g_MachinesData[g_TotalMachines].display = "Packapunch";
	g_MachinesData[g_TotalMachines].description = "Upgrade your currently active weapons damage, fire rate and reload time.";
	g_MachinesData[g_TotalMachines].model = "models/undead/machines/packapunch/packapunch.mdl";
	g_MachinesData[g_TotalMachines].offsets[2] -= 60.0;

	g_TotalMachines++;
	g_MachinesData[g_TotalMachines].name = "staminup";
	g_MachinesData[g_TotalMachines].display = "Staminup";
	g_MachinesData[g_TotalMachines].description = "Increase your movement speed.";
	g_MachinesData[g_TotalMachines].model = "models/undead/machines/staminup/staminup.mdl";
	g_MachinesData[g_TotalMachines].offsets[2] -= 10.0;

	g_TotalMachines++;
	g_MachinesData[g_TotalMachines].name = "deadshot";
	g_MachinesData[g_TotalMachines].display = "Deadshot";
	g_MachinesData[g_TotalMachines].description = "Add projectile pentrations to your weapons.";
	g_MachinesData[g_TotalMachines].model = "models/undead/machines/deadshot/deadshot.mdl";
	g_MachinesData[g_TotalMachines].offsets[2] -= 10.0;

	g_TotalMachines++;
	g_MachinesData[g_TotalMachines].name = "doubletap";
	g_MachinesData[g_TotalMachines].display = "Doubletap";
	g_MachinesData[g_TotalMachines].description = "Increase the amount of bullets per shot.";
	g_MachinesData[g_TotalMachines].model = "models/undead/machines/doubletap/doubletap2.mdl";
	g_MachinesData[g_TotalMachines].offsets[2] -= 8.0;
}

void SpawnMachines()
{
	int entity = -1; int unlock;
	while ((entity = FindEntityByClassname(entity, "info_target")) != -1)
	{
		if (!HasName(entity, "onMachineSpawn"))
			continue;
		
		unlock = GetWaveUnlockInt(entity);
		
		char sMachine[64];
		GetCustomKeyValue(entity, "udm_machine", sMachine, sizeof(sMachine));

		char sCost[64];
		GetCustomKeyValue(entity, "udm_cost", sCost, sizeof(sCost));

		float origin[3];
		GetEntityOrigin(entity, origin);

		float angles[3];
		GetEntityAngles(entity, angles);

		int index = GetMachine(sMachine);

		if (index == -1 || !IsModelPrecached(g_MachinesData[index].model))
			continue;

		origin[0] += g_MachinesData[index].offsets[0];
		origin[1] += g_MachinesData[index].offsets[1];
		origin[2] += g_MachinesData[index].offsets[2];

		int machine = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(machine, "model", g_MachinesData[index].model);
		DispatchKeyValueVector(machine, "origin", origin);
		DispatchKeyValueVector(machine, "angles", angles);
		DispatchSpawn(machine);

		SetEntitySolidType(machine, SOLID_TYPE_VPHYSICS);
		SetEntityCollisionGroup(machine, COLLISION_GROUP_INTERACTIVE);

		TF2_CreateGlow("machine_color", machine, view_as<int>({200, 200, 255, 150}));

		g_Machines[machine].index = index;
		g_Machines[machine].price = StringToInt(sCost);
		g_Machines[machine].unlock = unlock;

		SDKHook(machine, SDKHook_OnTakeDamagePost, OnMachineDamage);
	}
}

public void OnMachineDamage(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	if (attacker == 0)
		return;
	
	int entity = CreateEntityByName("env_spark");
	DispatchKeyValueVector(entity, "origin", damagePosition);
	DispatchKeyValue(entity, "Magnitude", "4");
	DispatchKeyValue(entity, "MaxDelay", "3");
	DispatchKeyValue(entity, "TrailLength", "2");
	DispatchSpawn(entity);
	
	AcceptEntityInput(entity, "StartSpark");
	
	SetVariantString("OnUser1 !self:kill::0.3:1");
	AcceptEntityInput(entity, "AddOutput");
	
	AcceptEntityInput(entity, "FireUser1");
}

void OnMachineTick(int entity)
{
	int unlock = g_Machines[entity].unlock;
	int index = g_Machines[entity].index;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != 3)
			continue;
		
		if (IsVisibleTo(i, entity, 200.0, true, 75.0))
		{
			if (unlock <= g_Match.round)
			{
				g_PlayerData[i].nearmachine = entity;

				g_Sync_NearInteractable.SetParams(-1.0, 0.2, 2.0, 255, 255, 255, 255);
				g_Sync_NearInteractable.Send(i, "Press 'MEDIC!' to purchase %s for %i points.\n - %s", g_MachinesData[index].display, g_Machines[entity].price, g_MachinesData[index].description);
			}
			else
			{
				g_Sync_NearInteractable.SetParams(-1.0, 0.2, 2.0, 255, 255, 255, 255);
				g_Sync_NearInteractable.Send(i, "[Locked until round %i]", unlock);
			}
		}
		else if (g_PlayerData[i].nearmachine == entity)
		{
			g_PlayerData[i].nearmachine = - 1;
			g_Sync_NearInteractable.Clear(i);
		}
	}
}

int GetMachine(const char[] name)
{
	for (int i = 0; i <= g_TotalMachines; i++)
		if (StrEqual(name, g_MachinesData[i].name, false))
			return i;
	
	return -1;
}

void DestroyMachines()
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_dynamic")) != -1)
	{
		if (g_Machines[entity].index != -1)
			AcceptEntityInput(entity, "Kill");
		
		g_Machines[entity].Reset();
	}	
}

void ApplyMachineEffects(int client, int index = -1)
{
	if (StrEqual(g_MachinesData[index].name, "quickrevive", false) || g_PlayerData[client].quickrevive)
	{
		g_PlayerData[client].quickrevive = true;
	}
	
	if (StrEqual(g_MachinesData[index].name, "speedcola", false) || g_PlayerData[client].speedcola)
	{
		g_PlayerData[client].speedcola = true;

		TF2Attrib_SetByName(client, "Reload time decreased", 0.70);
		TF2Attrib_SetByName(client, "deploy time decreased", 0.70);
	}
	
	if (StrEqual(g_MachinesData[index].name, "juggernog", false) || g_PlayerData[client].juggernog)
	{
		g_PlayerData[client].juggernog = true;

		SetEntityHealth(client, 300);
	}
	else if (StrEqual(g_MachinesData[index].name, "packapunch", false))
	{
		g_PlayerData[client].packapunch = true;

		int weapon = GetActiveWeapon(client);

		if (IsValidEntity(weapon))
		{
			TF2Attrib_SetByName(weapon, "damage bonus", 1.30);
			TF2Attrib_SetFireRateBonus(weapon, 0.30);
			TF2Attrib_SetByName(weapon, "Reload time decreased", 0.70);
			TF2Attrib_SetByDefIndex(weapon, 134, g_SpawnedWeapons[weapon].particle);
		}
	}
	else if (StrEqual(g_MachinesData[index].name, "staminup", false))
	{
		g_PlayerData[client].staminup = true;

		TF2Attrib_SetByName(client, "move speed bonus", 1.70);
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.0);
	}
	else if (StrEqual(g_MachinesData[index].name, "deadshot", false))
	{
		g_PlayerData[client].deadshot = true;

		for (int i = 0; i < 5; i++)
		{
			int weapon = GetPlayerWeaponSlot(client, i);

			if (IsValidEntity(weapon))
			{
				TF2Attrib_SetByName(weapon, "projectile penetration", 1.0);
				TF2Attrib_SetByName(weapon, "energy weapon penetration", 1.0);
				TF2Attrib_SetByName(weapon, "projectile penetration heavy", 1.0);
			}
		}
	}
	else if (StrEqual(g_MachinesData[index].name, "doubletap", false))
	{
		g_PlayerData[client].doubletap = true;

		for (int i = 0; i < 5; i++)
		{
			int weapon = GetPlayerWeaponSlot(client, i);

			if (IsValidEntity(weapon))
			{
				TF2Attrib_SetFireRateBonus(weapon, 0.30);
				TF2Attrib_SetByName(weapon, "bullets per shot bonus", 2.0);
			}
		}
	}
}

void TF2Attrib_SetFireRateBonus(int weapon, float bonus)
{
	float firerate;
	Address addr = TF2Attrib_GetByName(weapon, "fire rate bonus");

	firerate = addr != Address_Null ? TF2Attrib_GetValue(addr) : 1.00 - bonus;
	TF2Attrib_SetByName(weapon, "fire rate bonus", firerate);
}

/****************************************/
//Weapons
/****************************************/

void SetupCustomWeapons()
{
	g_TotalCustomWeapons = 0;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Raiding Aid";

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Steel Battalion";

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Twenty-Six Shooter";

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Bolshevik Bomber";

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Maxim GUN";

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Soviet Sweeper";

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Co's Jewel";

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Pseudonailgun";

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Tempest";

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Broomhandle Backup";

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Burping Blaster";

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Point Man's Carbine";

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Arms Racer Engineer";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Big MAC Engineer";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Gonzo Piece Engineer";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Raygun Engineer";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Kanopy Killer Engineer";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Tactigatling Engineer";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Wunderwaffe DG2";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Arms Racer Heavy";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Graphite Perisher";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Heavy Artillery";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Persistent Persuasion";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Portable Ordnance";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Kanopy Killer Heavy";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Tactigatling Heavy";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Big Iron";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Big MAC";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Blundergat";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Boston Bulldog";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Desk Fan";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Gonzo Piece";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Hand Cannon";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Raygun";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Kanopy Killer Scout";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "AK47";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Brief Negotiator";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Country Killer";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Lil Mate";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Fruit Shop Fiend";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Manncannon";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;

	g_TotalCustomWeapons++;
	g_CustomWeapons[g_TotalCustomWeapons].name = "Moonbeam";
	g_CustomWeapons[g_TotalCustomWeapons].secret_box = true;
}

void SpawnWeapons()
{
	int entity = -1; int unlock;
	while ((entity = FindEntityByClassname(entity, "info_target")) != -1)
	{
		if (!HasName(entity, "onWeaponSpawn"))
			continue;
		
		unlock = GetWaveUnlockInt(entity);
		
		char sWeapon[64];
		GetCustomKeyValue(entity, "udm_weapon", sWeapon, sizeof(sWeapon));

		char sParticle[64];
		GetCustomKeyValue(entity, "udm_particleupgrade", sParticle, sizeof(sParticle));

		char sCost[64];
		GetCustomKeyValue(entity, "udm_cost", sCost, sizeof(sCost));

		char sAmmoCost[64];
		GetCustomKeyValue(entity, "udm_ammocost", sAmmoCost, sizeof(sAmmoCost));

		char sAmmoUpgrade[64];
		GetCustomKeyValue(entity, "udm_ammoupgrade", sAmmoUpgrade, sizeof(sAmmoUpgrade));

		float origin[3];
		GetEntityOrigin(entity, origin);

		float angles[3];
		GetEntityAngles(entity, angles);

		int index = GetCustomWeaponIndex(sWeapon);

		if (index == -1)
			continue;
		
		char sWorldmodel[PLATFORM_MAX_PATH];
		if (!TF2Items_GetWeaponKeyString(sWeapon, "worldmodel", sWorldmodel, sizeof(sWorldmodel)) || !IsModelPrecached(sWorldmodel))
			continue;

		int weapon = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(weapon, "model", sWorldmodel);
		DispatchKeyValueVector(weapon, "origin", origin);
		DispatchKeyValueVector(weapon, "angles", angles);
		DispatchSpawn(weapon);

		TF2_CreateGlow("weapon_color", weapon, view_as<int>({255, 200, 200, 150}));

		g_SpawnedWeapons[weapon].index = index;
		g_SpawnedWeapons[weapon].price = StringToInt(sCost);
		g_SpawnedWeapons[weapon].unlock = unlock;
		g_SpawnedWeapons[weapon].particle = StringToFloat(sParticle);
		g_SpawnedWeapons[weapon].ammocost = StringToInt(sAmmoCost);
		g_SpawnedWeapons[weapon].ammoupgrade = StringToInt(sAmmoUpgrade);
	}
}

int GetCustomWeaponIndex(const char[] name)
{
	for (int i = 0; i <= g_TotalCustomWeapons; i++)
		if (StrEqual(name, g_CustomWeapons[i].name, false))
			return i;
	
	return -1;
}

void OnWeaponTick(int entity)
{
	int unlock = g_SpawnedWeapons[entity].unlock;
	int index = g_SpawnedWeapons[entity].index;

	char sClasses[2048];
	TF2Items_GetWeaponKeyString(g_CustomWeapons[index].name, "classes", sClasses, sizeof(sClasses));
	sClasses[0] = CharToUpper(sClasses[0]);

	char sRepurchase[16];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != 3)
			continue;
		
		sRepurchase[0] = '\0';

		if (IsVisibleTo(i, entity, 90.0, true))
		{
			if (unlock <= g_Match.round)
			{
				int price = g_SpawnedWeapons[entity].price;
				int slot = TF2Items_GetWeaponKeyInt(g_CustomWeapons[index].name, "slot");

				int weapon = GetPlayerWeaponSlot(i, slot);
				if (IsValidEntity(weapon) && g_WeaponIndex[weapon] == index)
				{
					strcopy(sRepurchase, sizeof(sRepurchase), "re");
					price *= 2;
				}

				g_PlayerData[i].nearweapon = entity;

				g_Sync_NearInteractable.SetParams(-1.0, 0.2, 2.0, 255, 255, 255, 255);
				g_Sync_NearInteractable.Send(i, "Press 'MEDIC!' to %spurchase %s for %i points. (%s Only)", sRepurchase, g_CustomWeapons[index].name, price, sClasses);
			}
			else
			{
				g_Sync_NearInteractable.SetParams(-1.0, 0.2, 2.0, 255, 255, 255, 255);
				g_Sync_NearInteractable.Send(i, "[Locked until round %i]", unlock);
			}
		}
		else if (g_PlayerData[i].nearweapon == entity)
		{
			g_PlayerData[i].nearweapon = -1;
			g_Sync_NearInteractable.Clear(i);
		}
	}
}

void DestroyWeapons()
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_dynamic")) != -1)
	{
		if (g_SpawnedWeapons[entity].index != -1)
			AcceptEntityInput(entity, "Kill");
		
		g_SpawnedWeapons[entity].Reset();
	}	
}

void GiveWallWeapon(int client, int index)
{
	int weapon = TF2Items_GiveWeapon(client, g_CustomWeapons[index].name);
	
	if (IsValidEntity(weapon))
		g_WeaponIndex[weapon] = index;
}

/****************************************/
//Powerups
/****************************************/

void SetupPowerups()
{
	g_PowerupsCount = 0;
	g_Powerups[g_PowerupsCount].name = "Double Points";
	g_Powerups[g_PowerupsCount].model = "models/undead/powerups/undead_powerup_x2.mdl";
	g_Powerups[g_PowerupsCount].sound = "undead/powerups/powerup_double_points.wav";
	g_Powerups[g_PowerupsCount].timer = 20.0;

	g_PowerupsCount++;
	g_Powerups[g_PowerupsCount].name = "Instant Kill";
	g_Powerups[g_PowerupsCount].model = "models/undead/powerups/undead_powerup_instant_kill.mdl";
	g_Powerups[g_PowerupsCount].sound = "undead/powerups/powerup_instant_kill.wav";
	g_Powerups[g_PowerupsCount].timer = 20.0;

	g_PowerupsCount++;
	g_Powerups[g_PowerupsCount].name = "Nuke";
	g_Powerups[g_PowerupsCount].model = "models/undead/powerups/undead_powerup_nuke.mdl";
	g_Powerups[g_PowerupsCount].sound = "undead/powerups/powerup_nuke.wav";

	g_PowerupsCount++;
	g_Powerups[g_PowerupsCount].name = "Max Ammo";
	g_Powerups[g_PowerupsCount].model = "models/undead/powerups/undead_powerup_max_ammo.mdl";
	g_Powerups[g_PowerupsCount].sound = "undead/powerups/powerup_max_ammo.wav";
}

public Action Command_SpawnPowerup(int client, int args)
{
	if (args == 0)
	{
		OpenPowerupsMenu(client);
		return Plugin_Handled;
	}

	int index = GetCmdArgInt(1);

	float origin[3];
	GetClientLookOrigin(client, origin);

	CPrintToChat(client, "Spawning Powerup %i: %s", index, g_Powerups[index].name);
	SpawnPowerup(origin, index);

	return Plugin_Handled;
}

void OpenPowerupsMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Powerups);
	menu.SetTitle("Pick a Powerup:");

	char sIndex[16];
	for (int i = 0; i <= g_PowerupsCount; i++)
	{
		IntToString(i, sIndex, sizeof(sIndex));
		menu.AddItem(sIndex, g_Powerups[i].name);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Powerups(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sIndex[16];
			menu.GetItem(param2, sIndex, sizeof(sIndex));
			
			float origin[3];
			GetClientLookOrigin(param1, origin);

			int index = StringToInt(sIndex);
			
			CPrintToChat(param1, "Spawning Powerup %i: %s", index, g_Powerups[index].name);
			SpawnPowerup(origin, index);
		}
		case MenuAction_End:
			delete menu;
	}
}

void SpawnPowerup(float origin[3], int index = -1)
{
	if (index == -1)
		index = GetRandomInt(0, g_PowerupsCount);

	int entity = CreateEntityByName("tf_halloween_pickup");
	DispatchKeyValueVector(entity, "origin", origin);
	DispatchKeyValueVector(entity, "basevelocity", view_as<float>({0.0, 0.0, 200.0}));
	DispatchKeyValueVector(entity, "velocity", view_as<float>({0.0, 0.0, 200.0}));
	//DispatchKeyValue(entity, "pickup_particle", g_Powerups[index].particle);
	//DispatchKeyValue(entity, "pickup_sound", g_Powerups[index].sound);
	DispatchKeyValue(entity, "powerup_model", g_Powerups[index].model);
	DispatchSpawn(entity);

	EmitSoundToAll("undead/powerups/powerup_spawn.wav", entity);

	SetEntityMoveType(entity, MOVETYPE_FLYGRAVITY);
	//SetEntProp(entity, Prop_Data, "m_iEFlags", 35913728);
	SetEntProp(entity, Prop_Data, "m_MoveCollide", 1);

	char sBuffer[128];
	FormatEx(sBuffer, sizeof(sBuffer), "OnUser1 !self:kill::30:1");

	SetVariantString(sBuffer);
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");

	g_PowerupIndex[entity] = index;
	SDKHook(entity, SDKHook_Touch, OnPowerupTouch);

	TriggerTimer(CreateTimer(1.0, Timer_Sound, EntIndexToEntRef(entity), TIMER_REPEAT), true);
}

public Action Timer_Sound(Handle timer, any data)
{
	int entity = EntRefToEntIndex(data);
	
	if (IsValidEntity(entity))
	{
		float position[3];
		GetEntityOrigin(entity, position);
		
		//EmitSoundToAll("undead/powerups/powerup_loop.wav", entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, entity, position, NULL_VECTOR, true, 0.0);
	}
}

public Action OnPowerupTouch(int entity, int other)
{
	if (!IsPlayerIndex(other) || GetClientTeam(other) != 3)
		return Plugin_Stop;
	
	//EmitSoundToAll("undead/powerups/powerup_loop.wav", entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_STOPLOOPING, SNDVOL_NORMAL, SNDPITCH_NORMAL, entity, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	
	int index = g_PowerupIndex[entity];
	g_PowerupIndex[entity] = -1;

	switch (index)
	{
		//double points
		case 0:
			g_PlayerData[other].doublepoints = GetTime() + RoundFloat(g_Powerups[index].timer);
		//insta kill
		case 1:
			g_PlayerData[other].instakill = GetTime() + RoundFloat(g_Powerups[index].timer);
		//nuke
		case 2:
			KillAllZombies();
		//max ammo
		case 3:
		{
			int active = GetActiveWeapon(other);

			if (IsValidEntity(active))
			{
				TF2Items_RefillMag(active);
				TF2Items_RefillAmmo(other, active);
			}
		}
	}
	
	EmitSoundToClient(other, "undead/powerups/powerup_grab.wav");
	EmitSoundToClient(other, g_Powerups[index].sound);

	AcceptEntityInput(entity, "Kill");

	return Plugin_Continue;
}

void DestroyPowerups()
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "tf_halloween_pickup")) != -1)
		AcceptEntityInput(entity, "Kill");
}

/****************************************/
//Secret Box
/****************************************/

void SpawnSecretBoxes()
{
	int entity = -1; int unlock;
	while ((entity = FindEntityByClassname(entity, "info_target")) != -1)
	{
		if (!HasName(entity, "onMysteryBoxSpawn"))
			continue;
		
		unlock = GetWaveUnlockInt(entity);

		float origin[3];
		GetEntityOrigin(entity, origin);
		origin[2] -= 8.0;

		float angles[3];
		GetEntityAngles(entity, angles);
		angles[1] = 270.0;

		int secretbox = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(secretbox, "model", "models/noobis/mystery_box/mystery_box.mdl");
		DispatchKeyValueVector(secretbox, "origin", origin);
		DispatchKeyValueVector(secretbox, "angles", angles);
		DispatchSpawn(secretbox);
		
		g_SecretBox[secretbox].status = true;
		g_SecretBox[secretbox].price = 1000;
		g_SecretBox[secretbox].inuse = false;
		g_SecretBox[secretbox].glow = TF2_CreateGlow("secretbox_color", secretbox, view_as<int>({255, 200, 255, 150}));
		g_SecretBox[secretbox].unlock = unlock;
	}
}

void OnSecretBoxTick(int entity)
{
	int unlock = g_SecretBox[entity].unlock;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != 3)
			continue;
				
		if (IsVisibleTo(i, entity, 120.0, true))
		{
			if (unlock <= g_Match.round)
			{
				g_PlayerData[i].nearbox = entity;

				g_Sync_NearInteractable.SetParams(-1.0, 0.2, 2.0, 255, 255, 255, 255);
				g_Sync_NearInteractable.Send(i, "Press 'MEDIC!' to open this box for %i points!", g_SecretBox[entity].price);
			}
			else
			{
				g_Sync_NearInteractable.SetParams(-1.0, 0.2, 2.0, 255, 255, 255, 255);
				g_Sync_NearInteractable.Send(i, "[Locked until round %i]", unlock);
			}
		}
		else if (g_PlayerData[i].nearbox == entity)
		{
			g_PlayerData[i].nearbox = -1;
			g_Sync_NearInteractable.Clear(i);
		}
	}
}

void DestroySecretBoxes()
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_dynamic")) != -1)
	{
		if (g_SecretBox[entity].status)
			AcceptEntityInput(entity, "Kill");
		
		g_SecretBox[entity].Reset();
	}	
}

void StartSecretBoxEvent(int client, int secretbox)
{
	g_SecretBox[secretbox].inuse = true;
	AcceptEntityInput(g_SecretBox[secretbox].glow, "Disabled");

	AnimateEntity(secretbox, "opening");
	EmitSoundToAll("undead/mystery_box.wav", secretbox);

	float origin[3];
	GetEntityOrigin(secretbox, origin);

	int display = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValueVector(display, "origin", origin);

	int index = GetRandomSecretWeapon(client);

	char sModel[PLATFORM_MAX_PATH];
	TF2Items_GetWeaponKeyString(g_CustomWeapons[index].name, "worldmodel", sModel, sizeof(sModel));

	DispatchKeyValue(display, "model", sModel);

	DispatchSpawn(display);
	SetEntitySelfDestruct(display, 15.0);
	TF2_CreateGlow("display_color", display);
	
	DataPack pack;
	CreateDataTimer(0.1, Timer_SecretBox, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(EntIndexToEntRef(secretbox));
	pack.WriteCell(EntIndexToEntRef(display));
	pack.WriteCell(index);
	pack.WriteCell(0); //phase
	pack.WriteFloat(0.0); //tick
}

public Action Timer_SecretBox(Handle timer, DataPack pack)
{
	pack.Reset();

	int client = GetClientOfUserId(pack.ReadCell());
	int secretbox = EntRefToEntIndex(pack.ReadCell());
	int display = EntRefToEntIndex(pack.ReadCell());
	int index = pack.ReadCell();
	int phase = pack.ReadCell();
	float ticks = pack.ReadFloat();

	ticks += 0.1;

	if (!IsPlayerIndex(client) || !IsValidEntity(secretbox) || !IsValidEntity(display))
	{
		if (IsValidEntity(display))
			AcceptEntityInput(display, "Kill");
		
		if (IsValidEntity(secretbox))
		{
			AnimateEntity(secretbox, "closing");
			g_SecretBox[secretbox].inuse = false;
			AcceptEntityInput(g_SecretBox[secretbox].glow, "Enabled");
		}
		
		return Plugin_Stop;
	}

	if (ticks >= 15.0)
	{
		CloseSecretBox(display, secretbox);
		return Plugin_Stop;
	}
	else if (ticks >= 5.0)
		phase = 1;
	
	float origin[3];
	GetEntityOrigin(display, origin);
	
	if (phase == 0)
	{
		origin[2] += 0.8;
		DispatchKeyValueVector(display, "origin", origin);

		index = GetRandomSecretWeapon(client);

		char sModel[PLATFORM_MAX_PATH];
		TF2Items_GetWeaponKeyString(g_CustomWeapons[index].name, "worldmodel", sModel, sizeof(sModel));

		SetEntityModel(display, sModel);
	}
	else if (phase == 1)
	{
		origin[2] -= 0.2;
		DispatchKeyValueVector(display, "origin", origin);

		float time = GetGameTime();
		if (g_PlayerData[client].delayhint == -1.0 || g_PlayerData[client].delayhint != -1.0 && g_PlayerData[client].delayhint <= time)
		{
			PrintSilentHint(client, "Press 'MEDIC!' near the secret box to pick up the weapon.");
			g_PlayerData[client].delayhint = time + 1.0;
		}

		if (g_PlayerData[client].interact != -1 && g_PlayerData[client].interact > GetTime() && GetEntitiesDistance(client, secretbox) <= 120.0)
		{
			SpeakResponseConcept(client, "TLK_MVM_LOOT_RARE");
			TF2Items_GiveWeapon(client, g_CustomWeapons[index].name);
			CloseSecretBox(display, secretbox);
		}
	}

	pack.Reset();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(EntIndexToEntRef(secretbox));
	pack.WriteCell(EntIndexToEntRef(display));
	pack.WriteCell(index);
	pack.WriteCell(phase);
	pack.WriteFloat(ticks);

	return Plugin_Continue;
}

void CloseSecretBox(int display, int secretbox)
{
	if (IsValidEntity(display))
		AcceptEntityInput(display, "Kill");
		
	if (IsValidEntity(secretbox))
	{
		AnimateEntity(secretbox, "closing");
		g_SecretBox[secretbox].inuse = false;
		AcceptEntityInput(g_SecretBox[secretbox].glow, "Enabled");
	}
}

int GetRandomSecretWeapon(int client)
{
	char sClass[32];
	TF2_GetClientClassName(client, sClass, sizeof(sClass));

	int[] indexes = new int[g_TotalCustomWeapons];
	int total;

	char sClasses[2048];
	for (int i = 0; i <= g_TotalCustomWeapons; i++)
	{
		if (g_CustomWeapons[i].secret_box)
		{
			TF2Items_GetWeaponKeyString(g_CustomWeapons[i].name, "classes", sClasses, sizeof(sClasses));

			if (StrContains(sClasses, sClass, false) != -1)
				indexes[total++] = i;
		}
	}
	
	return (total == 0) ? -1 : indexes[GetRandomInt(0, total - 1)];
}

/****************************************/
//Random Weapons
/****************************************/

void SpawnRandomWeapons()
{
	int entity = -1; int unlock;
	while ((entity = FindEntityByClassname(entity, "info_target")) != -1)
	{
		if (!HasName(entity, "onRandomWeaponSpawn"))
			continue;
		
		unlock = GetWaveUnlockInt(entity);
		
		char sParticle[64];
		GetCustomKeyValue(entity, "udm_particleupgrade", sParticle, sizeof(sParticle));

		char sCost[64];
		GetCustomKeyValue(entity, "udm_cost", sCost, sizeof(sCost));

		char sAmmoCost[64];
		GetCustomKeyValue(entity, "udm_ammocost", sAmmoCost, sizeof(sAmmoCost));

		char sAmmoUpgrade[64];
		GetCustomKeyValue(entity, "udm_ammoupgrade", sAmmoUpgrade, sizeof(sAmmoUpgrade));

		float origin[3];
		GetEntityOrigin(entity, origin);

		float angles[3];
		GetEntityAngles(entity, angles);

		int index = GetRandomInt(0, g_TotalCustomWeapons - 1);

		if (index == -1)
			continue;
		
		char sWorldmodel[PLATFORM_MAX_PATH];
		if (!TF2Items_GetWeaponKeyString(g_CustomWeapons[index].name, "worldmodel", sWorldmodel, sizeof(sWorldmodel)) || !IsModelPrecached(sWorldmodel))
			continue;

		int weapon = CreateEntityByName("prop_dynamic_override");
		DispatchKeyValue(weapon, "model", sWorldmodel);
		DispatchKeyValueVector(weapon, "origin", origin);
		DispatchKeyValueVector(weapon, "angles", angles);
		DispatchSpawn(weapon);

		TF2_CreateGlow("weapon_color", weapon, view_as<int>({255, 200, 200, 150}));

		g_SpawnedWeapons[weapon].index = index;
		g_SpawnedWeapons[weapon].price = StringToInt(sCost);
		g_SpawnedWeapons[weapon].unlock = unlock;
		g_SpawnedWeapons[weapon].particle = StringToFloat(sParticle);
		g_SpawnedWeapons[weapon].ammocost = StringToInt(sAmmoCost);
		g_SpawnedWeapons[weapon].ammoupgrade = StringToInt(sAmmoUpgrade);
	}
}

/****************************************/
//Planks
/****************************************/

void SetPlankStatus(int entity)
{
	SetEntProp(entity, Prop_Data, "m_iHealth", 500);
	SetEntProp(entity, Prop_Data, "m_iDisabled", 0);

	float fOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOrigin);
	TE_Particle("rps_win_sparks", fOrigin);

	AcceptEntityInput(entity, "Enable");
	g_RebuildDelay[entity] = -1.0;
}

void SpawnPlanks()
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "func_brush")) != -1)
	{
		if (HasName(entity, "plank_"))
			SetPlankStatus(entity);
	}
}

void OnPlankTick(int entity)
{
	int health = GetEntProp(entity, Prop_Data, "m_iHealth");
	bool disabled = GetEntProp(entity, Prop_Data, "m_iDisabled") == 1;

	char sCooldown[32]; float diff;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;
		
		switch (GetClientTeam(i))
		{
			case 2:
			{
				if (!IsVisibleTo(entity, i, 120.0, true))
					continue;
				
				if (health <= 0)
				{
					g_PlayerData[i].zombie_sounds = -1.0;
					AcceptEntityInput(entity, "Disable");
					EmitGameSoundToAll("Breakable.Crate", entity);
					g_RebuildDelay[entity] = GetGameTime() + 30.0;
					continue;
				}

				float time = GetGameTime();
				if (g_PlayerData[i].zombie_sounds == -1.0 || g_PlayerData[i].zombie_sounds != -1.0 && g_PlayerData[i].zombie_sounds <= time)
				{
					EmitGameSoundToAll("Breakable.Crate", entity);
					g_PlayerData[i].zombie_sounds = time + 1.0;
				}
				
				SetEntProp(entity, Prop_Data, "m_iHealth", health - 1);
			}
			case 3:
			{
				if (disabled && IsVisibleTo(i, entity, 180.0, true))
				{
					g_PlayerData[i].nearplank = entity;

					diff = (g_RebuildDelay[entity] - GetGameTime());
					FormatEx(sCooldown, sizeof(sCooldown), " (Cooldown: %.2f)", (diff > 0.0) ? diff : 0.0);

					g_Sync_NearInteractable.SetParams(-1.0, 0.2, 2.0, 255, 255, 255, 255);
					g_Sync_NearInteractable.Send(i, "Press 'MEDIC!' to rebuild this plank for points.%s", sCooldown);
				}
				else if (g_PlayerData[i].nearplank == entity)
				{
					g_PlayerData[i].nearplank = - 1;
					g_Sync_NearInteractable.Clear(i);
				}
			}
		}
	}

	if (disabled)
		return;
	
	float fOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOrigin);
	
	int zombie = -1;
	while ((zombie = FindEntityByClassname(zombie, "base_boss")) != -1)
	{
		if (GetEntitiesDistance(entity, zombie) > 120.0)
			continue;

		CBaseNPC npc = TheNPCs.FindNPCByEntIndex(zombie);

		if (health <= 0)
		{
			g_BreakingSounds[zombie] = -1;
			npc.flRunSpeed = 150.0 * (1.0 + (g_Match.round * 0.05));
			AcceptEntityInput(entity, "Disable");

			EmitGameSoundToAll("Breakable.Crate", entity);
			TE_Particle("mvm_loot_dustup", fOrigin);

			g_RebuildDelay[entity] = GetGameTime() + 30.0;
			continue;
		}

		int time = GetTime();
		if (g_BreakingSounds[zombie] == -1 || g_BreakingSounds[zombie] != -1 && g_BreakingSounds[zombie] <= time)
		{
			CBaseAnimatingOverlay animationEntity = CBaseAnimatingOverlay(zombie);
			int iSequence = animationEntity.LookupSequence("Melee_Swing");
			animationEntity.AddGestureSequence(iSequence);

			EmitGameSoundToAll("Breakable.Crate", entity);
			TE_Particle("mvm_loot_smoke", fOrigin);

			g_BreakingSounds[zombie] = time + 1;
		}

		SetEntProp(entity, Prop_Data, "m_iHealth", health - 1);
		npc.flRunSpeed = 0.0;
	}
}

/****************************************/
//Buildings
/****************************************/

void SetupSentries()
{
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "obj_*")) != -1)
	{
		g_RechargeBuilding[entity] = -1;
		g_DisableBuilding[entity] = -1;
		SetEntProp(entity, Prop_Send, "m_bDisabled", 1);
	}
}

void OnSentryTick(int entity)
{
	char sCost[64];
	GetCustomKeyValue(entity, "udm_cost", sCost, sizeof(sCost));
	
	char sRecharge[64];
	GetCustomKeyValue(entity, "udm_recharge", sRecharge, sizeof(sRecharge));

	int unlock = GetWaveUnlockInt(entity);

	if (g_DisableBuilding[entity] != -1 && g_DisableBuilding[entity] <= GetTime())
	{
		SetEntProp(entity, Prop_Send, "m_bDisabled", 1);
		g_RechargeBuilding[entity] = GetTime() + StringToInt(sRecharge);
		g_DisableBuilding[entity] = -1;
	}

	float fOrigin[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOrigin);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != 3)
			continue;
		
		if (IsVisibleTo(i, entity, 120.0, true))
		{
			if (unlock <= g_Match.round)
			{
				g_PlayerData[i].nearsentry = entity;

				g_Sync_NearInteractable.SetParams(-1.0, 0.2, 2.0, 255, 255, 255, 255);
				g_Sync_NearInteractable.Send(i, "Press 'MEDIC!' to start this sentry for %i points!", StringToInt(sCost));
			}
			else
			{
				g_Sync_NearInteractable.SetParams(-1.0, 0.2, 2.0, 255, 255, 255, 255);
				g_Sync_NearInteractable.Send(i, "[Locked until round %i]", unlock);
			}
		}
		else if (g_PlayerData[i].nearsentry == entity)
		{
			g_PlayerData[i].nearsentry = -1;
			g_Sync_NearInteractable.Clear(i);
		}
	}
}

//Misc
void KillAllZombies()
{
	int entity = -1; CBaseNPC zombie;
	while ((entity = FindEntityByClassname(entity, "base_boss")) != -1)
		if ((zombie = TheNPCs.FindNPCByEntIndex(entity)) != INVALID_NPC)
		{
			float vecOrigin[3];
			GetEntityOrigin(entity, vecOrigin);

			float vecAngles[3];
			GetEntityAngles(entity, vecAngles);
				
			TF2_CreateRagdoll(vecOrigin, vecAngles, g_ZombiesData[zombie].g_Class, zombie.iTeamNum, zombie.nSkin, 2.0, RAG_BECOMEASH);
			
			zombie.SetCollisionBounds(view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}));
			AcceptEntityInput(entity, "Kill");
		}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!IsPlayerIndex(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	float fCoordinates[3];
	GetClientAbsOrigin(client, fCoordinates);

	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "entity_revive_marker")) != -1)
	{
		float fOrigin[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fOrigin);

		if (GetVectorDistance(fCoordinates, fOrigin) <= 50.0)
		{
			int iOwner = GetEntPropEnt(entity, Prop_Send, "m_hOwner");

			if (GetClientTeam(client) != GetClientTeam(iOwner))
				continue;
			
			if ((buttons & IN_ATTACK2) != IN_ATTACK2)
			{
				PrintSilentHint(client, "Hold 'attack2' to revive %N.", iOwner);
				continue;
			}
			
			int iHealth = GetEntProp(entity, Prop_Send, "m_iHealth");
			int iMaxHealth = 175; //GetEntProp(entity, Prop_Send, "m_iMaxHealth")

			PrintHintText(client, "Reviving '%N'... [%i/%i]", iOwner, iHealth, iMaxHealth);

			SetEntProp(entity, Prop_Send, "m_iHealth", iHealth + 1);
			iHealth += g_PlayerData[client].quickrevive ? 2 : 1;

			if (iHealth >= iMaxHealth && IsClientInGame(iOwner))
			{
				if (client == iOwner)
					continue;

				float vecMarkerPos[3];
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vecMarkerPos);

				EmitGameSoundToAll("MVM.PlayerRevived", entity);

				float flMins[3], flMaxs[3];
				GetEntPropVector(iOwner, Prop_Send, "m_vecMaxs", flMaxs);
				GetEntPropVector(iOwner, Prop_Send, "m_vecMins", flMins);

				Handle TraceRay = TR_TraceHullFilterEx(vecMarkerPos, vecMarkerPos, flMins, flMaxs, MASK_PLAYERSOLID, TraceFilterNotSelf, entity);
					
				if (TR_DidHit(TraceRay))
				{
					float vecReviverPos[3];
					GetClientAbsOrigin(client, vecReviverPos);

					TF2_RespawnPlayer(iOwner);
					SpeakResponseConcept(iOwner, "TLK_RESURRECTED");

					TeleportEntity(iOwner, vecReviverPos, NULL_VECTOR, NULL_VECTOR);
					StripPlayer(iOwner);
				}
				else
				{
					TF2_RespawnPlayer(iOwner);
					SpeakResponseConcept(iOwner, "TLK_RESURRECTED");

					TeleportEntity(iOwner, vecMarkerPos, NULL_VECTOR, NULL_VECTOR);
					StripPlayer(iOwner);
				}

				TFClassType class = view_as<TFClassType>(GetEntProp(entity, Prop_Send, "m_nBody") + 1);
				TF2_SetPlayerClass(iOwner, class, true, true);
				TF2_RegeneratePlayer(iOwner);

				char sClassname[64];
				TF2Econ_GetItemClassName(g_PlayerData[client].primary, sClassname, sizeof(sClassname));
				TF2_GiveItem(iOwner, sClassname, g_PlayerData[client].primary);
				
				TF2Econ_GetItemClassName(g_PlayerData[client].secondary, sClassname, sizeof(sClassname));
				TF2_GiveItem(iOwner, sClassname, g_PlayerData[client].secondary);
				
				TF2Econ_GetItemClassName(g_PlayerData[client].melee, sClassname, sizeof(sClassname));
				TF2_GiveItem(iOwner, sClassname, g_PlayerData[client].melee);

				ApplyMachineEffects(iOwner);

				g_PlayerData[iOwner].revivemarker = INVALID_ENT_REFERENCE;
				delete TraceRay;
			}
		}
	}

	return Plugin_Continue;
}

public bool TraceFilterNotSelf(int entityhit, int mask, any entity)
{
	return (entity == 0 && entityhit != entity);
}

public Action Command_AddPoints(int client, int args)
{
	int target = GetCmdArgTarget(client, 1, true, false);

	if (target == -1)
	{
		CPrintToChat(client, "Target not found, please try again.");
		return Plugin_Handled;
	}

	int value = GetCmdArgInt(2);

	g_PlayerData[target].AddPoints(value);

	if (client == target)
		CPrintToChat(client, "You have given yourself %i points.", value);
	else
	{
		CPrintToChat(target, "%N has given you %i points.", client, value);
		CPrintToChat(client, "You have given %N %i points.", target, value);
	}

	return Plugin_Handled;
}

void StripPlayer(int client, bool invisible_melee = false)
{
	int melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);

	if (IsValidEntity(melee) && GetWeaponIndex(melee) == 142)
	{
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
		melee = TF2_GiveItem(client, "tf_weapon_wrench", 7);
	}

	if (g_PlayerData[client].zombie)
	{
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
		TFClassType class = TF2_GetPlayerClass(client);

		char sEntity[32];
		TF2_GetDefaultWeaponClass(class, TFWeaponSlot_Melee, sEntity, sizeof(sEntity));

		int index = TF2_GetDefaultWeaponID(class, TFWeaponSlot_Melee);
		melee = TF2_GiveItem(client, sEntity, index);
	}

	if (invisible_melee && IsValidEntity(melee))
	{
		SetEntityRenderMode(melee, RENDER_TRANSCOLOR); 
		SetEntityRenderColor(melee, _, _, _, 0);  
	}

	EquipWeaponSlot(client, TFWeaponSlot_Melee);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Grenade);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
	SetEntityHealth(client, g_PlayerData[client].zombie ? (15 + (g_Match.round * 2)) : (g_PlayerData[client].juggernog ? 300 : 150));
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool& result)
{
	result = false;
	return Plugin_Changed;
}

public Action Command_PlayZombie(int client, int args)
{
	if (!IsDrixevel(client) && g_Match.roundphase != PHASE_STARTING)
	{
		CPrintToChat(client, "Match must be starting to become a Zombie.");
		return Plugin_Handled;
	}

	if (!IsDrixevel(client) && GetClientTeam(client) != 2 && GetTeamAbsCount(3) < 2)
	{
		CPrintToChat(client, "Match must consist of 1 Survivor already in order to become a Zombie. (besides yourself)");
		return Plugin_Handled;
	}

	g_PlayerData[client].zombie = !g_PlayerData[client].zombie;
	CPrintToChat(client, "Zombie Mode: %s", g_PlayerData[client].zombie ? "ON" : "OFF");

	if (g_PlayerData[client].zombie)
		CPrintToChat(client, "To toggle it off, just type !playzombie once again.");

	TF2_RespawnPlayer(client);

	return Plugin_Handled;
}

void ClearGlow(int client)
{
	if (IsValidEntity(g_PlayerData[client].glow))
		AcceptEntityInput(g_PlayerData[client].glow, "Kill");
	
	g_PlayerData[client].glow = INVALID_ENT_REFERENCE;
}

public Action OnSoundPlay(int clients[MAXPLAYERS], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if (IsClassname(entity, "base_boss"))
	{

	}
}

public Action Command_SyncLobby(int client, int args)
{
	TelePlayersToMap();
	CPrintToChatAll("%N has teleported players from the lobby to the game.", client);
	return Plugin_Handled;
}

public void TF2_OnRegeneratePlayerPost(int client)
{
	StripPlayer(client);
}

bool IsVisibleTo(int client, int entity, float maxdistance = 0.0, bool FromEyePosition = false, float tolerance = 75.0)
{
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client) || !IsValidEntity(entity))
		return false;
	
	if (maxdistance > 0.0 && GetEntitiesDistance(client, entity) > maxdistance)
		return false;
	
	float vOrigin[3];
	FromEyePosition ? GetClientEyePosition(client, vOrigin) : GetClientAbsOrigin(client, vOrigin);
	
	float vEnt[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vEnt);
	
	float vLookAt[3];
	MakeVectorFromPoints(vOrigin, vEnt, vLookAt);
	
	float vAngles[3];
	GetVectorAngles(vLookAt, vAngles);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceFilter, entity);
	
	bool isVisible = true;
	if (TR_DidHit(trace))
	{
		float vStart[3];
		TR_GetEndPosition(vStart, trace);
		
		if ((GetVectorDistance(vOrigin, vStart, false) + tolerance) >= GetVectorDistance(vOrigin, vEnt))
			isVisible = true;
	}
	else
		isVisible = true;
	
	delete trace;
	return isVisible;
}

public bool TraceFilter(int entity, int contentsMask, any data)
{
	if (entity <= MaxClients || !IsValidEntity(entity) || entity == data)
		return false;
	
	return true;
}