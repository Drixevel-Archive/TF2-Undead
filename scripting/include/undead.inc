#if defined _Undead_Inc_ 
	#endinput
#endif 
#define _Undead_Inc_  

native void Undead_Damage(int entity, int attacker = -1, int weapon = -1, float damage = 100.0, int damagetype = DMG_GENERIC, int damagecustom = -1, bool powerups = true, bool bomb_heads = true);

#if !defined REQUIRE_PLUGIN
public void __pl_undead_SetNTVOptional()
{
    MarkNativeAsOptional("Undead_Damage");
}
#endif  

public SharedPlugin __pl_undead = 
{
	name = "undead",
	file = "tf2-undead.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};