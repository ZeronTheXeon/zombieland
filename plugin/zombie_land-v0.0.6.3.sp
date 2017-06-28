#pragma semicolon 1

#define PLUGIN_AUTHOR "[W]atch [D]ogs , The Team Ghost"
#define PLUGIN_VERSION "0.0.6.3"
#define UPDATE_URL "http://theteamghost.clanservers.com/.updater/zombieland/zlupdate.txt"

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdktools>
#include <steamtools>
#undef REQUIRE_PLUGIN
#include <updater>

#pragma newdecls required

Handle h_cInterval;
Handle h_MapPrefix;

Handle hConVarBalance;
Handle hConVarLimit;

bool b_GameStarted = false;
bool b_isZLmap = false;

int iInterval, iBlues = 0;

char sMapPrefix[256];

public Plugin myinfo = 
{
	name = "[TF2] Zombie Land",
	author = PLUGIN_AUTHOR,
	description = "Dedicated zombie mod for zombie land",
	version = PLUGIN_VERSION
};

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_TF2) SetFailState("Game not supported. This plugin only supports Team Fortress 2");
	
	if(LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	
	h_cInterval = CreateConVar("sm_zl_time", "120", "The round start timer interval in seconds.", _, true, 5.0);
	h_MapPrefix = CreateConVar("sm_zl_prefixes", "zf_,zl_", "Map prefixes seperated by comma, leave empty for all maps. (koth_, cp_ for example)");
	
	HookEvent("post_inventory_application", OnPlayerInventory);
	HookEvent("player_spawn", TF2_PlayerSpawn);
	HookEvent("player_death", TF2_PlayerDeath);
	HookEvent("teamplay_round_start", TF2_RoundStart);
	HookEvent("teamplay_round_win", TF2_RoundEnd);
	
	AddCommandListener(DisableSentry_Red, "build");
	
	hConVarBalance = FindConVar("mp_autoteambalance");
	hConVarLimit = FindConVar("mp_teams_unbalance_limit");
	
	AutoExecConfig(true, "ZombieLand");
}

