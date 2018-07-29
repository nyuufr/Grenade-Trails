
/* ========================================================================= */
/* PRAGMAS                                                                   */
/* ========================================================================= */

#pragma semicolon 1
#pragma newdecls  required

/* ========================================================================= */
/* INCLUDES                                                                  */
/* ========================================================================= */

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

/* ========================================================================= */
/* DEFINES                                                                   */
/* ========================================================================= */

/* Plugin version                                                            */
#define C_PLUGIN_VERSION                "1.3.0"

/* ------------------------------------------------------------------------- */

/* High explosive grenade type                                               */
#define C_GRENADE_TYPE_HE               (0)
/* Flashbang grenade type                                                    */
#define C_GRENADE_TYPE_FLASHBANG        (1)
/* Smoke grenade type                                                        */
#define C_GRENADE_TYPE_SMOKE            (2)
/* Decoy grenade type                                                        */
#define C_GRENADE_TYPE_DECOY            (3)
/* Tactical awareness grenade type                                           */
#define C_GRENADE_TYPE_TA               (4)
/* Incendiary (+ molotov) grenade type                                       */
#define C_GRENADE_TYPE_INCENDIARY       (5)
/* Maximum grenade type                                                      */
#define C_GRENADE_TYPE_MAXIMUM          (6)

/* ========================================================================= */
/* GLOBAL VARIABLES                                                          */
/* ========================================================================= */

/* Plugin information                                                        */
public Plugin myinfo =
{
    name        = "Grenade Trails",
    author      = "Nyuu",
    description = "Create colored trails following the grenades",
    version     = C_PLUGIN_VERSION,
    url         = ""
};

/* ------------------------------------------------------------------------- */

/* Plugin late                                                               */
bool      gl_bPluginLate;

/* Clients in game                                                           */
bool      gl_bClientInGame[MAXPLAYERS + 1];

/* Beam sprite                                                               */
int       gl_nSpriteBeam;
/* Halo sprite                                                               */
int       gl_nSpriteHalo;

/* Grenade projectile name stringmap                                         */
StringMap gl_hMapGrenadeProjectileName;

/* ------------------------------------------------------------------------- */

/* Plugin enable cvar                                                        */
ConVar    gl_hCvarPluginEnable;
/* Color of the self trails cvar                                             */
ConVar    gl_hCvarTrailsSelfColor;
/* Color of the teammate trails cvar                                         */
ConVar    gl_hCvarTrailsTeammateColor;
/* Color of the enemy trails cvar                                            */
ConVar    gl_hCvarTrailsEnemyColor;
/* Alpha of the trails cvar                                                  */
ConVar    gl_hCvarTrailsAlpha;
/* Life of the trails cvar                                                   */
ConVar    gl_hCvarTrailsLife;
/* Start width of the trails cvar                                            */
ConVar    gl_hCvarTrailsStartWidth;
/* End width of the trails cvar                                              */
ConVar    gl_hCvarTrailsEndWidth;
/* Amplitude of the trails cvar                                              */
ConVar    gl_hCvarTrailsAmplitude;
/* Fade length of the trails cvar                                            */
ConVar    gl_hCvarTrailsFadeLength;

/* Plugin enable                                                             */
bool      gl_bPluginEnable;
/* Color of the self trails                                                  */
int       gl_iTrailsSelfColor;
/* Color of the teammate trails                                              */
int       gl_iTrailsTeammateColor;
/* Color of the enemy trails                                                 */
int       gl_iTrailsEnemyColor;
/* Alpha of the trails                                                       */
int       gl_iTrailsAlpha;
/* Life of the trails                                                        */
float     gl_flTrailsLife;
/* Start width of the trails                                                 */
float     gl_flTrailsStartWidth;
/* End width of the trails                                                   */
float     gl_flTrailsEndWidth;
/* Amplitude of the trails                                                   */
float     gl_flTrailsAmplitude;
/* Fade length of the trails                                                 */
int       gl_iTrailsFadeLength;

/* ========================================================================= */
/* FUNCTIONS                                                                 */
/* ========================================================================= */

/* ------------------------------------------------------------------------- */
/* Plugin                                                                    */
/* ------------------------------------------------------------------------- */

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] szError, int iErrorMaxLength)
{
    // Save the plugin late status
    gl_bPluginLate = bLate;
    
    // Continue
    return APLRes_Success;
}

