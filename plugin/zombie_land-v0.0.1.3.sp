#pragma semicolon 1

#define PLUGIN_AUTHOR "[W]atch [D]ogs , The Team Ghost"
#define PLUGIN_VERSION "0.0.1.3"

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>

#pragma newdecls required

Handle h_cInterval;
Handle h_GameDesc;

Handle hConVarBalance;
Handle hConVarLimit;

bool b_GameStarted = false;

char sGameDesc[64];

int iInterval, iBlues = 0;

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
	
	h_cInterval = CreateConVar("sm_zml_time", "120", "The round start timer interval in seconds", _, true, 5.0);
	h_GameDesc = CreateConVar("sm_zml_gamedesc", "Zombie-Land", "What to override game description to (To disable it leave empty.)");
	
	HookEvent("player_spawn", TF2_PlayerSpawn);
	HookEvent("player_death", TF2_PlayerDeath);
	HookEvent("teamplay_round_start", TF2_RoundStart);
	HookEvent("teamplay_round_win", TF2_RoundEnd);
	
	AddCommandListener(DisableSentry_Red, "build");
	
	hConVarBalance = FindConVar("mp_autoteambalance");
	hConVarLimit = FindConVar("mp_teams_unbalance_limit");
	
	AutoExecConfig(true, "ZombieLand");
}

public void OnConfigsExecuted()
{
	GetConVarString(h_GameDesc, sGameDesc, sizeof(sGameDesc));
}


public Action DisableSentry_Red(int client, char[] command, int argc)
{
	char sObjectMode[256], sObjectType[256];
	GetCmdArg(1, sObjectType, sizeof(sObjectType));
	GetCmdArg(2, sObjectMode, sizeof(sObjectMode));
	
	int iObjectMode = StringToInt(sObjectMode),
			iObjectType = StringToInt(sObjectType),
			iTeam       = GetClientTeam(client);
		
	if(iTeam == 2 && iObjectType == 2 && iObjectMode == 0)
		return Plugin_Handled;
		
	return Plugin_Continue;
}

public Action TF2_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	any team = TF2_GetClientTeam(client);
	
	if(b_GameStarted)
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
	
	if(b_GameStarted)
	{
		if (TF2_GetClientTeam(client) == TFTeam_Red)TF2_ChangeClientTeam(client, TFTeam_Blue); else iBlues--;
		TF2_RespawnPlayer(client);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action TF2_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(!StrEqual(sGameDesc, ""))
		OnGetGameDescription(sGameDesc);
	
	CreateTimer(GetConVarFloat(h_cInterval), StartZombieMod, _, TIMER_FLAG_NO_MAPCHANGE);
	
	iInterval = GetConVarInt(h_cInterval);
	
	CreateTimer(1.0, CountDown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action TF2_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	b_GameStarted = false;
	
	SetConVarInt(hConVarBalance, 1);
	SetConVarInt(hConVarLimit, 1);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && TF2_IsPlayerInCondition(i, TFCond_MeleeOnly))
			TF2_RemoveCondition(i, TFCond_MeleeOnly);
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
	
	b_GameStarted = true;
	
	PrintHintTextToAll("Zombies have been released!!!");
	PrintToChatAll("[Zombie-Land] Game has started. Hide or they will get you!");
}

public Action CountDown(Handle timer)
{
	if (iInterval <= 0)
		return Plugin_Stop;
	
	PrintHintTextToAll("Zombie Land starts in: %d Seconds.", iInterval);	
	
	iInterval--;

	return Plugin_Continue;
}

public Action OnGetGameDescription(char gameDesc[64])
{
	strcopy(gameDesc, 64, sGameDesc);
	return Plugin_Changed;
}


public void SetPlayerClass(int client, any team)
{
	if(team == TFTeam_Red)
	{
		TF2_SetPlayerClass(client, TFClass_Engineer);
	} else 
	{
		TF2_SetPlayerClass(client, TFClass_Medic, false);
		if(!TF2_IsPlayerInCondition(client, TFCond_MeleeOnly)) TF2_AddCondition(client, TFCond_MeleeOnly);
		if(TF2_IsPlayerInCondition(client, TFCond_HalloweenTiny)) TF2_RemoveCondition(client, TFCond_HalloweenTiny);
		
		CreateTimer(0.1, SetMeleeOnly, client);
	}
}

public Action SetMeleeOnly(Handle timer, any client)
{
	for (int i = 0; i <= 5; i++)
	{
		if (i == 2)
		{
			continue;
		}

		TF2_RemoveWeaponSlot(client, i);
	}

	int weapon = GetPlayerWeaponSlot(client, 2);
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
}
