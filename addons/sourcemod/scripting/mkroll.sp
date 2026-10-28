#include <sourcemod>
#include <sdktools>

// Compiled with FoFLib
// https://github.com/fofscarfy/foflib
#include "foflib/usermsgs.inc"
#include "foflib/equipping.inc"

#define MKSOUND_DL "sound/mkroll/mkitemroulette_declipped_2sroll.mp3"
#define MKSOUND "mkroll/mkitemroulette_declipped_2sroll.mp3"

public Plugin myinfo =
{
    name = "Mario Kart Item Roulette",
    author = "Scarfy",
    description = "Test plugin to try to do a Mario Kart roulette",
    version = "0.1.0",
    url = "http://www.example.com"
};

static const float ROLL_INTERVAL = 0.1;
static const float ROLL_TIME = 2.0;
static const int VALID_WEAPONS[36] = 
{
    1, 2, 3, 4, 5,
    6, 7, 9, 11, 12,
    13, 14, 15, 16, 17,
    18, 19, 20, 21, 22,
    23, 24, 25, 26, 27,
    28, 29, 30, 31, 32,
    33, 34, 41, 42, 43,
    44
}

static const int VALID_MENU_WEAPONS[36] =
{
    19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 
    29, 30, 31, 33, 34, 35, 36, 37, 38, 39, 
    40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 
    50, 51, 52, 53, 54
}

static const char WEAPON_NAMES[55][32] =
{
    "", "", "", "", "",
    "", "", "", "", "",
    "", "", "", "", "",
    "", "", "", "", "",
    "", "", "", "", "",
    "", "", "", "weapon_knife", "",
    "weapon_deringer", "weapon_dynamite", "", "weapon_volcanic", "weapon_coltnavy",
    "weapon_axe", "weapon_bow", "weapon_sawedoff_shotgun", "weapon_hammerless", "weapon_remington_army",
    "weapon_maresleg", "weapon_schofield", "weapon_carbine", "weapon_peacemaker", "weapon_bow_black",
    "weapon_henryrifle", "weapon_coachgun", "weapon_spencer", "weapon_machete", "weapon_shotgun",
    "weapon_dynamite_black", "weapon_sharps", "weapon_walker", "weapon_dynamite_belt", "weapon_whiskey"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_mkroll", Command_MKRoll, "Rolls and equips your items.");
}

public void OnMapStart()
{
    AddFileToDownloadsTable(MKSOUND_DL);
    PrecacheSound(MKSOUND);
}

public Action Command_MKRoll(int client, int nArgs)
{
    DataPack dp = new DataPack();
    dp.WriteCell(EntIndexToEntRef(client));
    dp.WriteFloat(GetGameTime() + ROLL_TIME);
    Handle timer = CreateTimer(ROLL_INTERVAL, Timer_RouletteSpin, dp, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT | TIMER_DATA_HNDL_CLOSE);
    TriggerTimer(timer);
    // EmitSoundToClient(client, MKSOUND, -2, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
    EmitSoundToClient(client, MKSOUND);

    return Plugin_Handled;
}

