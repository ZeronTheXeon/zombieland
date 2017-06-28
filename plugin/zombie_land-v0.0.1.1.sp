#pragma semicolon 1

#define PLUGIN_AUTHOR "[W]atch [D]ogs"
#define PLUGIN_VERSION "0.0.1.1"

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <steamtools>

#pragma newdecls required

Handle h_Enable;
Handle h_cInterval;
Handle h_GameDesc;
Handle hTeam;

bool b_GameStarted = false;

char sGameDesc[128];
char sDefGameDesc[128] = "Team Fortress";

int iInterval;

public Plugin myinfo = 
{
	name = "[TF2] Zombie Mod",
	author = PLUGIN_AUTHOR,
	description = "Dedicated zombie mod for zombie land",
	version = PLUGIN_VERSION
};

public void OnPluginStart()
{
	if(GetEngineVersion() != Engine_TF2) SetFailState("Game not supported. This plugin only supports Team Fortress 2");
	
	h_Enable = CreateConVar("sm_tf2zm_enable", "1", "Enable/Disable TF2 Zombie Mod", _, true, 0.0, true, 1.0);
	h_cInterval = CreateConVar("sm_tf2zm_time", "120", "The round start timer interval in seconds", _, true, 5.0);
	h_GameDesc = CreateConVar("sm_tf2zm_gamdesc", "Zombie-Land", "What to override game description to (For disable this just leave it empty)");
	
	HookConVarChange(h_GameDesc, gdCvar_Changed);
	
	hTeam = FindConVar("mp_humans_must_join_team");
	
	HookEvent("player_death", TF2_PlayerDeath);
	HookEvent("teamplay_round_start", TF2_RoundStart);
	HookEvent("teamplay_round_win", TF2_RoundEnd);
	
	AddCommandListener(DisableSentry_Red, "build");
	
	AutoExecConfig(true, "TF2_ZombieMod");
}

public void OnConfigsExecuted()
{
	GetConVarString(h_GameDesc, sGameDesc, sizeof(sGameDesc));
	
	Handle STGameDescOverride = FindConVar("st_gamedesc_override");
	
	if(STGameDescOverride == INVALID_HANDLE) STGameDescOverride = FindConVar("sw_gamedesc_override");
	
	if(STGameDescOverride != INVALID_HANDLE) GetConVarString(STGameDescOverride, sDefGameDesc, sizeof(sDefGameDesc));
}

public void gdCvar_Changed(Handle convar, char[] oldValue, char[] newValue)
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
		
	if(GetConVarBool(h_Enable) && iTeam == 2 && iObjectType == 2 && iObjectMode == 0)
		return Plugin_Handled;
		
	return Plugin_Continue;
}

public Action TF2_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(GetConVarBool(h_Enable) && client != 0 && TF2_GetClientTeam(client) == TFTeam_Red && b_GameStarted)
	{
		TF2_ChangeClientTeam(client, TFTeam_Blue);
		TF2_SetPlayerClass(client, TFClass_Medic);
		TF2_AddCondition(client, TFCond_MeleeOnly);
		TF2_RespawnPlayer(client);
	}
}

public Action TF2_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if(GetConVarBool(h_Enable))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && TF2_GetClientTeam(i) == TFTeam_Blue)
			{
				TF2_ChangeClientTeam(i, TFTeam_Red);
				TF2_SetPlayerClass(i, TFClass_Engineer);
			}
		}
		SetConVarString(hTeam, "red");
		
		if(!StrEqual(sGameDesc, ""))
			Steam_SetGameDescription(sGameDesc);
		
		CreateTimer(GetConVarFloat(h_cInterval), StartZombieMod, _, TIMER_FLAG_NO_MAPCHANGE);
		
		iInterval = GetConVarInt(h_cInterval);
		
		CreateTimer(1.0, CountDown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action TF2_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	b_GameStarted = false;
	
	SetConVarString(hTeam, "any");
	
	Steam_SetGameDescription(sDefGameDesc);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && TF2_IsPlayerInCondition(i, TFCond_MeleeOnly))
			TF2_RemoveCondition(i, TFCond_MeleeOnly);
	}
}

public Action StartZombieMod(Handle timer)
{
	PrintToChatAll("[TF2-Zombie] Moving some players as Zombies to Blu team...");
	
	int Blue_Count = RoundFloat(GetClientCount() * 0.2), j = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i)) 
			TF2_SetPlayerClass(i, TFClass_Engineer);
			
		if(IsClientInGame(i) && !IsFakeClient(i) && j <= Blue_Count)
		{
			TF2_ChangeClientTeam(i, TFTeam_Blue);
			TF2_SetPlayerClass(i, TFClass_Medic);
			TF2_AddCondition(i, TFCond_MeleeOnly);
			j++;
		}
		
	}
	
	b_GameStarted = true;
	
	PrintHintTextToAll("Zombie Mod Started! GO GO GO...");
	PrintToChatAll("[TF2-Zombie] Game has started. GO! GO! GO!...");
}

public Action CountDown(Handle timer)
{
	if (iInterval <= 0)
		return Plugin_Stop;
	
	PrintHintTextToAll("Zombie Mod starts in: %d Seconds.", iInterval);	
	
	iInterval--;

	return Plugin_Continue;
}