public void OnPluginStart()
{
    // Check the engine version
    PluginCheckEngineVersion();
    
    // Initialize the cvars
    CvarInitialize();
    
    // Prepare the grenade projectile name stringmap
    gl_hMapGrenadeProjectileName = new StringMap();
    gl_hMapGrenadeProjectileName.SetValue("hegrenade_projectile",    C_GRENADE_TYPE_HE);
    gl_hMapGrenadeProjectileName.SetValue("flashbang_projectile",    C_GRENADE_TYPE_FLASHBANG);
    gl_hMapGrenadeProjectileName.SetValue("smokegrenade_projectile", C_GRENADE_TYPE_SMOKE);
    gl_hMapGrenadeProjectileName.SetValue("decoy_projectile",        C_GRENADE_TYPE_DECOY);
    gl_hMapGrenadeProjectileName.SetValue("tagrenade_projectile",    C_GRENADE_TYPE_TA);
    gl_hMapGrenadeProjectileName.SetValue("molotov_projectile",      C_GRENADE_TYPE_INCENDIARY);
    
    // Check the plugin late status
    PluginCheckLate();
}

void PluginCheckEngineVersion()
{
    // Check the engine version
    if (GetEngineVersion() != Engine_CSGO)
    {
        // Stop the plugin
        SetFailState("This plugin is for CS:GO only !");
    }
}

void PluginCheckLate()
{
    // Check if the plugin loads late
    if (gl_bPluginLate)
    {
        // Process the clients already on the server
        for (int iClient = 1 ; iClient <= MaxClients ; iClient++)
        {
            // Check if the client is connected
            if (IsClientConnected(iClient))
            {
                // Call the client connected forward
                OnClientConnected(iClient);
                
                // Check if the client is in game
                if (IsClientInGame(iClient))
                {
                    // Call the client put in server forward
                    OnClientPutInServer(iClient);
                }
            }
        }
    }
}

/* ------------------------------------------------------------------------- */
/* Map                                                                       */
/* ------------------------------------------------------------------------- */

public void OnMapStart()
{
    // Precache the sprites
    gl_nSpriteBeam = PrecacheModel("materials/sprites/physbeam.vmt");
    gl_nSpriteHalo = PrecacheModel("materials/sprites/glow4.vmt");
}

/* ------------------------------------------------------------------------- */
/* Console variable                                                          */
/* ------------------------------------------------------------------------- */

