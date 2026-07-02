#pragma semicolon 1
#pragma newdecls required

enum
{
	VISION_MODE_NONE = 0,
	VISION_MODE_PYRO,
	VISION_MODE_HALLOWEEN,
	VISION_MODE_ROME,

	MAX_VISION_MODES
};

static const int HealthMax = 3000;	// Max standard health
static const int HealthExtra = 3000;	// Max regenerable health

static const float SpeedExtra = 70.0;	// Extra speed while low health
static const float GlowRange = 800.0;	// Max outline range

static int Health[MAXPLAYERS + 1];

static int g_iOffsetDisguiseCompleteTime;
static float g_flDisguiseCompleteTime;

public bool SCP939_Create(int client)
{
	Classes_VipSpawn(client);

	Health[client] = HealthMax;
	
	int account = GetSteamAccountID(client, false);
	int weapon = SpawnWeapon(client, "tf_weapon_knife", 461, 70, 13, "2 ; 1.625 ; 15 ; 0 ; 252 ; 0 ; 412 ; 0.8", false);
	if(weapon > MaxClients)
	{
		ApplyStrangeRank(weapon, 10);
		SetEntProp(weapon, Prop_Send, "m_iAccountID", account);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}

	weapon = SpawnWeapon(client, "tf_weapon_pda_spy", 27, 70, 13, "", false);
	if(weapon > MaxClients)
	{
		TF2Attrib_SetByDefIndex(weapon, 214, view_as<float>(GetRandomInt(250, 374))); // Sharp
		TF2Attrib_SetByDefIndex(weapon, 292, view_as<float>(64));
		SetEntProp(weapon, Prop_Send, "m_iAccountID", account);
	}

	SDKHook(client, SDKHook_PreThink, SCP939_ThinkPre);
	SDKHook(client, SDKHook_PreThinkPost, SCP939_ThinkPost);

	#if defined _tf2_pets_included
 	TF2Pets_SetHidePets(client, true);
	#endif

	return false;
}

public void SCP939_OnButton(int client, int button)
{
	Client[client].WeaponClass = TFClass_Spy;

	if(TF2_IsPlayerInCondition(client, TFCond_Disguised))
	{
		Client[client].CurrentClass = view_as<TFClassType>(GetEntProp(client, Prop_Send, "m_nDisguiseClass"));
		if(Client[client].CurrentClass != TFClass_Unknown)
			return;
	}

	Client[client].CurrentClass = TFClass_Spy;
}

public void SCP939_OnMaxHealth(int client, int &health)
{
	health = Health[client] + HealthExtra;

	int current = GetClientHealth(client);
	if(current > health)
	{
		SetEntityHealth(client, health);
	}
	else if(current < Health[client]-HealthExtra)
	{
		Health[client] = current+HealthExtra;
	}
}

public void SCP939_OnKill(int client, int victim)
{
	ClassEnum class;
	
	if(Classes_GetByIndex(Client[victim].Class, class))
	{
		if(class.Vip)
		{
			Gamemode_AddValue("vkill", 1);
		}
		else if(class.Group > 1)
		{
			Gamemode_AddValue("mkill", 1);
		}
	}
}

public void SCP939_OnSpeed(int client, float &speed)
{
	speed += (1.0-(Pow(float(Health[client])/float(HealthMax), 2.0)))*SpeedExtra;
}

public Action SCP939_OnDealDamage(int client, int victim, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(Client[victim].IdleAt < GetGameTime())
	{
		damage = 60.0;
		damagetype &= ~DMG_CRIT;
		Client[victim].HudIn = GetGameTime()+6.0;
		return Plugin_Changed;
	}

	if(damagecustom!=TF_CUSTOM_BACKSTAB || damage<108)
	{
		Client[victim].HudIn = GetGameTime()+6.0;
		return Plugin_Continue;
	}

	damage = 65.0;
	damagetype &= ~DMG_CRIT;
	Client[victim].HudIn = GetGameTime()+13.0;
	return Plugin_Changed;
}

public Action SCP939_OnTakeDamage(int client, int attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	SDKCall_SetSpeed(client);

	if(!(damagetype & DMG_FALL))
		return Plugin_Continue;

	damage *= 0.015;
	return Plugin_Changed;
}

public bool SCP939_OnSeePlayer(int client, int victim)
{
	return (IsFriendly(Client[client].Class, Client[victim].Class) || Client[victim].IdleAt>GetGameTime());
}

