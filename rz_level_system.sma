#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <rezp>

#define is_user_valid_connected(%1) (1 <= %1 <= 32 && g_isconnected[%1])
#define is_user_valid_alive(%1) (1 <= %1 <= 32 && g_isalive[%1])
#define is_user_valid(%1) (1 <= %1 <= 32)

#define MYSQL_SAVE	// MySQL сохранение
//#define NVAULT_SAVE // Nvault сохранение

#if defined MYSQL_SAVE
	#include <sqlx>
#endif

#if defined NVAULT_SAVE
	#include <nvault>
#endif

enum _:CvarData{
	#if defined MYSQL_SAVE
		SQL_HOST[256],
		SQL_USER[128],
		SQL_PASSWORD[256],
		SQL_DATABASE[128],
		SQL_TABLENAME[128],
	#endif

	EFFECT_HUD,
	EFFECT_SCREENFADE,

	NEED_DAMAGE,
	EXP_PER_DAMAGE,
	EXP_KILL_NEM,
	EXP_KILL_SURV,
	EXP_KILL_ZOMBIE,
	EXP_KILL_HUMAN,
	EXP_KILL_SNIPER,
	EXP_KILL_ASSASSIN
};

//Опыт для каждого уровня  1	2	3	4	  5		6	7	 8	  9	   10   11    12    13    14    15    16    17    18    19    20    21     22   23    24     25   26    27     28    29    30    31    32    33    34    35    36    37    38    39    40   41    42    43    44     45   46     47   48    49    50    51
new const iLevel_Exp[51] = { 1, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900, 2000, 2100, 2200, 2300, 2400, 2500, 2600, 2700, 2800, 2900, 3000, 3100, 3200, 3300, 3400, 3500, 3600, 3700, 3800, 3900, 4000, 4100, 4200, 4300, 4400, 4500, 4600, 4700, 4800, 4900, 5000 };
new const szPluginInfo[][] = { "[ReZP] Level System", "6.2", "Base Code: Dambas / Edit: ImmortalAmxx" };

new g_iLevel[51], g_iExp[51], g_szString[21], g_Exp[3][33], g_iGetUserExp, Float:g_flPlayerDamage[33], g_pCvarData[CvarData];
new g_iClass_Human, g_iClass_Zombie, g_iClass_Survivor, g_iClass_Nemesis, g_iClass_Sniper, g_iClass_Assassin;

#if defined NVAULT_SAVE
	new g_Vault, g_iNextExp[50];
#endif

#if defined MYSQL_SAVE
	new Handle:MYSQL_Tuple;
	new Handle:MYSQL_Connect;
	new g_szQuery[512]; 

	new bool: UserLoaded[33];
	new UserSteamID[33][34];
#endif

#if defined NVAULT_SAVE
	public client_connect(pPlayer) {
		if(is_user_bot(pPlayer))
			return;
		
		@LoadData(pPlayer);
	}
#endif

public client_putinserver(pPlayer) {
	if(is_user_bot(pPlayer))
		return;

	#if defined MYSQL_SAVE
		@LoadData(pPlayer);
	#endif

	set_task(3.0, "@Task_ChangeExpConnect", pPlayer);
}

public client_disconnected(pPlayer) {
	#if defined NVAULT_SAVE
		@SaveData(pPlayer);
	#endif
	
	#if defined MYSQL_SAVE
		if(!UserLoaded[pPlayer])
			return;
	
		formatex(g_szQuery, charsmax(g_szQuery), "UPDATE `%s` SET `Level` = '%d', `Experience` = '%d' WHERE `%s`.`SteamID` = '%s';", g_pCvarData[SQL_TABLENAME], g_iLevel[pPlayer], g_iExp[pPlayer], g_pCvarData[SQL_TABLENAME], UserSteamID[pPlayer]);
		SQL_ThreadQuery(MYSQL_Tuple, "SQL_Thread", g_szQuery);
	#endif
}

public plugin_init()
{
	register_plugin(
		.plugin_name = szPluginInfo[0],
		.version = szPluginInfo[1],
		.author = szPluginInfo[2]
	);

	g_iClass_Human = rz_class_find("human");
	g_iClass_Zombie = rz_class_find("zombie");
	g_iClass_Survivor = rz_class_find("survivor");
	g_iClass_Nemesis = rz_class_find("nemesis");
	g_iClass_Sniper = rz_class_find("sniper");
	g_iClass_Assassin = rz_class_find("assassin");

	@CreateCvar();
	@GameHook();

	#if defined NVAULT_SAVE
		g_Vault = nvault_open("zp_level_system");
	#endif
}

