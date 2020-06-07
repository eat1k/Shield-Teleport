/*
 * Authors: 
 * - Original SourceMod plugin by: Drumanid (https://dev-cs.ru/members/2742/)
 *
 * Official resource topic: https://dev-cs.ru/resources/635/
 */

#include <amxmodx>
#include <hamsandwich>
#include <reapi>

#pragma semicolon 1

public stock const PluginName[] = "Shield Teleport";
public stock const PluginVersion[] = "1.2.5";
public stock const PluginAuthor[] = "twisterniq";
public stock const PluginURL[] = "https://github.com/twisterniq/amxx-shield-teleport";
public stock const PluginDescription[] = "Gives protection to player after using a teleport. Moreover, player cannot do damage at this time";

/****************************************************************************************
****************************************************************************************/

#define is_user_valid(%0) (1 <= %0 <= MaxClients)

const TASK_ID_TIMESHIELD = 100;

new Float:g_flTime[MAX_PLAYERS + 1];

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

new g_eCvar[CVARS];

new g_iSyncHudMessage;

public plugin_init()
{
#if AMXX_VERSION_NUM == 190
	register_plugin(
		.plugin_name = PluginName,
		.version = PluginVersion,
		.author = PluginAuthor);
#endif

	register_dictionary("shield_teleport.txt");

	RegisterHookChain(RG_CBasePlayer_TraceAttack, "@OnPlayerTraceAttack_Pre", false);
	RegisterHam(Ham_Touch, "trigger_teleport", "@OnTouchTriggerTeleport_Post", true, true);

	g_iSyncHudMessage = CreateHudSyncObj();

	func_RegisterCvars();
}

func_RegisterCvars()
{
	bind_pcvar_float(create_cvar(
		.name = "shield_teleport_timer",
		.string = "3.0", 
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "SHIELD_TELEPORT_CVAR_TIMER"),
		.has_min = true,
		.min_val = 0.1), g_eCvar[CVAR_TIMER]);

	bind_pcvar_num(create_cvar(
		.name = "shield_teleport_glow",
		.string = "1",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "SHIELD_TELEPORT_CVAR_GLOW"),
		.has_min = true,
		.min_val = 0.0,
		.has_max = true,
		.max_val = 1.0), g_eCvar[CVAR_GLOW]);

	bind_pcvar_num(create_cvar(
		.name = "shield_teleport_time_block",
		.string = "10",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "SHIELD_TELEPORT_CVAR_TIME_BLOCK"),
		.has_min = true,
		.min_val = 0.0), g_eCvar[CVAR_TIMEBLOCK]);

	bind_pcvar_num(create_cvar(
		.name = "shield_teleport_team",
		.string = "1",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "SHIELD_TELEPORT_CVAR_TEAM"),
		.has_min = true,
		.min_val = 1.0,
		.has_max = true,
		.max_val = 3.0), g_eCvar[CVAR_TEAM]);

	bind_pcvar_num(create_cvar(
		.name = "shield_teleport_message",
		.string = "2",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "SHIELD_TELEPORT_CVAR_MESSAGE"),
		.has_min = true,
		.min_val = 0.0,
		.has_max = true,
		.max_val = 3.0), g_eCvar[CVAR_MESSAGE]);

	bind_pcvar_float(create_cvar(
		.name = "shield_message_hud_x",
		.string = "-1.0",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "SHIELD_TELEPORT_CVAR_HUD_X")), g_eCvar[CVAR_MESSAGE_HUD_X]);

	bind_pcvar_float(create_cvar(
		.name = "shield_message_hud_y",
		.string = "0.70",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "SHIELD_TELEPORT_CVAR_HUD_Y")), g_eCvar[CVAR_MESSAGE_HUD_Y]);

	bind_pcvar_float(create_cvar(
		.name = "shield_message_hud_time",
		.string = "3.0",
		.flags = FCVAR_NONE,
		.description = fmt("%L", LANG_SERVER, "SHIELD_TELEPORT_CVAR_HUD_TIME"),
		.has_min = true,
		.min_val = 0.1), g_eCvar[CVAR_MESSAGE_HUD_TIME]);

	AutoExecConfig(true, "shield_teleport");
}

