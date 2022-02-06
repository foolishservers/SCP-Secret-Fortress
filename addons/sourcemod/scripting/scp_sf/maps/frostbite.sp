#define POWERUP "item_powerup_rune"
static int IndexHeavyBlu;
static int IndexHeavyRed;
static int IndexSeeman;
//static int IndexSeeldier;
static int IndexSeeldier2;
//static const int 682ks = 0;
static const char Pootis[] = "freak_fortress_2/pootis_engage/heavy_duo_intro2.mp3";
static const char Seeduo[] = "682\roar.mp3";
static const char Seeman[] = "freak_fortress_2/seeman/seeman_see.wav";
static const char Seeldier[] = "freak_fortress_2/seeman/seeldier_see.wav";
static const char NukeSong[] = "freak_fortress_2/seesolo/seeman_nuke.mp3";


public void HeavyBlu_Enable(int index)
{
	IndexHeavyBlu = index;
}

public bool HeavyBlu_Create(int client)
{
	Classes_VipSpawn(client);

	Client[client].Extra2 = 0;
	Client[client].Extra3 = 0.0;

	int weapon = SpawnWeapon(client, "tf_weapon_minigun", 298, 69, 11, "1 ; 0 ; 275 ; 1 ; 375 ; 1", 1);
	if(weapon > MaxClients)
	{
		ApplyStrangeRank(weapon, 18);
		SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", FAR_FUTURE);
		SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
		CreateTimer(15.0, Timer_UpdateClientHud, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}

	GivePassiveWeapon(client);
	TF2_AddCondition(client, TFCond_RestrictToMelee);

	for(int target=1; target<=MaxClients; target++)
	{
		if(Client[target].Class == IndexHeavyRed)
		{
			EmitSoundToClient(client, Pootis);
			break;
		}
	}
	return false;
}

public void HeavyBlu_OnButton(int client, int button)
{
	switch(Client[client].Extra2)
	{
		case 2:
		{
			if(Client[client].Extra3 <= 1.25)
			{
				Client[client].Extra2 = 0;

				TF2_StunPlayer(client, 0.5, 0.0, TF_STUNFLAG_SLOWDOWN);
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
				GivePassiveWeapon(client);
			}
		}
		case 3:
		{
			return;
		}
		default:
		{
			if(Client[client].Extra3 >= 100.0)
			{
				Client[client].Extra2 = 2;

				TF2_StunPlayer(client, 0.5, 1.0, TF_STUNFLAG_SLOWDOWN);
				TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
				GiveAngerWeapon(client);
			}
		}
	}

	float engineTime = GetGameTime();
	static float delay;
	if(delay < engineTime)
	{
		delay = engineTime+0.25;

		Client[client].Extra3 -= 2.5;
		if(Client[client].Extra3 > 95.0)
		{
			Client[client].Extra3 = 95.0;
		}
		else if(Client[client].Extra3 < 0.0)
		{
			Client[client].Extra3 = 0.0;
		}

		static float pos1[3], ang1[3];
		GetClientEyePosition(client, pos1);
		GetClientEyeAngles(client, ang1);
		ang1[0] = fixAngle(ang1[0]);
		ang1[1] = fixAngle(ang1[1]);

		bool found;
		for(int target=1; target<=MaxClients; target++)
		{
			if(target==client || !IsValidClient(target) || IsSpec(target) || IsFriendly(Client[client].Class, Client[target].Class))
				continue;

			static float pos2[3], ang2[3], ang3[3];
			GetClientEyePosition(target, pos2);
			GetClientEyeAngles(target, ang2);
			GetVectorAnglesTwoPoints(pos2, pos1, ang3);

			// fix all angles
			ang2[0] = fixAngle(ang2[0]);
			ang2[1] = fixAngle(ang2[1]);
			ang3[0] = fixAngle(ang3[0]);
			ang3[1] = fixAngle(ang3[1]);

			// verify angle validity
			if(!(fabs(ang2[0] - ang3[0]) <= MAXANGLEPITCH ||
			(fabs(ang2[0] - ang3[0]) >= (360.0-MAXANGLEPITCH))))
				continue;

			if(!(fabs(ang2[1] - ang3[1]) <= MAXANGLEYAW ||
			(fabs(ang2[1] - ang3[1]) >= (360.0-MAXANGLEYAW))))
				continue;

			// ensure no wall is obstructing
			TR_TraceRayFilter(pos2, pos1, MASK_VISIBLE, RayType_EndPoint, Trace_WallsOnly);
			TR_GetEndPosition(ang3);
			if(ang3[0]!=pos1[0] || ang3[1]!=pos1[1] || ang3[2]!=pos1[2])
				continue;

			// success
			found = true;
			break;
		}

		if(found)
		{
			Client[client].Extra3 += 5.0;
			if(!Client[client].Extra2)
			{
				Client[client].Extra2 = 1;
				SDKCall_SetSpeed(client);
			}
		}
		else if(Client[client].Extra2 == 1)
		{
			Client[client].Extra2 = 0;
			SDKCall_SetSpeed(client);
		}

		SetEntPropFloat(client, Prop_Send, "m_flRageMeter", Client[client].Extra3);
	}
}

public void HeavyBlu_OnDeath(int client, Event event)
{
	Classes_DeathScp(client, event);

	for(int target=1; target<=MaxClients; target++)
	{
		if(Client[target].Class == IndexHeavyRed)
			Client[target].Extra3 = 100.0;
	}
}

public int HeavyBlu_OnKeycard(int client, AccessEnum access)
{
	if(access == Access_Checkpoint)
		return 1;

	if(Client[client].Extra2 || access==Access_Exit)
		return 0;

	if(access==Access_Main || access==Access_Armory)
		return 3;

	return 1;
}

public void HeavyBlu_OnSpeed(int client, float &speed)
{
	switch(Client[client].Extra2)
	{
		case 0:
			speed *= 0.85;

		case 1:
			speed = 1.0;
	}
}

public Action HeavyBlu_OnTakeDamage(int client, int attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(!TF2_IsPlayerInCondition(client, TFCond_Dazed))
		Client[client].Extra3 += damage/2.0;

	if(Client[client].Extra2 == 1)
	{
		damagetype |= DMG_PREVENT_PHYSICS_FORCE;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

static void GivePassiveWeapon(int client)
{
	int weapon = SpawnWeapon(client, "tf_weapon_shovel", 474, 69, 11, "138 ; 0.5", 2);
	if(weapon > MaxClients)
	{
		ApplyStrangeRank(weapon, 18);
		SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}
}

static void GiveAngerWeapon(int client)
{
	int weapon = SpawnWeapon(client, "tf_weapon_fists", 195, 69, 11, "2 ; 1.69 ; 252 ; 0.5", 2);
	if(weapon > MaxClients)
	{
		ApplyStrangeRank(weapon, 18);
		SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}
}

public void HeavyRed_Enable(int index)
{
	IndexHeavyRed = index;
}

public bool HeavyRed_Create(int client)
{
	Classes_VipSpawn(client);

	Client[client].Extra3 = 0.0;

	int weapon = SpawnWeapon(client, "tf_weapon_minigun", 850, 69, 11, "1 ; 0 ; 275 ; 1 ; 375 ; 1", 1);
	if(weapon > MaxClients)
	{
		ApplyStrangeRank(weapon, 18);
		SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", FAR_FUTURE);
		SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
		CreateTimer(15.0, Timer_UpdateClientHud, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}

	weapon = SpawnWeapon(client, "tf_weapon_fists", 195, 69, 11, "252 ; 0.5 ; 1006 ; 1", 2);
	if(weapon > MaxClients)
	{
		ApplyStrangeRank(weapon, 18);
		SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}

	TF2_AddCondition(client, TFCond_RestrictToMelee);

	for(int target=1; target<=MaxClients; target++)
	{
		if(Client[target].Class == IndexHeavyBlu)
		{
			EmitSoundToClient(client, Pootis);
			break;
		}
	}
	return false;
}

public void HeavyRed_OnButton(int client, int button)
{
	float engineTime = GetGameTime();
	static float delay;
	if(delay < engineTime)
	{
		delay = engineTime+0.5;

		Client[client].Extra3 -= 0.5;
		if(Client[client].Extra3 > 100.0)
		{
			Client[client].Extra3 = 100.0;
			SDKCall_SetSpeed(client);
		}
		else if(Client[client].Extra3 < 0.0)
		{
			Client[client].Extra3 = 0.0;
			SDKCall_SetSpeed(client);
		}

		SetEntPropFloat(client, Prop_Send, "m_flRageMeter", Client[client].Extra3);
	}
}

public Action HeavyRed_OnDealDamage(int client, int attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	damage *= 1.0 + (Client[client].Extra3*0.03);
	return Plugin_Continue;
}

public void HeavyRed_OnDeath(int client, Event event)
{
	Classes_DeathScp(client, event);

	for(int target=1; target<=MaxClients; target++)
	{
		if(Client[target].Class==IndexHeavyBlu && IsClientInGame(target))
		{
			SetEntPropFloat(target, Prop_Send, "m_flRageMeter", 100.0);
			Client[target].Extra2 = 3;
		}
	}
}

public int HeavyRed_OnKeycard(int client, AccessEnum access)
{
	if(access == Access_Checkpoint)
		return Client[client].Extra3<65.0;

	if(Client[client].Extra3>35.0 || access==Access_Exit)
		return 0;

	if(access==Access_Main || access==Access_Armory)
		return 3;

	return 1;
}

public void HeavyRed_OnSpeed(int client, float &speed)
{
	speed *= 0.65 + (Client[client].Extra3*0.0035);
}

public Action HeavyRed_OnTakeDamage(int client, int attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	Client[client].Extra3 += damage*0.05;
	SDKCall_SetSpeed(client);

	if(Client[client].Extra3 > 50.0)
	{
		damagetype |= DMG_PREVENT_PHYSICS_FORCE;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void Seeman_Enable(int index)
{
	IndexSeeman = index;
}

public bool Seeman_Create(int client)//scp682
{
	Classes_VipSpawn(client);
	Client[client].Extra2 = 0;
	Client[client].Extra3 = 0.0;
	int weapon = SpawnWeapon(client, "tf_weapon_fireaxe", 326, 101, 5, "190 ; 10 ; 2 ; 2 ; 5 ; 0.8 ; 28 ; 0.5 ; 68 ; 2 ; 252 ; 0.5 ; 476 ; 0.5 ; 2025 ; 1", 0); 
	if(weapon > MaxClients)
	{
		ApplyStrangeRank(weapon, 20);
		SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
		CreateTimer(1.5, Seeman_CaberTimer, EntIndexToEntRef(weapon), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	}
	return false;
}

public void Seeman_OnKill(int client, int victim)
{
	Client[client].Extra2++;
	switch(Client[client].Extra2)
	{
		case 2:
		{
			CPrintToChatAll("%s%t", PREFIX, "seeman_5");
			//TF2_AddCondition(client, TFCond_SmallBulletResist, 999.0);
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
			int weapon = SpawnWeapon(client, "tf_weapon_fireaxe", 326, 101, 5, "736 ; 10 ; 190 ; 10 ; 2 ; 2.5 ; 5 ; 0.8 ; 28 ; 0.5 ; 68 ; 2 ; 252 ; 0.5 ; 476 ; 0.5 ; 2025 ; 1", 0); 
			if(weapon > MaxClients)
			{
				ApplyStrangeRank(weapon, 20);
				SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
				CreateTimer(1.5, Seeman_CaberTimer, EntIndexToEntRef(weapon), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
			}
			
			ChangeGlobalSong(FAR_FUTURE, NukeSong);
		}
		case 5:
		{
			CPrintToChatAll("%s%t", PREFIX, "seeman_5");
			TF2_AddCondition(client, TFCond_Buffed, 999.0);
		}
		case 11:
		{
			CPrintToChatAll("%s%t", PREFIX, "seeman_5");
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
			int weapon = SpawnWeapon(client, "tf_weapon_fireaxe", 326, 101, 5, "57 ; 1.2 ; 263 ; 1.25 ; 737 ; 5 ; 190 ; 10 ; 2 ; 2.75 ; 5 ; 0.6 ; 28 ; 0.5 ; 68 ; 2 ; 252 ; 0.1 ; 476 ; 0.5 ; 2025 ; 1", 0); 
			if(weapon > MaxClients)
			{
				ApplyStrangeRank(weapon, 20);
				SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
				CreateTimer(1.5, Seeman_CaberTimer, EntIndexToEntRef(weapon), TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
			}
		}
		case 20:
		{	
			CPrintToChatAll("%s%t", PREFIX, "seeman_3");
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
			int weapon = SpawnWeapon(client, "tf_weapon_knife", 8, 90, 13, "7 ; 1.32 ; 149 ; 5 ; 54 ; 1.3 ; 263 ; 2 ; 264 ; 1.5 ; 2 ; 3 ; 5 ; 0.3 ; 252 ; 0 ; 326 ; 1.67 ; 412 ; 0.8", 2, true);
			if(weapon > MaxClients)
			{
				ApplyStrangeRank(weapon, 18);
				SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);

			}
			ChangeGlobalSong(FAR_FUTURE, NukeSong);
	
			//return false;
		}
	}
	//return true;
}

public bool SCP682_OnPickup(int client, int entity)
{
	char buffer[64];
	GetEntityClassname(entity, buffer, sizeof(buffer));
	if(StrEqual(buffer, "tf_dropped_weapon"))
	{
		ApplyHealEvent(client, 10);
		SetEntityHealth(client, GetClientHealth(client)+10);
		Client[client].Extra3++;
		RemoveEntity(entity);
		switch(Client[client].Extra3)
		{
			case 3:
			{
				CPrintToChatAll("%s%t", PREFIX, "seeman_2");
				TF2_AddCondition(client, TFCond_SmallBulletResist, 999.0);
			}
			case 10:
			{
				CPrintToChatAll("%s%t", PREFIX, "seeman_2");
				TF2_AddCondition(client, TFCond_RegenBuffed, 999.0);
				TF2_RemoveCondition(client, TFCond_SmallBulletResist);
				TF2_AddCondition(client, TFCond_UberBulletResist, 999.0);
				ChangeGlobalSong(FAR_FUTURE, NukeSong);
			}
			case 16:
			{
				CPrintToChatAll("%s%t", PREFIX, "seeman_2");
				TF2_AddCondition(client, TFCond_SmallFireResist, 999.0);
			}
			case 26:
			{
				CPrintToChatAll("%s%t", PREFIX, "seeman_2");
				TF2_AddCondition(client, TFCond_DefenseBuffed, 999.0);
				TF2_AddCondition(client, TFCond_SmallBlastResist, 999.0);
			}
			case 40:
			{	
				CPrintToChatAll("%s%t", PREFIX, "seeman_1");
				TF2_AddCondition(client, TFCond_HalloweenQuickHeal, 999.0);
				TF2_AddCondition(client, TFCond_UberFireResist, 999.0);
				TF2_RemoveCondition(client, TFCond_SmallFireResist);
			}
	}
	else if(!StrContains(buffer, "prop_dynamic"))
	{
		GetEntPropString(entity, Prop_Data, "m_iName", buffer, sizeof(buffer));
		if(!StrContains(buffer, "scp_trigger", false))
		{
			ClassEnum class;
			if(Classes_GetByIndex(Client[client].Class, class))
			{
				switch(class.Group)
				{
					case 0:
						AcceptEntityInput(entity, "FireUser1", client, client);

					case 1:
						AcceptEntityInput(entity, "FireUser2", client, client);

					case 2:
						AcceptEntityInput(entity, "FireUser3", client, client);

					default:
						AcceptEntityInput(entity, "FireUser4", client, client);
				}
				return true;
			}
		}
	}
	else if(StrEqual(buffer, "func_button"))
	{
		GetEntPropString(entity, Prop_Data, "m_iName", buffer, sizeof(buffer));
		if(!StrContains(buffer, "scp_trigger", false))
		{
			AcceptEntityInput(entity, "Press", client, client);
			return true;
		}
	}
	return false;
}

public Action 682_OnTakeDamage(int client, int attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{		
	SetEntityHealth(client, GetClientHealth(client)+15);	
	return Plugin_Continue;
}

public Action Seeman_CaberTimer(Handle timer, int ref)
{
	int entity = EntRefToEntIndex(ref);
	if(entity <= MaxClients)
		return Plugin_Stop;

	SetEntProp(entity, Prop_Send, "m_bBroken", 0);
	SetEntProp(entity, Prop_Send, "m_iDetonated", 0);
	return Plugin_Continue;
}

public Action Seeman_NukeTimer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(client && IsClientInGame(client) && Client[client].Class==IndexSeeman)
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		for(int i=1; i<=MaxClients; i++)
		{
			if(i!=client && IsClientInGame(i) && IsPlayerAlive(i))
			{
				if(TF2_IsPlayerInCondition(i, TFCond_HalloweenGhostMode))
					TF2_RemoveCondition(i, TFCond_HalloweenGhostMode);

				SDKHooks_TakeDamage(i, client, client, 3000.34, DMG_BLAST|DMG_CRUSH|DMG_CRIT, weapon);
			}
		}

		ChangeGlobalSong(FAR_FUTURE, NukeSong);

		FakeClientCommand(client, "+taunt");
		FakeClientCommand(client, "+taunt");
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
}



public Action Seeman_OnSound(int client, char sample[PLATFORM_MAX_PATH], int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if(!StrContains(sample, "vo", false))
	{
		pitch += GetRandomInt(-35, 30);
		strcopy(sample, sizeof(sample), Seeman);
		return Plugin_Changed;
	}

	if(StrContains(sample, "footsteps", false) != -1)
	{
		level += 30;
		EmitSoundToAll(sample, client, channel, level, flags, volume, pitch);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}



//public void Seeldier_Enable(int index)
//{
	//IndexSeeldier = index;
//}

public void Seeldier2_Enable(int index)
{
	IndexSeeldier2 = index;
}

public bool Seeldier_Create(int client)
{
	Classes_VipSpawn(client);

	int weapon = SpawnWeapon(client, "tf_weapon_shovel", 6, 101, 5, "2 ; 3.1 ; 28 ; 0.5 ; 68 ; 2 ; 252 ; 0.6 ; 476 ; 0.372", 0);
	if(weapon > MaxClients)
	{
		ApplyStrangeRank(weapon, 20);
		SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}

	for(int target=1; target<=MaxClients; target++)
	{
		if(Client[target].Class == IndexSeeman)
		{
			EmitSoundToClient(client, Seeduo);
			break;
		}
	}
	return false;
}

public bool Seeldier2_Create(int client)
{
	int weapon = SpawnWeapon(client, "tf_weapon_shovel", 6, 101, 5, "15 ; 0 ; 180 ; 200 ; 191 ; -2", 0);
	if(weapon > MaxClients)
	{
		ApplyStrangeRank(weapon, 0);
		SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}
	
	return false;
}

public void Seeldier_OnKill(int client, int victim)
{
	Seeldier_Kill(client, victim);

	if(IndexSeeman)
	{
		for(int i=1; i<=MaxClients; i++)
		{
			if(IsClientInGame(i) && Client[i].Class==IndexSeeman)
			{
				//Seeman_Kill(i);
				break;
			}
		}
	}
}

public Action Seeldier_OnSound(int client, char sample[PLATFORM_MAX_PATH], int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if(!StrContains(sample, "vo", false))
	{
		pitch += GetRandomInt(-35, 30);
		strcopy(sample, sizeof(sample), Seeldier);
		return Plugin_Changed;
	}

	if(StrContains(sample, "footsteps", false) != -1)
	{
		level += 30;
		EmitSoundToAll(sample, client, channel, level, flags, volume, pitch);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

static void Seeldier_Kill(int client, int victim)
{
	DataPack pack;
	CreateDataTimer(0.5, Seeldier_Timer, pack, TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(GetClientUserId(victim));
}

public Action Seeldier_Timer(Handle timer, DataPack pack)
{
	if(Enabled)
	{
		pack.Reset();
		int client = GetClientOfUserId(pack.ReadCell());
		int victim = GetClientOfUserId(pack.ReadCell());
		if(client && IsClientInGame(client) && IsPlayerAlive(client) && victim && IsClientInGame(victim))
		{
			Client[victim].Class = IndexSeeldier2;
			TF2_RespawnPlayer(victim);
			Client[victim].Floor = Client[client].Floor;

			SetEntProp(victim, Prop_Send, "m_bDucked", true);
			SetEntityFlags(victim, GetEntityFlags(victim)|FL_DUCKING);

			static float pos[3];
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
			TeleportEntity(victim, pos, NULL_VECTOR, NULL_VECTOR);

			for(int i=1; i<=MaxClients; i++)
			{
				if(victim!=i && (client==i || IsFriendly(Client[i].Class, Client[client].Class)))
					Client[i].ThinkIsDead[victim] = false;
			}
		}
	}
	return Plugin_Continue;
}

public bool Saxtron_Create(int client)
{
	int weapon = SpawnWeapon(client, "tf_weapon_fists", 331, 101, 5, "2 ; 3.1 ; 28 ; 0.5 ; 68 ; 2 ; 252 ; 0 ; 330 ; 3 ; 334 ; 1", 2);
	if(weapon > MaxClients)
	{
		ApplyStrangeRank(weapon, 20);
		SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}
	return false;
}

public bool MTF105_OnGlow(int client, int target)
{
	static float pos1[3], pos2[3];
	GetClientEyePosition(client, pos1);
	GetClientAbsOrigin(target, pos2);
	return GetVectorDistance(pos1, pos2) < ((GetGameTime()-RoundStartAt)*3.0);
}

public bool MTF076_Create(int client)
{
	int weapon = SpawnWeapon(client, "tf_weapon_sword", 266, 90, 13, "2 ; 101 ; 5 ; 1.1 ; 28 ; 0.25 ; 138 ; 0.0305 ; 252 ; 0", 2);
	if(weapon > MaxClients)
	{
		ApplyStrangeRank(weapon, 18);
		SetEntProp(weapon, Prop_Send, "m_iAccountID", GetSteamAccountID(client, false));
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}
	return false;
}