@CreateCvar() {
	#if defined MYSQL_SAVE
		bind_pcvar_string(
			create_cvar(
				.name = "rezp_lvl_sql_host",
				.string = "localhost",
				.description = "Хостинг от БД"
			), g_pCvarData[SQL_HOST], charsmax(g_pCvarData[SQL_HOST])
		);

		bind_pcvar_string(
			create_cvar(
				.name = "rezp_lvl_sql_user",
				.string = "root",
				.description = "Имя пользователя от БД"
			), g_pCvarData[SQL_USER], charsmax(g_pCvarData[SQL_USER])
		);

		bind_pcvar_string(
			create_cvar(
				.name = "rezp_lvl_sql_password",
				.string = "",
				.description = "Пароль от БД"
			), g_pCvarData[SQL_PASSWORD], charsmax(g_pCvarData[SQL_PASSWORD])
		);

		bind_pcvar_string(
			create_cvar(
				.name = "rezp_lvl_sql_dbname",
				.string = "sborka",
				.description = "Имя БД"
			), g_pCvarData[SQL_DATABASE], charsmax(g_pCvarData[SQL_DATABASE])
		);

		bind_pcvar_string(
			create_cvar(
				.name = "rezp_lvl_sql_tablename",
				.string = "rezp_lvlsystem",
				.description = "Название таблицы в БД."
			), g_pCvarData[SQL_TABLENAME], charsmax(g_pCvarData[SQL_TABLENAME])
		);
	#endif

	bind_pcvar_num(
		create_cvar(
			.name = "rezp_lvl_effect_hud",
			.string = "1",
			.description = "Показывать HUD при получении опыта? 0 - Нет, 1 - Да.",
			.has_min = true,
			.min_val = 0.0,
			.has_max = true,
			.max_val = 1.0
		), g_pCvarData[EFFECT_HUD]
	)

	bind_pcvar_num(
		create_cvar(
			.name = "rezp_lvl_effect_screenfade",
			.string = "1",
			.description = "Эффект ScreenFade при получении опыта (Затемнение экрана). 0 - Нет, 1 - Да.",
			.has_min = true,
			.min_val = 0.0,
			.has_max = true,
			.max_val = 1.0
		), g_pCvarData[EFFECT_SCREENFADE]
	)

	bind_pcvar_num(
		create_cvar(
			.name = "rezp_lvl_need_damage",
			.string = "500",
			.description = "Сколько урона нужно нанести, что бы получить опыт? 0 - Не выдавать опыт за урон.",
			.has_min = true,
			.min_val = 0.0
		), g_pCvarData[NEED_DAMAGE]
	);

	bind_pcvar_num(
		create_cvar(
			.name = "rezp_lvl_exp_damage",
			.string = "1",
			.description = "Сколько опыта давать за нанесённый урон?"
		), g_pCvarData[EXP_PER_DAMAGE]
	);

	bind_pcvar_num(
		create_cvar(
			.name = "rezp_lvl_exp_kill_nemesis",
			.string = "20",
			.description = "Сколько опыта выдавать за убийство немезиды? 0 - Не выдавать опыт.",
			.has_min = true,
			.min_val = 0.0
		), g_pCvarData[EXP_KILL_NEM]
	);

	bind_pcvar_num(
		create_cvar(
			.name = "rezp_lvl_exp_kill_survivor",
			.string = "15",
			.description = "Сколько опыта выдавать за убийство выжившего? 0 - Не выдавать опыт.",
			.has_min = true,
			.min_val = 0.0
		), g_pCvarData[EXP_KILL_SURV]
	);

	bind_pcvar_num(
		create_cvar(
			.name = "rezp_lvl_exp_kill_zombie",
			.string = "1",
			.description = "Сколько опыта выдавать за убийство зомби? 0 - Не выдавать опыт.",
			.has_min = true,
			.min_val = 0.0
		), g_pCvarData[EXP_KILL_ZOMBIE]
	);

	bind_pcvar_num(
		create_cvar(
			.name = "rezp_lvl_exp_kill_human",
			.string = "1",
			.description = "Сколько опыта выдавать за убийство человека? 0 - Не выдавать опыт.",
			.has_min = true,
			.min_val = 0.0
		), g_pCvarData[EXP_KILL_HUMAN]
	);

	bind_pcvar_num(
		create_cvar(
			.name = "rezp_lvl_exp_kill_sniper",
			.string = "15",
			.description = "Сколько опыта выдавать за убийство снайпера? 0 - Не выдавать опыт.",
			.has_min = true,
			.min_val = 0.0
		), g_pCvarData[EXP_KILL_SNIPER]
	);

	bind_pcvar_num(
		create_cvar(
			.name = "rezp_lvl_exp_kill_assassin",
			.string = "20",
			.description = "Сколько опыта выдавать за убийство ассассина? 0 - Не выдавать опыт.",
			.has_min = true,
			.min_val = 0.0
		), g_pCvarData[EXP_KILL_ASSASSIN]
	);

	AutoExecConfig(.autoCreate = true, .name = "Rezp_LevelSystem");
}

