#pragma semicolon 1

#define PLUGIN_NAME "[TF2] Zombie Land"
#define PLUGIN_AUTHOR "[W]atch[D]ogs , The Team Ghost"
#define PLUGIN_DESC "Dedicated zombie mod for zombie land"
#define PLUGIN_VERSION "0.0.7.3"
#define PLUGIN_URL "http://theteamghost.clanservers.com/"


#define UPDATE_URL "http://theteamghost.clanservers.com/.updater/zombieland/zlupdate.txt"

#define DEBUG	1

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
Handle h_Precent;
Handle h_MinPlayers;

Handle hConVarBalance;
Handle hConVarLimit;

bool b_GameStarted = false;
bool b_IsZlMap = false;

int iInterval;

char sMapPrefix[256];


public Plugin myinfo = 
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESC,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_TF2) 
	{
		SetFailState("Game not supported. This plugin only supports Team Fortress 2");
	}
	
	if(LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	
	h_cInterval = CreateConVar("sm_zl_time", "120", "The round start timer interval in seconds.", _, true, 5.0);
	h_MapPrefix = CreateConVar("sm_zl_prefixes", "zf_,koth_,cp_", "Map prefixes seperated by comma, leave this empty for all maps. (koth_, cp_ for example)");
	h_Precent = CreateConVar("sm_zl_zmpercent", "0.20", "The percent of players that should move to blue team as zombies", _, true, 0.05, true, 1.0);
	h_MinPlayers = CreateConVar("sm_zl_minplayers", "2", "Min players to start the game", _, true, 2.0);
	
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
				PrintToServer("[Zombie-Land]: Specified map detected. Enabling Zombie-Land Gamemode.");
				b_IsZlMap = true;
				Steam_SetGameDescription("Zombie Land");
				AddServerTag("zombieland");
				ToggleObjectiveState(false);
				break;
			}
		}
		
		if(!b_IsZlMap)
		{
			PrintToServer("[Zombie-Land]: Current map is not a specified map. Disabling Zombie-Land Gamemode.");
			Steam_SetGameDescription("Team Fortress");	
			RemoveServerTag("zombieland");
			ToggleObjectiveState(true);
		}
	} 
	else 
	{
		PrintToServer("Zombie-Land is currently enabled for all maps. Enabling Zombie-Land Gamemode.");
		b_IsZlMap = true;
		Steam_SetGameDescription("Zombie Land");
		AddServerTag("zombieland");
		ToggleObjectiveState(false);
	}
}

public void OnMapEnd()
{
	b_IsZlMap = false;
	b_GameStarted = false;
}

public Action DisableSentry_Red(int client, char[] command, int argc)
{
	if(b_IsZlMap){
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
	if(b_IsZlMap && IsEnoughPlayers())
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		
		if(TF2_GetClientTeam(client) == TFTeam_Blue)
		{
			#if DEBUG
				LogMessage("[OnPlayerInventory] Setting MeleeOnly on client: %N", client);
			#endif
			
			TF2_RemoveAllWeapons(client);
		
			int iWeapon = CreateEntityByName("tf_weapon_bonesaw", 8);
			DispatchSpawn(iWeapon); 
			EquipPlayerWeapon(client, iWeapon);
			
			TF2_SwitchtoSlot(client, TFWeaponSlot_Melee);
		}
	}
}