public Action Timer_RouletteSpin(Handle timer, DataPack dp)
{
    dp.Reset();
    int client = EntRefToEntIndex(dp.ReadCell());
    float endTime = dp.ReadFloat();

    if (client == -1) return Plugin_Stop;

    int weapons[8];
    int numCopied = _Roulette(weapons, sizeof(weapons));
    FindConVar("fof_sv_currentmode").SetInt(5);
    _ShowRouletteMsgs(client, weapons, numCopied);
    FindConVar("fof_sv_currentmode").SetInt(1);

    if (GetGameTime() >= endTime)
    {
        RemoveWeaponsFromPlayer(client, false);
        _GivePlayerWeapons(EntIndexToEntRef(client), numCopied, weapons);
        // Take and give weapons
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

static void _GivePlayerWeapons(int entref, int size, int[] weapons)
{
    int client = EntRefToEntIndex(entref);
    if (client == -1) return;

    int playerInfo = GetEntProp(client, Prop_Send, "m_nPlayerInfo");
    playerInfo &= ~FOFLIB_PLAYERINFO_GUNTHROW;
    playerInfo &= ~FOFLIB_PLAYERINFO_JUMPMASTER;
    playerInfo &= ~FOFLIB_PLAYERINFO_SLIDE;
    playerInfo &= ~FOFLIB_PLAYERINFO_HEAVYLOADS;
    playerInfo &= ~FOFLIB_PLAYERINFO_BRASSKNUCKLES;
    playerInfo &= ~FOFLIB_PLAYERINFO_BOOTS;

    SetEntProp(client, Prop_Send, "m_nHandStance", Handedness_Right);

    for (int i = 0; i < size; i++)
    {
        LogMessage("Menu Item %d: %d", i + 1, weapons[i]);
        if (weapons[i] < 19 || weapons[i] > 54) continue;

        switch(weapons[i])
        {
            case 19, 20, 21, 22: SetEntProp(client, Prop_Send, "m_nHandStance", (weapons[i] - 18) % 4);
            case 23: playerInfo |= FOFLIB_PLAYERINFO_GUNTHROW;
            case 24: playerInfo |= FOFLIB_PLAYERINFO_JUMPMASTER;
            case 25: playerInfo |= FOFLIB_PLAYERINFO_SLIDE;
            case 26: playerInfo |= FOFLIB_PLAYERINFO_HEAVYLOADS;
            case 27: playerInfo |= FOFLIB_PLAYERINFO_BRASSKNUCKLES;
            case 29: playerInfo |= FOFLIB_PLAYERINFO_BOOTS;
            default: GivePlayerItem(client, WEAPON_NAMES[weapons[i]]);
        }
    }

    SetEntProp(client, Prop_Send, "m_nPlayerInfo", playerInfo);
    GivePlayerItem(client, "weapon_fists");
    FakeClientCommand(client, "use %s", "weapon_fists");
    // DataPack dp = new DataPack(); 
    // dp.WriteCell(EntIndexToEntRef(client)); 
    // dp.WriteCell(EntIndexToEntRef(GivePlayerItem(client, "weapon_fists")));
    // RequestFrame(_EquipFists, dp);
    // CreateTimer(1.0, _EquipWeapon, dp, TIMER_DATA_HNDL_CLOSE);
    // EquipPlayerWeapon(client, GivePlayerItem(client, "weapon_fists"));
}

static Action _EquipWeapon(Handle timer, DataPack dp)
{
    dp.Reset();
    int client = EntRefToEntIndex(dp.ReadCell());
    if (client == -1) return Plugin_Stop;

    int fists = EntRefToEntIndex(dp.ReadCell());
    if (fists == -1) return Plugin_Stop;

    char classname[64]; GetEntityClassname(fists, classname, sizeof(classname));

    LogMessage("Equipping %s!", classname);

    EquipPlayerWeapon(client, fists);

    return Plugin_Stop;
}

static void _ShowRouletteMsgs(int client, int[] weapons, int size)
{
    ShowMenuFoFMsg msg;
    msg.numPlayers = 1;
    msg.players[0] = client;
    msg.label = "";

    msg.SendClear();

    for (int i = 0; i < size && i < 5; i++)
    {
        msg.command = weapons[i];
        msg.final = i + 1 == size || i + 1 == 5;
        msg.Send();
    }
}

static int _Roulette(int[] weapons, int size)
{
    int tmp[36]; tmp = VALID_MENU_WEAPONS;
    _FisherYates(tmp, sizeof(tmp));
    
    bool handedness=false;
    int copied = 0;
    for (int i = 0; i < sizeof(tmp) && copied < 5 && copied < size; i++)
    {
        if (tmp[i] < 23)
        {
            if (handedness) continue;
            handedness = true;
        }

        weapons[copied] = tmp[i];
        copied++;
    }

    return copied;
}



static void _FisherYates(int[] arr, int size)
{
    int tmp, idx;
    for (int i = 0; i < size; i++)
    {
        idx = GetRandomInt(i, size - 1);
        tmp = arr[i];
        arr[i] = arr[idx];
        arr[idx] = tmp;
    }
}