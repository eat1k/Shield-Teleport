/*
 * Copy of SourceMod plugin "Shield Teleport" whose:
 * - Author is Drumanid ( https://dev-cs.ru/members/2742/ )
 * - Official topic is https://dev-cs.ru/resources/592/
 *
 * Author contact: https://t.me/twisternick or:
 *	- Official resource topic on Russian forum: https://dev-cs.ru/threads/4363/
 *	- Official resource topic on English forum: https://forums.alliedmods.net/showthread.php?t=312213
 *	- Official resource topic on Spanish forum: https://amxmodx-es.com/Thread-Shield-Teleport-v1-0?pid=191695#pid191695
 *
 * Changelog:
 *	- 1.1:
 *		- Use of engine instead of hamsandwich (thanks to 6u3oH).
 *		- COORD_X, COORD_Y and TIME_HUD now in cvars: shield_teleport_message_hud_x, shield_teleport_message_hud_y and shield_teleport_message_hud_time.
 *	- 1.0: Release.
 */

#include <amxmodx>
#include <engine>
#include <reapi>

#pragma semicolon 1

enum (+= 100)
{
	TASK_ID_TIMESHIELD
};

new bool:g_bAlive[MAX_PLAYERS+1];
new Float:g_flTime[MAX_PLAYERS+1];

enum _:CVARS
{
	Float:CVAR_TIMER,
	CVAR_GLOW,
	CVAR_TIMEBLOCK,
	CVAR_TEAM,
	CVAR_MESSAGE,
	Float:CVAR_MESSAGE_HUD_X,
	Float:CVAR_MESSAGE_HUD_Y,
	Float:CVAR_MESSAGE_HUD_TIME
};

new g_vCvar[CVARS];

new g_iSyncHudMessage;

public plugin_init()
{
	register_plugin("Shield Teleport", "1.1", "w0w");
	register_dictionary("shield_teleport.txt");

	RegisterHookChain(RG_CSGameRules_PlayerSpawn, "refwd_PlayerAlive_Post", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "refwd_PlayerAlive_Post", true);
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "refwd_PlayerTakeDamage_Pre");
	register_touch("trigger_teleport", "player", "touch_TriggerTeleport");

	g_iSyncHudMessage = CreateHudSyncObj();

	new pCvar = create_cvar("shield_teleport_timer", "3.0", FCVAR_NONE, "How many seconds will the player be protected and won't be able to damage after using a teleport?", true, 0.1);
	bind_pcvar_float(pCvar, g_vCvar[CVAR_TIMER]);

	pCvar = create_cvar("shield_teleport_glow", "1", FCVAR_NONE, "1 - Enable the glow which shows that damage is forbidden on the player / 0 - disabled", true, 0.0, true, 1.0);
	bind_pcvar_num(pCvar, g_vCvar[CVAR_GLOW]);

	pCvar = create_cvar("shield_teleport_time_block", "10", FCVAR_NONE, "How many seconds don't give the player protection after using a teleport?", true, 0.0);
	bind_pcvar_num(pCvar, g_vCvar[CVAR_TIMEBLOCK]);

	pCvar = create_cvar("shield_teleport_team", "1", FCVAR_NONE, "Which team can get protection? 1 - any / 2 - Terrorists / 3 - Counter-Terrorists", true, 1.0, true, 3.0);
	bind_pcvar_num(pCvar, g_vCvar[CVAR_TEAM]);

	pCvar = create_cvar("shield_teleport_message", "2", FCVAR_NONE, "How to display messages to the player? 0 - disabled / 1 - chat / 2 - center / 3 - hud", true, 0.0, true, 3.0);
	bind_pcvar_num(pCvar, g_vCvar[CVAR_MESSAGE]);

	pCvar = create_cvar("shield_message_hud_x", "-1.0", FCVAR_NONE, "Coordinate X for hud message (if shield_teleport_message = 3)");
	bind_pcvar_float(pCvar, g_vCvar[CVAR_MESSAGE_HUD_X]);

	pCvar = create_cvar("shield_message_hud_y", "0.70", FCVAR_NONE, "Coordinate Y for hud message (if shield_teleport_message = 3)");
	bind_pcvar_float(pCvar, g_vCvar[CVAR_MESSAGE_HUD_Y]);

	pCvar = create_cvar("shield_message_hud_time", "3.0", FCVAR_NONE, "How many seconds will the hud message be displayed (if shield_teleport_message = 3)", true, 0.1);
	bind_pcvar_float(pCvar, g_vCvar[CVAR_MESSAGE_HUD_TIME]);

	AutoExecConfig(true, "shield_teleport");
}