public client_disconnected(id)
{
	remove_task(id+TASK_ID_TIMESHIELD);
}

@OnPlayerTraceAttack_Pre(const iVictim, iAttacker, Float:flDamage, Float:flVecDir[3], iTraceHandle, iBitsDamageType)
{
	#pragma unused flDamage, flVecDir, iTraceHandle, iBitsDamageType

	if (is_user_connected(iAttacker) && (task_exists(iVictim+TASK_ID_TIMESHIELD) || task_exists(iAttacker+TASK_ID_TIMESHIELD)))
	{
		return HC_SUPERCEDE;
	}

	return HC_CONTINUE;
}

@OnTouchTriggerTeleport_Post(const iEnt, const id)
{
	if (is_user_valid(id))
	{
		func_TeleportUse(id);
	}
}

func_TeleportUse(const id)
{
	if (g_eCvar[CVAR_TEAM] != 1 && (get_member(id, m_iTeam) != (g_eCvar[CVAR_TEAM] - 1)))
	{
		return;
	}

	new Float:flGameTime = get_gametime();

	if (g_flTime[id] > flGameTime)
	{
		func_ShowMessage(id, "%l", "SHIELD_TELEPORT_COOLDOWN", g_flTime[id] - flGameTime);
		return;
	}

	g_flTime[id] = flGameTime + g_eCvar[CVAR_TIMEBLOCK];
	func_ShowMessage(id, "%l", "SHIELD_TELEPORT_ENABLED", g_eCvar[CVAR_TIMER]);

	remove_task(id+TASK_ID_TIMESHIELD);
	set_task(g_eCvar[CVAR_TIMER], "@task_TimeShield", id+TASK_ID_TIMESHIELD);

	if (!g_eCvar[CVAR_GLOW])
	{
		return;
	}

	rg_set_user_rendering(id, kRenderFxGlowShell, 165.0, 42.0, 42.0, kRenderNormal, 255.0);
}

@task_TimeShield(id)
{
	id -= TASK_ID_TIMESHIELD;

	if (!is_user_alive(id))
	{
		remove_task(id+TASK_ID_TIMESHIELD);
		return;
	}

	if (g_eCvar[CVAR_GLOW])
	{
		rg_set_user_rendering(id);
	}

	remove_task(id+TASK_ID_TIMESHIELD);
	func_ShowMessage(id, "%l", "SHIELD_TELEPORT_DISABLED");
}

func_ShowMessage(const id, szMessage[], any:...)
{
	new szText[192];
	vformat(szText, charsmax(szText), szMessage, 3);

	enum { message_type_chat = 1, message_type_center, message_type_hud };

	switch(g_eCvar[CVAR_MESSAGE])
	{
		case message_type_chat:
		{
			client_print_color(id, print_team_default, szText);
		}
		case message_type_center:
		{
			client_print(id, print_center, szText);
		}
		case message_type_hud:
		{
			set_hudmessage(255, 255, 255, g_eCvar[CVAR_MESSAGE_HUD_X], g_eCvar[CVAR_MESSAGE_HUD_Y], 0, 0.5, g_eCvar[CVAR_MESSAGE_HUD_TIME], 0.5, 0.5);
			ShowSyncHudMsg(id, g_iSyncHudMessage, szText);
		}
	}
}

stock rg_set_user_rendering(id, iRenderFx = kRenderFxNone, Float:flRed = 255.0, Float:flGreen = 255.0, Float:flBlue = 255.0, iRender = kRenderNormal, Float:flAmount = 16.0)
{
	new Float:flRenderColor[3];
	flRenderColor[0] = flRed;
	flRenderColor[1] = flGreen;
	flRenderColor[2] = flBlue;

	set_entvar(id, var_renderfx, iRenderFx);
	set_entvar(id, var_rendercolor, flRenderColor);
	set_entvar(id, var_rendermode, iRender);
	set_entvar(id, var_renderamt, flAmount);
}