public bool SCP939_OnGlowPlayer(int client, int victim)
{
	float time = Client[victim].IdleAt-GetGameTime();
	if(time > 0)
	{
		static float clientPos[3], targetPos[3];
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", clientPos);
		GetEntPropVector(victim, Prop_Send, "m_vecOrigin", targetPos);
		if(GetVectorDistance(clientPos, targetPos) < (GlowRange*time/2.5))
			return true;
	}
	return false;
}

public void SCP939_ThinkPre(int client)
{
	ClassEnum class;
	if(!Classes_GetByIndex(Client[client].Class, class))
	{
		SDKUnhook(client, SDKHook_PreThink, SCP939_ThinkPre);
		return;
	}

	if(!StrEqual(class.Name, "scp939"))
	{
		SDKUnhook(client, SDKHook_PreThink, SCP939_ThinkPre);
		return;
	}

	if (!g_iOffsetDisguiseCompleteTime)
		g_iOffsetDisguiseCompleteTime = FindSendPropInfo("CTFPlayer", "m_unTauntSourceItemID_High") + 4;
	
	g_flDisguiseCompleteTime = GetEntDataFloat(client, g_iOffsetDisguiseCompleteTime);
}

public void SCP939_ThinkPost(int client)
{
	ClassEnum class;
	if(!Classes_GetByIndex(Client[client].Class, class))
	{
		SDKUnhook(client, SDKHook_PreThinkPost, SCP939_ThinkPost);
		return;
	}

	if(!StrEqual(class.Name, "scp939"))
	{
		SDKUnhook(client, SDKHook_PreThinkPost, SCP939_ThinkPost);
		return;
	}

	if (g_flDisguiseCompleteTime && !GetEntDataFloat(client, g_iOffsetDisguiseCompleteTime))
		SCP939_OnDisguise(client);
}

void SCP939_OnDisguise(int client)
{
	if (view_as<TFClassType>(GetEntProp(client, Prop_Send, "m_nDisguiseClass")) == TFClass_Unknown) return;
	
	int offset = FindSendPropInfo("CTFPlayer", "m_iDisguiseHealth") - 4;	// m_hDisguiseTarget
	int target = GetEntDataEnt2(client, offset);
	if (0 < target <= MaxClients)
	{
		ClassEnum class;
		if(Classes_GetByIndex(Client[target].Class, class))
		{
			SetVariantString(class.Model);
			AcceptEntityInput(client, "SetCustomModel");
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", true);
			SetEntProp(client, Prop_Send, "m_nModelIndexOverrides", class.ModelIndex, _, 0);
			SetEntProp(client, Prop_Send, "m_nModelIndexOverrides", class.ModelAlt, _, 3);

			int weapon = GetEntPropEnt(client, Prop_Send, "m_hDisguiseWeapon");
			if (weapon != INVALID_ENT_REFERENCE && GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") != 195)
			{
				RemoveEntity(weapon);
				weapon = INVALID_ENT_REFERENCE;
			}
	
			if (weapon == INVALID_ENT_REFERENCE)
			{
				Handle item = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
				if(item)
				{
					TF2Items_SetClassname(item, "tf_weapon_fists");
					TF2Items_SetItemIndex(item, 195);
					TF2Items_SetLevel(item, 101);
					TF2Items_SetQuality(item, 6);
					weapon = TF2Items_GiveNamedItem(client, item);
					delete item;

					SetEntPropEnt(weapon, Prop_Send, "m_hOwner", client);
					SetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity", client);
		
					SetEntityMoveType(weapon, MOVETYPE_NONE);
					SetEntProp(weapon, Prop_Send, "m_fEffects", GetEntProp(weapon, Prop_Send, "m_fEffects")|EF_BONEMERGE);
					SetVariantString("!activator");
					AcceptEntityInput(weapon, "SetParent", client);
		
					SetEntProp(weapon, Prop_Send, "m_iState", 2);	// WEAPON_IS_ACTIVE
					SetEntProp(weapon, Prop_Send, "m_bDisguiseWeapon", true);
		
					SetEntPropEnt(client, Prop_Send, "m_hDisguiseWeapon", weapon);
				}
			}
		}
	}
}

public void SCP939_OnCondRemoved(int client, TFCond condition)
{
	if(condition == TFCond_Disguised)
	{
		ClassEnum class;
		if(Classes_GetByIndex(Client[client].Class, class))
		{
			SetVariantString(class.Model);
			AcceptEntityInput(client, "SetCustomModel");
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", true);
			SetEntProp(client, Prop_Send, "m_nModelIndexOverrides", class.ModelIndex, _, 0);
			SetEntProp(client, Prop_Send, "m_nModelIndexOverrides", class.ModelAlt, _, 3);
		}
	}
}