public client_disconnected(id)
{
	g_bAlive[id] = false;
	remove_task(id);
}

public refwd_PlayerAlive_Post(id)
{
	g_bAlive[id] = bool:is_user_alive(id);
}

public refwd_PlayerTakeDamage_Pre(iVictim, iInflictor, iAttacker)
{
	#pragma unused iInflictor

	if(is_user_connected(iAttacker) && (task_exists(iVictim+TASK_ID_TIMESHIELD) || task_exists(iAttacker+TASK_ID_TIMESHIELD)))
	{
		SetHookChainReturn(ATYPE_INTEGER, false);
		return HC_SUPERCEDE;
	}
	return HC_CONTINUE;
}

public touch_TriggerTeleport(iTouched, iToucher)
{
	if(g_bAlive[iToucher])
		func_TeleportUse(iToucher);
	return PLUGIN_CONTINUE;
}

func_TeleportUse(id)
{
	if(g_vCvar[CVAR_TEAM] != 1 && (get_member(id, m_iTeam) != (g_vCvar[CVAR_TEAM] - 1)))
		return;

	new Float:flGameTime = get_gametime();

	if(g_flTime[id] > flGameTime)
	{
		func_ShowMessage(id, "%l", "SHIELD_TELEPORT_COOLDOWN", g_flTime[id] - flGameTime);
		return;
	}

	g_flTime[id] = flGameTime + g_vCvar[CVAR_TIMEBLOCK];
	func_ShowMessage(id, "%l", "SHIELD_TELEPORT_ENABLED", g_vCvar[CVAR_TIMER]);

	remove_task(id+TASK_ID_TIMESHIELD);
	set_task(g_vCvar[CVAR_TIMER], "task_TimeShield", id+TASK_ID_TIMESHIELD);

	if(!g_vCvar[CVAR_GLOW]) return;

	rg_set_user_rendering(id, kRenderFxGlowShell, 165, 42, 42, kRenderNormal, 255);
}

public task_TimeShield(id)
{
	id -= TASK_ID_TIMESHIELD;

	if(!g_bAlive[id])
	{
		remove_task(id+TASK_ID_TIMESHIELD);
		return;
	}

	if(g_vCvar[CVAR_GLOW])
		rg_set_user_rendering(id);

	remove_task(id+TASK_ID_TIMESHIELD);
	func_ShowMessage(id, "%l", "SHIELD_TELEPORT_DISABLED");
}

func_ShowMessage(id, szMessage[], any:...)
{
	new szText[192]; vformat(szText, charsmax(szText), szMessage, 3);

	switch(g_vCvar[CVAR_MESSAGE])
	{
		case 1: client_print_color(id, print_team_default, szText);
		case 2: client_print(id, print_center, szText);
		case 3:
		{
			set_hudmessage(255, 255, 255, g_vCvar[CVAR_MESSAGE_HUD_X], g_vCvar[CVAR_MESSAGE_HUD_Y], 0, 0.5, g_vCvar[CVAR_MESSAGE_HUD_TIME], 0.5, 0.5);
			ShowSyncHudMsg(id, g_iSyncHudMessage, szText);
		}
	}
}

stock rg_set_user_rendering(id, iRenderFx = kRenderFxNone, iRed = 255, iGreen = 255, iBlue = 255, iRender = kRenderNormal, iAmount = 16)
{
	if(!is_user_connected(id)) return PLUGIN_CONTINUE;

	new Float:flRenderColor[3];
	flRenderColor[0] = float(iRed); flRenderColor[1] = float(iGreen); flRenderColor[2] = float(iBlue);

	set_entvar(id, var_renderfx, iRenderFx);
	set_entvar(id, var_rendercolor, flRenderColor);
	set_entvar(id, var_rendermode, iRender);
	set_entvar(id, var_renderamt, float(iAmount));

	return PLUGIN_CONTINUE;
}