@GameHook() {
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "@CBasePlayer_TakeDamage_Pre", .post = false);
	RegisterHookChain(RG_CBasePlayer_Killed, "@CBasePlayer_Killed_Post", .post = true);
}

public plugin_natives() {
	register_native("rz_get_user_level", "@Native_GetUserLevel");
	register_native("rz_get_user_exp", "@Native_GetUserExp");
	register_native("rz_get_user_next_exp", "@Native_GetUserNextExp");
	
	register_native("rz_set_user_level", "@Native_SetUserLevel");
	register_native("rz_set_user_exp", "@Native_SetUserExp");
}

#if defined MYSQL_SAVE
	public plugin_cfg() SQL_LoadDebug();
#endif

public plugin_end() {
	#if defined MYSQL_SAVE
		if(MYSQL_Tuple) 
			SQL_FreeHandle(MYSQL_Tuple);
		
		if(MYSQL_Connect) 
			SQL_FreeHandle(MYSQL_Connect);
	#endif
}

#if defined MYSQL_SAVE
	public SQL_LoadDebug() {
		new szError[512], iErrorCode;
		
		MYSQL_Tuple = SQL_MakeDbTuple(g_pCvarData[SQL_HOST], g_pCvarData[SQL_USER], g_pCvarData[SQL_PASSWORD], g_pCvarData[SQL_DATABASE]);
		MYSQL_Connect = SQL_Connect(MYSQL_Tuple, iErrorCode, szError, charsmax(szError));
		
		if(MYSQL_Connect == Empty_Handle)
			set_fail_state(szError);
		
		if(!SQL_TableExists(MYSQL_Connect, g_pCvarData[SQL_TABLENAME])) {
			new Handle:hQueries, szQuery[512];
			
			formatex( szQuery, charsmax(szQuery), "CREATE TABLE IF NOT EXISTS `%s` (SteamID VARCHAR(32) CHARACTER SET cp1250 COLLATE cp1250_general_ci NOT NULL, Level INT NOT NULL, Experience INT NOT NULL, PRIMARY KEY (SteamID))", g_pCvarData[SQL_TABLENAME]);
			hQueries = SQL_PrepareQuery(MYSQL_Connect, szQuery);
			
			if(!SQL_Execute(hQueries)) {
				SQL_QueryError(hQueries, szError, charsmax(szError));
				set_fail_state(szError);
			}

			SQL_FreeHandle(hQueries);
		}

		SQL_QueryAndIgnore(MYSQL_Connect, "SET NAMES utf8");
	}

	public SQL_Query( iState, Handle: hQuery, szError[], iErrorCode, iParams[], iParamsSize) {
		switch(iState) {
			case TQUERY_CONNECT_FAILED: log_amx("Load - Could not connect to SQL database. [%d] %s", iErrorCode, szError);
			case TQUERY_QUERY_FAILED: log_amx("Load Query failed. [%d] %s", iErrorCode, szError);
		}
		
		new id = iParams[0]
		UserLoaded[id] = true
		
		if(SQL_NumResults(hQuery) < 1) {
			if(equal(UserSteamID[id], "ID_PENDING"))
				return PLUGIN_HANDLED;

			formatex(g_szQuery, charsmax(g_szQuery), "INSERT INTO `%s` (`SteamID`, `Level`, `Experience`) VALUES ('%s', '%d', '%d');", g_pCvarData[SQL_TABLENAME], UserSteamID[id], g_iLevel[id], g_iExp[id]);
			SQL_ThreadQuery(MYSQL_Tuple, "SQL_Thread", g_szQuery);
			
			return PLUGIN_HANDLED;
		}
		else {
			g_iLevel[id] = SQL_ReadResult(hQuery, 1);
			g_iExp[id] = SQL_ReadResult(hQuery, 2);
		}
		
		return PLUGIN_HANDLED;
	}

	@LoadData(pPlayer) {
		if(!is_user_connected(pPlayer))
			return;
		
		new iParams[1]; iParams[0] = pPlayer;
		
		get_user_authid(pPlayer, UserSteamID[pPlayer], charsmax(UserSteamID[]));
		
		formatex(g_szQuery, charsmax(g_szQuery), "SELECT * FROM `%s` WHERE (`%s`.`SteamID` = '%s')", g_pCvarData[SQL_TABLENAME], g_pCvarData[SQL_TABLENAME], UserSteamID[pPlayer]);
		SQL_ThreadQuery(MYSQL_Tuple, "SQL_Query", g_szQuery, iParams, sizeof iParams);
	}

	public SQL_Thread(iState, Handle: hQuery, szError[], iErrorCode, iParams[], iParamsSize) {
		if(iState == 0)
			return;
		
		log_amx("SQL Error: %d (%s)", iErrorCode, szError);
	}