public Action TF2_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	TFTeam team = TF2_GetClientTeam(client);
	
	if(b_IsZlMap && (team == TFTeam_Red || team == TFTeam_Blue))
	{
		if(b_GameStarted)
		{
			if (team == TFTeam_Red) 
			{
				#if DEBUG
					LogMessage("[OnPlayerSpawn - GameStarted] Changing client(%N) team from red to blue", client);
				#endif
				
				TF2_ChangeClientTeam(client, TFTeam_Blue);
				PrintCenterText(client, "[Zombie-Land] You can't spawn on RED. Switching to BLU.");
			}
			
			if(GetClientCountTeam(TFTeam_Red) == 0)
			{
				#if DEBUG
					LogMessage("[OnPlayerSpawn] Restaring round because all players are in blue team.");
				#endif
				
				int entityTimer = FindEntityByClassname(-1, "team_round_timer");
				if (entityTimer > -1)
				{
					SetVariantInt(1);
					AcceptEntityInput(entityTimer, "SetTime");
				}
				else
				{
					Handle timelimit = FindConVar("mp_timelimit");
					SetConVarFloat(timelimit, 1.0);
					CloseHandle(timelimit);
				}
				return Plugin_Changed;
			}
			SetPlayerClass(client, TFTeam_Blue, true);
			return Plugin_Changed;
		}
		else
		{
			if (team == TFTeam_Blue) 
			{
				#if DEBUG
					LogMessage("[OnPlayerSpawn - !GameStarted] Changing client(%N) team from blue to red", client);
				#endif
				
				TF2_ChangeClientTeam(client, TFTeam_Red);
				PrintCenterText(client, "[Zombie-Land] You can't spawn on BLU. Switching to RED.");
				SetPlayerClass(client, TFTeam_Red, true);
				return Plugin_Changed;
			}
		}
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
			#if DEBUG
				LogMessage("[OnPlayerDeath - GameStarted] Changing client(%N) team from red to blue", client);
			#endif
			
			TF2_ChangeClientTeam(client, TFTeam_Blue); 
		} 
		
		#if DEBUG
			LogMessage("[OnPlayerDeath - GameStarted] Client (%N) has respawned.", client);
		#endif
		
		TF2_RespawnPlayer(client);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action TF2_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(b_IsZlMap && IsEnoughPlayers())
	{
		#if DEBUG
			LogMessage("[RoundStart - IsZLMap] Timers created.");
		#endif
		
		CreateTimer(GetConVarFloat(h_cInterval), StartZombieMod, _, TIMER_FLAG_NO_MAPCHANGE);
	
		iInterval = GetConVarInt(h_cInterval);
	
		CreateTimer(1.0, CountDown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action TF2_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	if(b_GameStarted)
	{
		#if DEBUG
			LogMessage("[RoundEnd - GameStarted] Setting game started to false & enabling doors.");
		#endif
		
		int ent = -1;
		while( (ent = FindEntityByClassname(ent, "func_respawnroomvisualizer")) != -1 )
			AcceptEntityInput(ent, "Enable");
			
		while( (ent = FindEntityByClassname(ent, "func_regenerate")) != -1 )
			AcceptEntityInput(ent, "Enable");
			
		b_GameStarted = false;
	}
}

public Action StartZombieMod(Handle timer)
{
	#if DEBUG
		LogMessage("[StartZombieMod - Timer_CallBack] Moving players , SetClasses and start the game.");
	#endif
		
	SetConVarInt(hConVarBalance, 0);
	SetConVarInt(hConVarLimit, 0);

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(TF2_GetClientTeam(i) == TFTeam_Blue)
			{
				#if DEBUG
					LogMessage("[StartZombieMod - Timer_CallBack] Moving all players to red. client: %N", i);
				#endif
				
				TF2_ChangeClientTeam(i, TFTeam_Red);
			}
			SetPlayerClass(i, TFTeam_Red);
		}
	}

	int Blue_Count = RoundFloat(GetClientCountTeam(TFTeam_Red) * GetConVarFloat(h_Precent)), j = 0;
	if (Blue_Count == 0) Blue_Count = 1;
	
	#if DEBUG
		LogMessage("[StartZombieMod - Timer_CallBack] Randomizing blue players of 20 precent value is: %i", Blue_Count);
	#endif

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && j <= Blue_Count)
		{
			#if DEBUG
				LogMessage("[StartZombieMod - Timer_CallBack] Moving random players to team blue. client: %N", i);
			#endif
			
			TF2_ChangeClientTeam(i, TFTeam_Blue);
			SetPlayerClass(i, TFTeam_Blue);
			j++;
		}
	}
	
	#if DEBUG
		LogMessage("[StartZombieMod - Timer_CallBack] Making doors disable...");
	#endif
	
	int ent = -1;
	while( (ent = FindEntityByClassname(ent, "func_respawnroomvisualizer")) != -1 )
		AcceptEntityInput(ent, "Disable");
		
	while( (ent = FindEntityByClassname(ent, "func_regenerate")) != -1 )
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

void SetPlayerClass(int client, TFTeam team, bool IsInSpawn=false)
{
	if (!IsPlayerAlive(client)) TF2_RespawnPlayer(client);
	
	if(team == TFTeam_Red)
	{
		#if DEBUG
			LogMessage("[SetPlayerClass] Red client (%N) detected. Setting class to Engineer...", client);
		#endif
		
		TF2_SetPlayerClass(client, TFClass_Engineer, !IsInSpawn);
	} 
	else 
	{
		#if DEBUG
			LogMessage("[SetPlayerClass] Blue client (%N) detected. Setting class to Medic & Setting MeleeOnly...", client);
		#endif
		
		TF2_SetPlayerClass(client, TFClass_Medic, !IsInSpawn);
	
		TF2_RemoveAllWeapons(client);
		
		int iWeapon = CreateEntityByName("tf_weapon_bonesaw", 8);
		DispatchSpawn(iWeapon); 
		EquipPlayerWeapon(client, iWeapon);
		
		TF2_SwitchtoSlot(client, TFWeaponSlot_Melee);
	}
}

void ToggleObjectiveState(bool newState)
{
	#if DEBUG
		LogMessage("[ToggleObjectiveState] Toggling objective state (%s)", newState ? "True":"False");
	#endif
	
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
	#if DEBUG
		LogMessage("[SwitchToSlot] Switching to MeleeOnly Slot Client (%N)", client);
	#endif
	
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

int GetClientCountTeam(TFTeam team)
{
	int j = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && TF2_GetClientTeam(i) == team)
		{
			j++;
		}
	}
	return j;
}

bool IsEnoughPlayers()
{
	if (GetClientCount() >= GetConVarInt(h_MinPlayers))
		return true;
	else 
		return false;
}

/* We will add it later - Don't touch it please!

void TF2_PrintToChatTeam(TFTeam team, char format[])
{
	char buffer[192];
	int i = 1;
	while (i <= MaxClients)
	{
		if (IsClientInGame(i) && TF2_GetClientTeam(i) == team)
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, 192, format, 2);
			PrintToChat(i, "%s", buffer);
		}
		i++;
	}
}

*/