void CvarInitialize()
{
    // Create the version cvar
    CreateConVar("sm_grenade_trails_version", C_PLUGIN_VERSION, "Display the plugin version", FCVAR_DONTRECORD | FCVAR_NOTIFY | FCVAR_REPLICATED | FCVAR_SPONLY);
    
    // Create the custom cvars
    gl_hCvarPluginEnable        = CreateConVar("sm_grenade_trails_enable",         "1",        "Enable the plugin",                    _, true, 0.0, true, 1.0);   
    gl_hCvarTrailsSelfColor     = CreateConVar("sm_grenade_trails_self_color",     "0x0000FF", "Set the color of the self trails",     _, true, 0.0);
    gl_hCvarTrailsTeammateColor = CreateConVar("sm_grenade_trails_teammate_color", "0x0000FF", "Set the color of the teammate trails", _, true, 0.0);
    gl_hCvarTrailsEnemyColor    = CreateConVar("sm_grenade_trails_enemy_color",    "0xFF0000", "Set the color of the enemy trails",    _, true, 0.0);
    gl_hCvarTrailsAlpha         = CreateConVar("sm_grenade_trails_alpha",          "255",      "Set the alpha of the trails",          _, true, 0.0, true, 255.0);
    gl_hCvarTrailsLife          = CreateConVar("sm_grenade_trails_life",           "1.0",      "Set the life of the trails",           _, true, 0.1);
    gl_hCvarTrailsStartWidth    = CreateConVar("sm_grenade_trails_start_width",    "4.0",      "Set the start width of the trails",    _, true, 0.0);
    gl_hCvarTrailsEndWidth      = CreateConVar("sm_grenade_trails_end_width",      "4.0",      "Set the end width of the trails",      _, true, 0.0);
    gl_hCvarTrailsAmplitude     = CreateConVar("sm_grenade_trails_amplitude",      "0.0",      "Set the amplitude of the trails",      _, true, 0.0);
    gl_hCvarTrailsFadeLength    = CreateConVar("sm_grenade_trails_fade_length",    "1",        "Set the fade length of the trails",    _, true, 0.0);

    // Cache the custom cvars values
    gl_bPluginEnable        = gl_hCvarPluginEnable.BoolValue;
    gl_iTrailsSelfColor     = gl_hCvarTrailsSelfColor.IntValue;
    gl_iTrailsTeammateColor = gl_hCvarTrailsTeammateColor.IntValue;
    gl_iTrailsEnemyColor    = gl_hCvarTrailsEnemyColor.IntValue;
    gl_iTrailsAlpha         = gl_hCvarTrailsAlpha.IntValue;
    gl_flTrailsLife         = gl_hCvarTrailsLife.FloatValue;
    gl_flTrailsStartWidth   = gl_hCvarTrailsStartWidth.FloatValue;
    gl_flTrailsEndWidth     = gl_hCvarTrailsEndWidth.FloatValue;
    gl_flTrailsAmplitude    = gl_hCvarTrailsAmplitude.FloatValue;
    gl_iTrailsFadeLength    = gl_hCvarTrailsFadeLength.IntValue;
    
    // Hook the custom cvars change
    gl_hCvarPluginEnable.AddChangeHook(OnCvarChanged);
    gl_hCvarTrailsSelfColor.AddChangeHook(OnCvarChanged);
    gl_hCvarTrailsTeammateColor.AddChangeHook(OnCvarChanged);
    gl_hCvarTrailsEnemyColor.AddChangeHook(OnCvarChanged);
    gl_hCvarTrailsAlpha.AddChangeHook(OnCvarChanged);
    gl_hCvarTrailsLife.AddChangeHook(OnCvarChanged);
    gl_hCvarTrailsStartWidth.AddChangeHook(OnCvarChanged);
    gl_hCvarTrailsEndWidth.AddChangeHook(OnCvarChanged);
    gl_hCvarTrailsAmplitude.AddChangeHook(OnCvarChanged);
    gl_hCvarTrailsFadeLength.AddChangeHook(OnCvarChanged);
}

public void OnCvarChanged(ConVar hCvar, const char[] szOldValue, const char[] szNewValue)
{
    // Cache the custom cvars values
    if      (gl_hCvarPluginEnable        == hCvar) gl_bPluginEnable        = gl_hCvarPluginEnable.BoolValue;
    else if (gl_hCvarTrailsSelfColor     == hCvar) gl_iTrailsSelfColor     = gl_hCvarTrailsSelfColor.IntValue;
    else if (gl_hCvarTrailsTeammateColor == hCvar) gl_iTrailsTeammateColor = gl_hCvarTrailsTeammateColor.IntValue;
    else if (gl_hCvarTrailsEnemyColor    == hCvar) gl_iTrailsEnemyColor    = gl_hCvarTrailsEnemyColor.IntValue;
    else if (gl_hCvarTrailsAlpha         == hCvar) gl_iTrailsAlpha         = gl_hCvarTrailsAlpha.IntValue;
    else if (gl_hCvarTrailsLife          == hCvar) gl_flTrailsLife         = gl_hCvarTrailsLife.FloatValue;
    else if (gl_hCvarTrailsStartWidth    == hCvar) gl_flTrailsStartWidth   = gl_hCvarTrailsStartWidth.FloatValue;
    else if (gl_hCvarTrailsEndWidth      == hCvar) gl_flTrailsEndWidth     = gl_hCvarTrailsEndWidth.FloatValue;
    else if (gl_hCvarTrailsAmplitude     == hCvar) gl_flTrailsAmplitude    = gl_hCvarTrailsAmplitude.FloatValue;
    else if (gl_hCvarTrailsFadeLength    == hCvar) gl_iTrailsFadeLength    = gl_hCvarTrailsFadeLength.IntValue;
}

/* ------------------------------------------------------------------------- */
/* Client                                                                    */
/* ------------------------------------------------------------------------- */

public void OnClientConnected(int iClient)
{
    // Set the client as not in game
    gl_bClientInGame[iClient] = false;
}

public void OnClientPutInServer(int iClient)
{
    // Set the client as in game
    gl_bClientInGame[iClient] = true;
}

public void OnClientDisconnect(int iClient)
{
    // Set the client as not in game
    gl_bClientInGame[iClient] = false;
}