#endif

#if defined NVAULT_SAVE
	@SaveData(pPlayer) {
		new szAuthID[35];
		get_user_authid(pPlayer, szAuthID, charsmax(szAuthID));
	
		new iVaultKey[64], iVaultData[256];
		format(iVaultKey, 63, "%s", szAuthID);
		format(iVaultData, 255, "%i#%i#%i#", g_iExp[pPlayer], g_iLevel[pPlayer], g_iNextExp[pPlayer]);
		nvault_set(g_Vault, iVaultKey, iVaultData);
		
		return PLUGIN_CONTINUE;
	}

	@LoadData(pPlayer) {
		new szAuthID[35]
		get_user_authid(pPlayer, szAuthID, charsmax(szAuthID));
	
		new iVaultKey[64], iVaultData[256];
		format(iVaultKey, 63, "%s", szAuthID);
		format(iVaultData, 255, "%i#%i#%i#", g_iExp[pPlayer], g_iLevel[pPlayer], g_iNextExp[pPlayer]);
		nvault_get(g_Vault, iVaultKey, iVaultData, 255);
	
		replace_all(iVaultData, 255, "#", " ");
	
		new iPlayerExp[32], iPlayerLevel[32], iPlayerNextExp[32];
	
		parse(iVaultData, iPlayerExp, 31, iPlayerLevel, 31);
	
		g_iExp[pPlayer] = str_to_num(iPlayerExp);
		g_iLevel[pPlayer] = str_to_num(iPlayerLevel);
		g_iNextExp[pPlayer] = str_to_num(iPlayerNextExp);
	
		return PLUGIN_CONTINUE;
	}
#endif

@Task_ChangeExpConnect(pPlayer) {
	g_iGetUserExp = g_iExp[pPlayer];
	
	g_Exp[0][pPlayer] = g_iGetUserExp;
	g_Exp[1][pPlayer] = g_iGetUserExp;
	g_Exp[2][pPlayer] = g_iGetUserExp;
	
	if(g_pCvarData[EFFECT_HUD])
		set_task(1.0, "@Task_ChangeExp", pPlayer);
}

@Task_ChangeExp(pPlayer) {
	if(get_member(pPlayer, m_iTeam) == TEAM_SPECTATOR || !is_user_connected(pPlayer))
		return PLUGIN_HANDLED;

	g_Exp[1][pPlayer] = g_iExp[pPlayer];
	
	if(g_Exp[1][pPlayer] != g_Exp[2][pPlayer]) {
		if(g_Exp[1][pPlayer] > g_Exp[2][pPlayer]) {
			g_iGetUserExp = g_Exp[1][pPlayer] - g_Exp[2][pPlayer];
			format(g_szString, charsmax(g_szString), "[+%d Опыт(а)]", g_iGetUserExp);
		}
		
		g_Exp[2][pPlayer] = g_Exp[1][pPlayer];
		
		set_hudmessage(255, 15, 247, 0.57, 0.57, 0, 6.0, 3.0, 0.1, 0.2, -1);
		show_hudmessage(pPlayer, "%s", g_szString);
	}

	return PLUGIN_HANDLED;
}

@CBasePlayer_TakeDamage_Pre(pVictim, inflictor, pAttacker, Float:flDamage) { 
	if(!is_user_connected(pAttacker))
		return;
	
	if(get_member(pAttacker, m_iTeam) == get_member(pVictim, m_iTeam))
		return;
	
	if(g_iLevel[pAttacker] > iLevel_Exp[pAttacker])
		return;

	g_flPlayerDamage[pAttacker] += flDamage;
	
	if(g_flPlayerDamage[pAttacker] >= float(g_pCvarData[NEED_DAMAGE])) {
		g_iExp[pAttacker] += g_pCvarData[EXP_PER_DAMAGE];

		@Task_ChangeExp(pAttacker);

		g_flPlayerDamage[pAttacker] = 0.0;
	}

	@CheckLevel(pAttacker);
}