public void OnLibraryAdded(const char[] updater)
{
	if(StrEqual(updater, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

public int Updater_OnPluginUpdated()
{
	ReloadPlugin(GetMyHandle());
}

public void OnConfigsExecuted()
{
	GetConVarString(h_MapPrefix, sMapPrefix, sizeof(sMapPrefix));
	if(!StrEqual(sMapPrefix, ""))
	{
		ReplaceString(sMapPrefix, sizeof(sMapPrefix), " ", "");
		
		char sPrefixes[100][128];
		ExplodeString(sMapPrefix, ",", sPrefixes, 100, 128);
		
		char sMap[128];
		GetCurrentMap(sMap, sizeof(sMap));
		
		for (int i = 0; i < 100; i++)
		{
			if(StrEqual(sPrefixes[i], ""))
			{
				break;
			}
			
			if (strncmp(sMap, sPrefixes[i], strlen(sPrefixes[i]), false) == 0)
			{
				PrintToServer("Specified Zombie-Land map detected. Enabling Zombie-Land Gamemode.");
				b_isZLmap = true;
				Steam_SetGameDescription("Zombie Land");
				AddServerTag("zombieland");
				ToggleObjectiveState(false);
				break;
			}
		}
		
		if(!b_isZLmap)
		{
			PrintToServer("Current map is not a specified Zombie-Land map. Disabling Zombie-Land Gamemode.");
			Steam_SetGameDescription("Team Fortress");	
			RemoveServerTag("zombieland");
			ToggleObjectiveState(true);
		}
	} 
	else 
	{
		PrintToServer("Zombie-Land is currently enabled for all maps. Enabling Zombie-Land Gamemode.");
		b_isZLmap = true;
		Steam_SetGameDescription("Zombie Land");
		AddServerTag("zombieland");
		ToggleObjectiveState(false);
	}
}

public void OnMapEnd()
{
	b_isZLmap = false;
	b_GameStarted = false;
}

public Action DisableSentry_Red(int client, char[] command, int argc)
{
	if(b_isZLmap){
		char sObjectMode[256], sObjectType[256];
		GetCmdArg(1, sObjectType, sizeof(sObjectType));
		GetCmdArg(2, sObjectMode, sizeof(sObjectMode));
	
		int iObjectMode = StringToInt(sObjectMode),
				iObjectType = StringToInt(sObjectType),
				iTeam       = GetClientTeam(client);
		
		if(iTeam == 2 && iObjectType == 2 && iObjectMode == 0)
			return Plugin_Handled;
	}
		
	return Plugin_Continue;
}

public Action OnPlayerInventory(Handle event, const char[] name, bool dontBroadcast)
{
	if(b_GameStarted)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		
		if(TF2_GetClientTeam(client) == TFTeam_Blue)
		{
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Grenade);
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
		
			TF2_SwitchtoSlot(client, TFWeaponSlot_Melee);
		}
	}
}

public Action TF2_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	TFTeam team = TF2_GetClientTeam(client);
	
	if(b_GameStarted && (team == TFTeam_Red || team == TFTeam_Blue))
	{
		if (team == TFTeam_Red) 
		{
			TF2_ChangeClientTeam(client, TFTeam_Blue);
			PrintCenterText(client, "[Zombie-Land] You can't spawn on RED. Switching to BLU.");
		}
		
		iBlues++;
		
		if(iBlues == GetClientCount())
		{
			int entityTimer = FindEntityByClassname(-1, "team_round_timer");
			if (entityTimer > -1)
			{
				SetVariantInt(1);
				AcceptEntityInput(entityTimer, "SetTime");
			}
			else
			{
				Handle timelimit = FindConVar("mp_timelimit");
				SetConVarFloat(timelimit, 1.0 / 60);
				CloseHandle(timelimit);
			}
		}
		SetPlayerClass(client, TFTeam_Blue);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action TF2_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	TFTeam team = TF2_GetClientTeam(client);
	
	if(b_GameStarted && (team == TFTeam_Red || team == TFTeam_Blue))
	{
		if (team == TFTeam_Red) 
		{
			TF2_ChangeClientTeam(client, TFTeam_Blue); 
		} 
		else 
		{
			iBlues--;
		}
		TF2_RespawnPlayer(client);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action TF2_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(b_isZLmap)
	{	
		CreateTimer(GetConVarFloat(h_cInterval), StartZombieMod, _, TIMER_FLAG_NO_MAPCHANGE);
	
		iInterval = GetConVarInt(h_cInterval);
	
		CreateTimer(1.0, CountDown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action TF2_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	if(b_GameStarted)
	{
		int ent = -1;
		while( (ent = FindEntityByClassname(ent, "func_respawnroomvisualizer")) != -1 )
			AcceptEntityInput(ent, "Enable");
			
		b_GameStarted = false;
	}
}

public Action StartZombieMod(Handle timer)
{
	SetConVarInt(hConVarBalance, 0);
	SetConVarInt(hConVarLimit, 0);

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && TF2_GetClientTeam(i) == TFTeam_Blue)
		{
			TF2_ChangeClientTeam(i, TFTeam_Red);
			SetPlayerClass(i, TFTeam_Red);
		}
	}

	int Blue_Count = RoundFloat(GetClientCount() * 0.2), j = 0;
	

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && j <= Blue_Count)
		{
			TF2_ChangeClientTeam(i, TFTeam_Blue);
			SetPlayerClass(i, TFTeam_Blue);
			j++;
		}
	}

	iBlues = j;
	
	int ent = -1;
	while( (ent = FindEntityByClassname(ent, "func_respawnroomvisualizer")) != -1 )
		AcceptEntityInput(ent, "Disable");
		
	b_GameStarted = true;

	PrintHintTextToAll("Zombies have been released!!!");
	PrintToChatAll("[Zombie-Land]: Game has started. Hide or they will get you!");
}

public Action CountDown(Handle timer)
{
	if (iInterval <= 0)
		return Plugin_Stop;
	
	PrintHintTextToAll("Zombie Land starts in: %d Seconds.", iInterval);	
	
	iInterval--;

	return Plugin_Continue;
}

public void SetPlayerClass(int client, TFTeam team)
{
	if (!IsPlayerAlive(client)) TF2_RespawnPlayer(client);
	
	if(team == TFTeam_Red)
	{
		TF2_SetPlayerClass(client, TFClass_Engineer);
	} 
	else 
	{
		TF2_SetPlayerClass(client, TFClass_Medic);
		
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Grenade);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
		
		TF2_SwitchtoSlot(client, TFWeaponSlot_Melee);
	
		int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}
}

void ToggleObjectiveState(bool newState)
{
	/* Things to enable or disable */
	char targets[5][25] = {"team_control_point_master","team_control_point","trigger_capture_area","item_teamflag","func_capturezone"};
	char input[7] = "Disable";
	if(newState) input = "Enable";
 
	/* Loop through things that should be enabled/disabled, and push it as an input */
	int ent = 0;
	for (int i = 0; i < 5; i++)
	{
		ent = MaxClients+1;
		while((ent = FindEntityByClassname(ent, targets[i]))!=-1)
		{
			AcceptEntityInput(ent, input);
		}
	}
}

void TF2_SwitchtoSlot(int client, int slot)
{
	if (slot >= 0 && slot <= 5 && IsClientInGame(client))
	{
		char classname[64];
		int wep = GetPlayerWeaponSlot(client, slot);
		if (wep > MaxClients && IsValidEdict(wep) && GetEdictClassname(wep, classname, sizeof(classname)))
		{
			FakeClientCommandEx(client, "use %s", classname);
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", wep);
		}
	}
}	