/* ------------------------------------------------------------------------- */
/* Player                                                                    */
/* ------------------------------------------------------------------------- */

int PlayerGetTrailColor(int iPlayer, int iTrailOwner, int iTrailTeam)
{
    // Check if the player sees his own trail
    if (iPlayer == iTrailOwner)
    {
        return gl_iTrailsSelfColor;
    }
    
    // Check if the player sees the trail of a teammate
    if (GetClientTeam(iPlayer) == iTrailTeam)
    {
        return gl_iTrailsTeammateColor;
    }
    
    // The player sees the trail of an enemy
    return gl_iTrailsEnemyColor;
}

/* ------------------------------------------------------------------------- */
/* Entity                                                                    */
/* ------------------------------------------------------------------------- */

public void OnEntityCreated(int iEntity, const char[] szClassname)
{
    static int iGrenadeType;
    
    // Check if the plugin is enabled
    if (gl_bPluginEnable)
    {
        // Check if the entity created is a grenade projectile
        if (gl_hMapGrenadeProjectileName.GetValue(szClassname, iGrenadeType))
        {
            // Hook the grenade spawn function
            SDKHook(iEntity, SDKHook_SpawnPost, OnGrenadeSpawnPost);
        }
    }
}

/* ------------------------------------------------------------------------- */
/* Grenade                                                                   */
/* ------------------------------------------------------------------------- */

public void OnGrenadeSpawnPost(int iGrenade)
{
    // Request the next frame
    RequestFrame(OnGrenadeSpawnPostNextFrame, EntIndexToEntRef(iGrenade));
}

public void OnGrenadeSpawnPostNextFrame(int iGrenadeReference)
{
    // Get the grenade index
    int iGrenade = EntRefToEntIndex(iGrenadeReference);
    
    // Check if the grenade is still valid
    if (iGrenade != INVALID_ENT_REFERENCE)
    {
        // Get the grenade owner
        int iGrenadeOwner = GetEntPropEnt(iGrenade, Prop_Send, "m_hOwnerEntity");
        
        // Check if the owner is in game
        if (1 <= iGrenadeOwner <= MaxClients && gl_bClientInGame[iGrenadeOwner])
        {
            // Create the trail
            GrenadeCreateTrail(iGrenade, iGrenadeOwner);
        }
    }
}

void GrenadeCreateTrail(int iGrenade, int iGrenadeOwner)
{
    int iColor;
    
    // Get the grenade team
    int iGrenadeTeam = GetClientTeam(iGrenadeOwner);
    
    // Send the trail to all the players in game
    for (int iPlayer = 1 ; iPlayer <= MaxClients ; iPlayer++)
    {
        // Check if the player is in game
        if (gl_bClientInGame[iPlayer])
        {
            // Get the trail color
            iColor = PlayerGetTrailColor(iPlayer, iGrenadeOwner, iGrenadeTeam);
            
            // Prepare the trail
            TE_Start          ("BeamFollow");
            TE_WriteEncodedEnt("m_iEntIndex",   iGrenade);
            TE_WriteNum       ("m_nModelIndex", gl_nSpriteBeam);
            TE_WriteNum       ("m_nHaloIndex",  gl_nSpriteHalo);
            TE_WriteNum       ("m_nStartFrame", 0);
            TE_WriteNum       ("m_nFrameRate",  16);
            TE_WriteFloat     ("m_fLife",       gl_flTrailsLife);
            TE_WriteFloat     ("m_fWidth",      gl_flTrailsStartWidth);
            TE_WriteFloat     ("m_fEndWidth",   gl_flTrailsEndWidth);
            TE_WriteFloat     ("m_fAmplitude",  gl_flTrailsAmplitude);
            TE_WriteNum       ("m_nFadeLength", gl_iTrailsFadeLength);
            TE_WriteNum       ("r",             (iColor >> 16) & 0xFF);
            TE_WriteNum       ("g",             (iColor >>  8) & 0xFF);
            TE_WriteNum       ("b",             (iColor      ) & 0xFF);
            TE_WriteNum       ("a",             gl_iTrailsAlpha);
            TE_WriteNum       ("m_nSpeed",      0);
            TE_WriteNum       ("m_nFlags",      0);
            
            // Send the trail to the player
            TE_SendToClient(iPlayer);
        }
    }
}

/* ========================================================================= */