@CBasePlayer_Killed_Post(pVictim, pKiller) {
	if(!is_user_alive(pKiller))
		return;	

	if(g_iLevel[pKiller] > iLevel_Exp[pKiller])
		return;	

	if(rz_class_player_get(pVictim) == g_iClass_Zombie)
		g_iExp[pKiller] += g_pCvarData[EXP_KILL_ZOMBIE]

	else if(rz_class_player_get(pVictim) == g_iClass_Nemesis)
		g_iExp[pKiller] += g_pCvarData[EXP_KILL_NEM];

	else if(rz_class_player_get(pVictim) == g_iClass_Survivor)
		g_iExp[pKiller] += g_pCvarData[EXP_KILL_SURV];

	else if(rz_class_player_get(pVictim) == g_iClass_Human)
		g_iExp[pKiller] += g_pCvarData[EXP_KILL_HUMAN];

	else if(rz_class_player_get(pVictim) == g_iClass_Sniper)
		g_iExp[pKiller] += g_pCvarData[EXP_KILL_SNIPER];

	else if(rz_class_player_get(pVictim) == g_iClass_Assassin)
		g_iExp[pKiller] += g_pCvarData[EXP_KILL_ASSASSIN];

	@CheckLevel(pKiller);
}

@CheckLevel(pPlayer) {
	if(!is_user_connected(pPlayer))
		return PLUGIN_HANDLED;
	
	new MAX_LVL = sizeof iLevel_Exp - 1;
	
	if(g_iExp[pPlayer] > iLevel_Exp[MAX_LVL] - 1)
		return PLUGIN_HANDLED;
	
	if(g_iExp[pPlayer] >= iLevel_Exp[g_iLevel[pPlayer]]) {
		if(g_iLevel[pPlayer] < MAX_LVL )
		{
			g_iLevel[pPlayer]++;

			if(g_pCvarData[EFFECT_SCREENFADE]) {
				message_begin(MSG_ONE, get_user_msgid("ScreenFade"), {0, 0, 0}, pPlayer);
				write_short(1 << 11);
				write_short(1 << 11);
				write_short(0x0001);
				write_byte(255);
				write_byte(255);
				write_byte(0);
				write_byte(110);
				message_end();
			}

			client_print_color(pPlayer, print_team_default, "^1[^4Уровни^1] ^1Вы достигли^4 %d ^1уровня.", g_iLevel[pPlayer]);
			g_iExp[pPlayer] = 0;
		}
	}
	
	return PLUGIN_HANDLED;
}

@Native_GetUserLevel(iPlugin, iParam) {
	new pPlayer = get_param(1);

	return g_iLevel[pPlayer];
}

@Native_GetUserExp(iPlugin, iParam) {
	new pPlayer = get_param(1);
	
	return g_iExp[pPlayer];
}

@Native_GetUserNextExp(iPlugin, iParam) {
	new pPlayer = get_param(1);

	return iLevel_Exp[g_iLevel[pPlayer]];
}

@Native_SetUserLevel(iPlugin, iParam) {
	enum { argPlayer = 1, argAmount };
	
	new pPlayer = get_param(argPlayer);
	new iAmount = get_param(argAmount);
	
	if(!is_user_valid(pPlayer))
		return;
	
	g_iLevel[pPlayer] = iAmount;

	@CheckLevel(pPlayer);
}

@Native_SetUserExp(iPlugin, iParam) {
	enum { argPlayer = 1, argAmount };
	
	new pPlayer = get_param(argPlayer);
	new iAmount = get_param(argAmount);
	
	if(!is_user_valid(pPlayer))
		return;
	
	g_iExp[pPlayer] = iAmount;

	@CheckLevel(pPlayer);
}

#if defined MYSQL_SAVE
	stock bool: SQL_TableExists(Handle: hDataBase, const szTable[]) {
		new Handle: hQuery = SQL_PrepareQuery(hDataBase, "SELECT * FROM information_schema.tables WHERE table_name = '%s' LIMIT 1;", szTable);
		new szError[512];
		
		if(!SQL_Execute(hQuery)) {
			SQL_QueryError(hQuery, szError, charsmax(szError));
			set_fail_state(szError);
		}
		else if( !SQL_NumResults(hQuery)) {
			SQL_FreeHandle(hQuery);
			return false;
		}

		SQL_FreeHandle(hQuery);
		return true;
	}
#endif