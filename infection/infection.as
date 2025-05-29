/*
Copyright (C) 2009-2010 Chasseur de bots

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
*/


Cvar allowEvenTeams( "g_teams_allow_uneven", "1", 0 );
Cvar scoreLimit( "g_scorelimit", "10", 0);

Cvar roundTimeLimit( "g_infection_roundtime", "120", 0);
Cvar startPercent( "g_infection_startPercent", "20", 0);
Cvar zombieHealth( "g_infection_zombiehealth", "150", 0);
Cvar spawnWithMG( "g_infection_spawnWithMG", "0", 0);

Cvar infectionDebug( "g_infection_debug", "0", 0);


Cvar g_disable_vote_shuffle( "g_disable_vote_shuffle", "0", 0);
Cvar g_disable_vote_rebalance( "g_disable_vote_rebalance", "0", 0);
Cvar g_disable_opcall_shuffle( "g_disable_opcall_shuffle", "0", 0);
Cvar g_disable_opcall_rebalance( "g_disable_opcall_rebalance", "0", 0);
Cvar g_teams_allow_uneven( "g_teams_allow_uneven", "0", 0);
Cvar g_instajump( "g_instajump", "1", 0);
// Cvar caMode( "g_infection_caMode", "0", 0);
// Cvar g_noclass_inventory( "g_noclass_inventory", "gb mg rg gl rl pg lg eb cells shells grens rockets plasma lasers bullets", 0 );
// Cvar g_class_strong_ammo( "g_class_strong_ammo", "1 75 20 20 40 125 180 15", 0 ); // GB MG RG GL RL PG LG EB

// Cvar selfdmg( "g_allow_selfdamage", "1", 0 );
// Cvar falldmg( "g_allow_falldamage", "1", 0 );

const int PICKUP_AMMO_GUNBLADE = 1;
const int PICKUP_AMMO_BULLETS = 25;
const int PICKUP_AMMO_SHELLS = 5;
const int PICKUP_AMMO_GRENADES = 5;
const int PICKUP_AMMO_ROCKETS = 3;
const int PICKUP_AMMO_PLASMA = 35;
const int PICKUP_AMMO_LASERS = 50;
const int PICKUP_AMMO_BOLTS = 3;
const int PICKUP_AMMO_INSTAS = 1;

bool finalSurvivorAcknowledged = false;

bool roundIsBeingPlayed = false;

bool fallbackDisabled = false;

// Entity @patientZero = null;
Entity @finalSurvivor = null;
Entity @camper = null;

const array<String> bannedCallvotes = {"shuffle", "rebalance"};

int[] teamScore(GS_MAX_TEAMS);

int[] playerTeam(maxClients);
int[] infects(maxClients);
int[] survivorFrags(maxClients);
int[] mvps(maxClients);
bool[] isInfected(maxClients);

int[] thisRoundSurvivorFrags(maxClients);
int[] thisRoundInfects(maxClients);

uint[] lastDamageTime(maxClients);
const uint regainHealthTimer = 5;

int thisRoundSurvivors = 0;


uint roundEndTime;
uint roundStartTime;
uint endRoundCountdownNumber = 0;

uint countdownForRoundStart = 0;
uint nextRoundCountdownNumber = 0;

const uint timeBetweenRounds = 5;

uint roundTransitionTime = 0;
const uint timeBetweenRoundEndAndStart = 3;

const int survivorFragsScoreWorth = 1;
const int infectsScoreWorth = 1;
const int mvpsScoreWorth = 2;

const int MG_AMMO = 35;

const uint AFK_TIME = 60;

// CS_GENERAL = CS_WEAPONDEFS + MAX_WEAPONDEFS

// const int MAX_WEAPONDEFS = 64;
// const int CS_WEAPONDEFS = CS_GENERAL - MAX_WEAPONDEFS;

const uint zombie_PMFEATS =
    PMFEAT_DEFAULT & ~(
    //PMFEAT_GUNBLADEAUTOATTACK |
    PMFEAT_AIRCONTROL |
    PMFEAT_FWDBUNNY |
    PMFEAT_ITEMPICK
);

const uint camper_PMFEATS =
PMFEAT_DEFAULT & ~(
    PMFEAT_GUNBLADEAUTOATTACK |
    PMFEAT_AIRCONTROL |
    PMFEAT_FWDBUNNY |
    PMFEAT_WALLJUMP |
    PMFEAT_CONTINOUSJUMP |
    PMFEAT_ITEMPICK
  );


const uint PMFEAT_FREEZE = 0x0000 | PMFEAT_ZOOM | PMFEAT_CROUCH;


// const int MG_AMMO_REWARD = 15;


class MVPResults {
    array<Client @> SurvivorMVPList;
    int highestSurvivorFrags;

    array<Client @> ZombieMVPList;
    int highestInfects;
}

///*****************************************************************
/// NEW MAP ENTITY DEFINITIONS
///*****************************************************************


///*****************************************************************
/// LOCAL FUNCTIONS
///*****************************************************************
int amountPlayersPlaying() { return ( G_GetTeam(TEAM_ALPHA).numPlayers + G_GetTeam(TEAM_BETA).numPlayers ); }

void Infection_setScore(Client @client) {
    client.stats.setScore(
        + ( survivorFrags[client.playerNum] * survivorFragsScoreWorth ) 
        + ( infects[client.playerNum] * infectsScoreWorth )
        + ( mvps[client.playerNum] * mvpsScoreWorth )
        );
}

void Infection_InitPlayer(int playerNum, bool uninit = false) {
    
    playerTeam[playerNum] = TEAM_ALPHA;
    infects[playerNum] = 0;
    survivorFrags[playerNum] = 0;
    mvps[playerNum] = 0;
    isInfected[playerNum] = false;
    thisRoundSurvivorFrags[playerNum] = 0;
    thisRoundInfects[playerNum] = 0;
    lastDamageTime[playerNum] = 0;
}



void Infection_StartRound()
{

    /*
    if ( caMode.boolean ) {
    gametype.spawnableItemsMask = ( 0 );
    selfdmg.set( 0 );
    falldmg.set( 0 );
}
    else {
    gametype.spawnableItemsMask = ( IT_WEAPON | IT_AMMO | IT_ARMOR | IT_HEALTH );
}
     */
    // gametype.spawnableItemsMask = ( IT_WEAPON | IT_AMMO | IT_ARMOR | IT_HEALTH );

    // gametype.respawnableItemsMask = gametype.spawnableItemsMask;
    // gametype.dropableItemsMask = gametype.spawnableItemsMask;
    // gametype.pickableItemsMask = ( gametype.spawnableItemsMask | gametype.dropableItemsMask );

    roundTransitionTime = 0;
    G_Items_RespawnByType( 0, 0, 0 );                       // respawn all items

    @finalSurvivor = null;

    for ( int i = 0; i < maxClients; i++ )
    {
        Client @client = @G_GetClient( i );

        playerTeam[client.playerNum] = TEAM_BETA;
        isInfected[client.playerNum] = true;

        thisRoundSurvivorFrags[client.playerNum] = 0;
        thisRoundInfects[client.playerNum] = 0;

        Entity @ent = @client.getEnt();
        if ( ent.team == TEAM_SPECTATOR || client.state() < CS_SPAWNED )
            continue;

        ent.client.pmoveFeatures = PMFEAT_DEFAULT;
        ent.client.pmoveDashSpeed = -1;
        ent.client.pmoveMaxSpeed = -1;
        isInfected[ent.playerNum] = false;
        playerTeam[ent.playerNum] = TEAM_ALPHA;
        ent.maxHealth = 100;
        ent.client.team = TEAM_ALPHA;
        ent.client.respawn( false );
        ent.team = TEAM_ALPHA;
    }


    G_RemoveAllProjectiles();
    gametype.shootingDisabled = true;  // avoid shooting before "FIGHT!"
    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = false;
    gametype.countdownEnabled = false;

    // gametype.pickableItemsMask = 0;                     // disallow item pickup
    // gametype.dropableItemsMask = 0;                     // disallow item drop

    roundIsBeingPlayed = false;
    finalSurvivorAcknowledged = false;

    endRoundCountdownNumber = 3;


/*
    Entity @patientZero = null;
    if (@patientZero == null || patientZero.client.state() < CS_SPAWNED || patientZero.team == TEAM_SPECTATOR) {
        @patientZero = @randomPlayer();
        if (patientZero.client.lastActivity + AFK_TIME * 1000 < levelTime) {
            if (infectionDebug.boolean)
                G_Print(patientZero.client.name + S_COLOR_GREEN + " Failed afkcheck, choosing patient zero again\n");
            @patientZero = @randomPlayer();                 // try get a new player if afk, try once, if its the same one, who cares?
        }
    }

    InfectPlayer(patientZero);
    ApplyZombieStatus(patientZero, "patientZero:");

    G_CenterPrintMsg( null, "The first zombie for this round will be: "+ patientZero.client.name );
    G_CenterPrintMsg( patientZero, "You are a zombie!\nInfect others!" );
    G_PrintMsg( null, "The first zombie for this round will be: "+ patientZero.client.name + "\n");
	
	@patientZero = null;
*/

    uint playerCount = amountPlayersPlaying();

    uint infectedAmount = floor ( playerCount * ( startPercent.value / 100.0f ) );

    if (infectedAmount >= playerCount) {
        if (infectionDebug.boolean)
            G_Print(S_COLOR_CYAN + "infectedAmount >= playerCount\n");
        infectedAmount = playerCount - 1;
    }
    if ( infectedAmount <= 0 ) {
        if (infectionDebug.boolean)
            G_Print(S_COLOR_CYAN + "infectedAmount <= 0\n");
        infectedAmount = 1;
    }
    if (infectionDebug.boolean)
        G_Print(startPercent.value + "% of " + playerCount + ": " + infectedAmount + "\n");

    array<Entity @> startinfectedList;

    for ( uint i = 0; startinfectedList.length() < infectedAmount && i < 1000; i++)
    {
        Entity @ent = @randomPlayer();
        bool alreadyInList = false;

        for ( uint j = 0; j < startinfectedList.length(); j++)
        {
            if (@startinfectedList[j] == @ent)
            {
                alreadyInList = true;
                break;
            }
        }

        if (!alreadyInList)
            startinfectedList.insertLast(@ent);
    }

    String listOfInfected = "";
    for ( uint i = 0; i < startinfectedList.length(); i++ )
    {
        Entity @ent = @startinfectedList[i];
        InfectPlayer(ent);

        if (!listOfInfected.empty())
        listOfInfected += S_COLOR_WHITE + ", ";
        listOfInfected += ent.client.name;
    }

    String msg = "The starting zombie" + (startinfectedList.length() == 1 ? "" : "s") + " for this round will be: " + listOfInfected;

    G_CenterPrintMsg( null, msg );

    for ( int i = 0; i < maxClients; i++ )
    {
        Client @client = @G_GetClient( i );

        if (isInfected[client.playerNum] && client.team != TEAM_SPECTATOR ) {
            ApplyZombieStatus(client.getEnt(), "startInfected:");
            G_CenterPrintMsg( client.getEnt(), "You are a zombie!" );
        }
    }

    thisRoundSurvivors = amountPlayersPlaying() - startinfectedList.length();

    if (infectionDebug.boolean)
        G_Print( thisRoundSurvivors + " survivors this round\n" );

    G_PrintMsg( null, msg + "\n");


    // Entity @patientZero = @randomPlayer();
    // InfectPlayer(patientZero);
    // ApplyZombieStatus(patientZero);

    countdownForRoundStart = levelTime + timeBetweenRounds * 1000;
    nextRoundCountdownNumber = timeBetweenRounds;

}


void Infection_EndRound(int winningTeam = 0, bool errorFallback = false )
{
    if (match.getState() != MATCH_STATE_PLAYTIME)
        return;
    if (!roundIsBeingPlayed)
        return;


    gametype.shootingDisabled = true;
    roundIsBeingPlayed = false;


    G_RemoveAllProjectiles();
    match.setClockOverride( 0 );


    if (winningTeam != 0) {
        teamScore[winningTeam]++;
        G_GetTeam(winningTeam).stats.setScore(teamScore[winningTeam]);
  

        MVPResults thisRoundMVPs = getMVPs();

        String endRoundMVPSurvivorMsg = "";
        String endRoundMVPZombieMsg = "";

        String SurvivorMVPNames = "";
        String ZombieMVPNames = "";

        for (int i = 0; i < maxClients; i++)
        {
            Client @client = @G_GetClient(i);
            if (@client == null)
                continue;

            bool isSurvivorMVP = false;
            for (uint j = 0; j < thisRoundMVPs.SurvivorMVPList.length(); j++)
            {
                if (@thisRoundMVPs.SurvivorMVPList[j] is client)
                {
                    if (thisRoundMVPs.highestSurvivorFrags != 0)
                        isSurvivorMVP = true;

                    if (!SurvivorMVPNames.empty())
                        SurvivorMVPNames += S_COLOR_WHITE + ", ";
                    SurvivorMVPNames += client.name;
                    break;
                }
            }

            bool isZombieMVP = false;
            for (uint j = 0; j < thisRoundMVPs.ZombieMVPList.length(); j++)
            {
                if (@thisRoundMVPs.ZombieMVPList[j] is client)
                {
                    if (thisRoundMVPs.highestInfects != 0)
                        isZombieMVP = true;
                    if (!ZombieMVPNames.empty())
                        ZombieMVPNames += S_COLOR_WHITE + ", ";
                    ZombieMVPNames += client.name;
                    break;
                }
            }


            if (isSurvivorMVP && thisRoundMVPs.SurvivorMVPList.length() <= 2) {
                client.addAward(S_COLOR_CYAN + "Survivor MVP!");
                mvps[client.playerNum]++;
            }
            if (isZombieMVP && thisRoundMVPs.ZombieMVPList.length() <= 2) {
                client.addAward(S_COLOR_GREEN + "Zombie MVP!");
                mvps[client.playerNum]++;
            }
            Infection_setScore(client);
        }

        if (thisRoundMVPs.highestSurvivorFrags != 0 && thisRoundMVPs.SurvivorMVPList.length() <= 2) {
            bool pluralPlayers = (thisRoundMVPs.SurvivorMVPList.length() > 1);
            bool pluralScore = (thisRoundMVPs.highestSurvivorFrags > 1);
            endRoundMVPSurvivorMsg = S_COLOR_RED + "Survivor MVP" + ( pluralPlayers ? "s" : "") + ": " + S_COLOR_WHITE + SurvivorMVPNames + " with " + thisRoundMVPs.highestSurvivorFrags + " zombie frag" + (pluralScore ? "s" : "") + (pluralPlayers ? " each" : "") + '!';
        } else {
            endRoundMVPSurvivorMsg = S_COLOR_RED + "No survivor MVPs.";
        }
        if (thisRoundMVPs.highestInfects != 0 && thisRoundMVPs.ZombieMVPList.length() <= 2) {
            bool pluralPlayers = (thisRoundMVPs.ZombieMVPList.length() > 1);
            bool pluralScore = (thisRoundMVPs.highestInfects > 1);
            endRoundMVPZombieMsg = S_COLOR_RED + "Zombie MVP" + (pluralPlayers ? "s" : "") + ": " + S_COLOR_WHITE + ZombieMVPNames + " with " + thisRoundMVPs.highestInfects + " infect" + (pluralScore ? "s" : "") + (pluralPlayers ? " each" : "") + '!';
        } else {
            endRoundMVPZombieMsg = S_COLOR_RED + "No zombie MVPs.";
        }

        G_PrintMsg(null, endRoundMVPSurvivorMsg + "\n");
        G_PrintMsg(null, endRoundMVPZombieMsg + "\n");
        if (winningTeam == TEAM_ALPHA && finalSurvivorAcknowledged && thisRoundSurvivorFrags[finalSurvivor.playerNum] == 0 && @camper != null && thisRoundSurvivors >= 3) {
            G_PrintMsg(null, finalSurvivor.client.name + S_COLOR_YELLOW + " is a lame camper! They will be punished next round!" + "\n");
            @camper = @finalSurvivor;
        }
        else {
            @camper = null;
        }

    }


    if ( match.scoreLimitHit() ) {
        match.launchState(MATCH_STATE_POSTMATCH);
        return;
    }

	GENERIC_UpdateMatchScore();

    // print scores to console
    if ( gametype.isTeamBased )
    {
        Team @team1 = @G_GetTeam( TEAM_ALPHA );
        Team @team2 = @G_GetTeam( TEAM_BETA );

        String winningTeamName = G_GetTeam(winningTeam).name;
        String msg = winningTeamName + " win this round!";
        if (winningTeam == 0)
            msg = S_COLOR_ORANGE + "Draw Round!";

        G_PrintMsg(null, msg + "\n" );
        G_CenterPrintMsg(null, msg);
    }

    // int soundIndex = G_SoundIndex( "sounds/announcer/postmatch/game_over0" + (1 + (rand() & 1)) );
    // G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, true, null );
    if (!errorFallback) {
        roundTransitionTime = levelTime + (timeBetweenRoundEndAndStart * 1000);
    }
    return;
}

MVPResults getMVPs()
{
    int highestSurvivorFrags = 0;
    int highestInfects = 0;
    array<Client @> SurvivorMVPList;
    array<Client @> ZombieMVPList;
    for ( int i = 0; i < maxClients; i++ )
    {
        Client @client = @G_GetClient( i );

        if (thisRoundSurvivorFrags[client.playerNum] > highestSurvivorFrags) {
            highestSurvivorFrags = thisRoundSurvivorFrags[client.playerNum];
            SurvivorMVPList.resize(0);
        }
        if (thisRoundSurvivorFrags[client.playerNum] == highestSurvivorFrags) {
            SurvivorMVPList.insertLast(@client);
        }

        if (thisRoundInfects[client.playerNum] > highestInfects) {
            highestInfects = thisRoundInfects[client.playerNum];
            ZombieMVPList.resize(0);
        }
        if (thisRoundInfects[client.playerNum] == highestInfects) {
            ZombieMVPList.insertLast(@client);
        }
    }
    MVPResults results;
    results.SurvivorMVPList = SurvivorMVPList;
    results.highestSurvivorFrags = highestSurvivorFrags;
    results.ZombieMVPList = ZombieMVPList;
    results.highestInfects = highestInfects;

    return results;
}

void removeAllEntitiesByClassname(String classname)
{
    array<Entity @> @ents = G_FindByClassname( classname );

    for (uint i = 0; i < ents.length(); i++) {
        ents[i].freeEntity();
    }
    return;
}

void printAllClients(Entity @ent = null) {
    String msg;
    msg += "- List of current players:\n";
    for ( int i = 0; i < maxClients; i++ )
    {
        Client @client = @G_GetClient( i );
        if (client.state() < CS_SPAWNED)
            continue;

            msg += "  " + client.playerNum + ": " + client.name + "\n";

    }
    G_PrintMsg(ent, msg);
}

void changePickupToAmmo(String classname, int tag, int count)
{
    array<Entity @> @ents = G_FindByClassname( classname );

    for (uint i = 0; i < ents.length(); i++) {
        GENERIC_SpawnItem(ents[i], tag);
        ents[i].count = count;
      }
    return;
}

// array<int @> getAllIngamePlayerNums() {
//     array<int @> playerList;
//     for ( int t = TEAM_ALPHA; t < GS_MAX_TEAMS; t++ )
//     {
//         Team @team = @G_GetTeam( t );
//         for ( int i = 0; @team.ent( i ) != null; i++ )
//         {
//             playerList.insertLast( team.ent( i ).playerNum );
//         }
//     }
//     return playerList;
// }


// void fakeObituary(int victimPlayerNum, int attackerPlayerNum, int meansOfDeath) {
//     for (int i = 0; i < maxClients; i++)
//     {
//         G_GetClient(i).execGameCommand("obry " + ( victimPlayerNum + 1 ) + " " + ( attackerPlayerNum + 1) + " " + meansOfDeath );
//     }
// }

// void Infection_getCvar( Client @client, const String &in cmdString, const String &in argsString, int argc )
// {
//     //G_Print( S_COLOR_RED + "cvarinfo response: (argc" + argc + ") " + S_COLOR_WHITE + client.name + S_COLOR_WHITE + " " + argsString + "\n" );

//     if ( argc < 2 )
//         return;

//     if ( @client == null )
//         return;

//     String cvarName = argsString.getToken( 0 );
//     String cvarContent = argsString.getToken( 1 );

//     //G_Print('^3cvarcheck:^7 ' + client.name + ' ' + cvarName + ' ' + cvarContent + "\n");
// }


Entity @getPlayerEntByName(String clientName = "") {
    if ( clientName.empty() ) return null;
    int playerNum;
    // check playerNum first
    if ( ( clientName == "0" || clientName.toInt() != 0 ) && (clientName.toInt() >= 0 && clientName.toInt() < maxClients ) ) {

        playerNum = clientName.toInt();
        if (G_GetClient(playerNum).state() >= CS_SPAWNED)
            return G_GetClient(playerNum).getEnt();
    }

    for ( int i = 0; i < maxClients; i++ ) {
            Client @c = @G_GetClient( i );
            if ( c.name.removeColorTokens().tolower() == clientName.removeColorTokens().tolower() )
                return c.getEnt();
        }
    return null;
}


Entity @randomPlayerTeam(int team) { return G_GetTeam( team ).ent(floor(brandom(0, ( G_GetTeam( team ).numPlayers ) ))); }

Entity @randomPlayer() {
    if ( G_GetTeam( TEAM_ALPHA ).numPlayers == 0 )
        return randomPlayerTeam( TEAM_BETA );
    if ( G_GetTeam( TEAM_BETA ).numPlayers == 0 )
        return randomPlayerTeam( TEAM_ALPHA );

    // Yes this means uneven teams = more chance of being chosen if on team with less players
    // TODO: make this even


    if ((rand() & 1) == 1)
        return randomPlayerTeam( TEAM_ALPHA );
    else
        return randomPlayerTeam( TEAM_BETA );
}

void InfectPlayer( Entity @ent, float damage = 50.0f)
{
    if (match.getState() != MATCH_STATE_PLAYTIME)
        return;
    if (ent.client.team == TEAM_SPECTATOR)
        return;

    if ( playerTeam[ent.playerNum] == TEAM_ALPHA && G_GetTeam(TEAM_ALPHA).numPlayers <= 1 )
    {

        ent.client.inventoryClear();
        ent.client.inventorySetCount( WEAP_GUNBLADE, 1 );
        ent.client.selectWeapon(-1);

        if (ent.health > 0)
            ent.health = zombieHealth.integer + damage;
        ent.maxHealth = zombieHealth.integer;

        Infection_EndRound(TEAM_BETA);
        return;
    }
    playerTeam[ent.playerNum] = TEAM_BETA;
    isInfected[ent.playerNum] = true;
}

void ApplyZombieStatus( Entity @ent, String debugText = "" )
{
    if (match.getState() != MATCH_STATE_PLAYTIME)
        return;
    if (ent.health <= 0)
        return;
    if (ent.client.team == TEAM_SPECTATOR)
        return;

    
    if (infectionDebug.boolean)
        G_Print( S_COLOR_YELLOW + debugText + S_COLOR_RED + "ApplyZombieStatus(" + S_COLOR_WHITE + ent.client.name + S_COLOR_RED + ")\n");

    isInfected[ent.playerNum] = true;
    playerTeam[ent.playerNum] = TEAM_BETA;
    ent.team = TEAM_BETA;

    ent.client.pmoveFeatures = zombie_PMFEATS;
    ent.client.pmoveMaxSpeed = -1;
    ent.client.pmoveDashSpeed = -1;

    if (!roundIsBeingPlayed) {
        ent.client.pmoveFeatures = PMFEAT_FREEZE;
        ent.client.pmoveMaxSpeed = 0;
        ent.client.pmoveDashSpeed = 0;
    }

    //if (caMode.boolean)
    //    ent.client.pmoveFeatures = ent.client.pmoveFeatures | PMFEAT_AIRCONTROL | PMFEAT_GUNBLADEAUTOATTACK;
    
    ent.client.inventoryClear();
    ent.client.inventorySetCount( WEAP_GUNBLADE, 1 );
    ent.client.selectWeapon(-1);


    if ( !(ent.health <= 0) ) 
        ent.health = zombieHealth.integer + 50;
    ent.maxHealth = zombieHealth.integer;

    
    ent.client.armor = 0;



}

void unfreezeZombies() {

    for ( int i = 0; i < maxClients; i++ )
    {
        Entity @ent = @G_GetEntity(i);
        if ( ent.team == TEAM_SPECTATOR || ent.client.state() < CS_SPAWNED )
            continue;
        if ( playerTeam[ent.playerNum] == TEAM_BETA )
            ApplyZombieStatus(ent, "unfreezeZombies:");

    }
}

// a player has just died. The script is warned about it so it can account scores
void TDM_playerKilled( Entity @target, Entity @attacker, Entity @inflictor )
{
    if ( match.getState() != MATCH_STATE_PLAYTIME )
        return;

    if ( @attacker != null && @attacker.client != null && @attacker != @target && !isInfected[attacker.playerNum] ) {
        survivorFrags[attacker.playerNum]++;
        thisRoundSurvivorFrags[attacker.playerNum]++;
        // attacker.client.inventoryGiveItem( AMMO_BULLETS, MG_AMMO_REWARD );
        Infection_setScore(attacker.client);
    }

    if ( @target.client == null )
        return;

    if (playerTeam[target.playerNum] != TEAM_BETA) {
        InfectPlayer(target);
    }

    // check for generic awards for the frag
    if( @attacker != null && attacker.team != target.team )
		award_playerKilled( @target, @attacker, @inflictor );
}


float Infection_bot_PlayerWeight( Entity @self, Entity @enemy )
{
    float weight;

    if ( @enemy == null || @enemy == @self )
        return 0;

    if ( enemy.isGhosting() )
        return 0;

    //if not team based give some weight to every one
    if ( gametype.isTeamBased && ( enemy.team == self.team ) )
        return 0;

    if( !self.client.isBot() )
        return 0.0f;

    weight = 0.5f;

    // don't fight against zombies.
    if ( isInfected[enemy.playerNum] )
        weight *= 0.25f;

    // if enemy has EF_CARRIER we can assume it's someone important
    if ( ( enemy.effects & EF_CARRIER ) != 0 )
        weight *= 1.5f;

    return weight * self.client.getBot().offensiveness;
}

int getTeamByName( String teamname )
{
    for ( int i = TEAM_SPECTATOR; i < GS_MAX_TEAMS; i++ )
    {
        Team @team = @G_GetTeam( i );
        if (team.name.toupper() == teamname.toupper())
            return i;
    }
    return -1;
}
bool joinCommand( Client @client, String chosenTeam )
{
    Entity @ent = client.getEnt();
    Team @team1 = G_GetTeam(TEAM_ALPHA);
    Team @team2 = G_GetTeam(TEAM_BETA);

    if ( match.getState() == MATCH_STATE_POSTMATCH && !( getTeamByName(chosenTeam) == TEAM_SPECTATOR ) ) {
        G_PrintMsg(ent, "You can't join the game now\n");
        return false;
    }

    if (!chosenTeam.empty()) {
        if ( getTeamByName(chosenTeam) == TEAM_PLAYERS ) {
            G_PrintMsg(ent, "Can't join PLAYERS in " + gametype.name + "\n");
            return false;
        }
        if ( getTeamByName(chosenTeam) == -1 ) {
            G_PrintMsg(ent, "No such team.\n");
            return false;
        }

        if ( getTeamByName(chosenTeam) == client.team ) {
            if (client.team == TEAM_SPECTATOR)
                G_PrintMsg(ent, "You are already a spectator.\n");
            else
                G_PrintMsg(ent, "You are already in " + chosenTeam.toupper() + " team\n");
            return false;
        }
        client.team = getTeamByName(chosenTeam);
    }
    else if (client.team == TEAM_SPECTATOR) {
        if (team1.numPlayers > team2.numPlayers) {
            client.team = TEAM_BETA;
        } else {
            client.team = TEAM_ALPHA;
        }
    } else {
        client.team = (client.team == TEAM_ALPHA ? TEAM_BETA : TEAM_ALPHA);
    }

    if (isInfected[client.playerNum] && ent.team != TEAM_SPECTATOR) {
        G_PrintMsg(ent, "You can't switch teams, you're a zombie!\n");
        return false;
    }

    if ( roundIsBeingPlayed && client.team == TEAM_ALPHA )
        client.team = TEAM_BETA;
    if ( client.team == TEAM_BETA && roundIsBeingPlayed ) {
        InfectPlayer(client.getEnt());
    }
    if ( client.state() >= CS_SPAWNED ) {
        G_PrintMsg(null, client.name + S_COLOR_WHITE + " joined the " + G_GetTeam(client.team).name + " team.\n");
        client.respawn( true );
        ent.spawnqueueAdd();
    }
    
    return true;
}
///*****************************************************************
/// MODULE SCRIPT CALLS
///*****************************************************************

bool GT_Command( Client @client, const String &cmdString, const String &argsString, int argc )
{
    /*
    if ( cmdString == "kill" )
    {
        if (playerTeam[client.playerNum] != TEAM_BETA)
            InfectPlayer(client.getEnt());
        client.respawn(false);

        return true;
    }
    else
    */ 
    
    if ( cmdString == "cvarinfo" )
    {
        // lol i tried to  overengineer this so hard
        //Infection_getCvar( client, cmdString, argsString, argc );

        GENERIC_CheatVarResponse( client, cmdString, argsString, argc );
        return true;
    }
    /*
    else if ( cmdString == "debugTest" )
    {
        if (!client.isOperator) {
            G_PrintMsg(client.getEnt(), S_COLOR_RED + "You are not an operator\n");
            return false;
        }

        String msg;
        for ( int i = 0; i < maxClients; i++ )
        {
            Client @c = @G_GetClient( i );
            if ( c.getUserInfoKey( "steam_id" ).toInt() != 0 ) {
                msg += c.name + ' ^7:^3 ' 
                + c.getUserInfoKey( "steam_id" ) + ' : '
                + c.getUserInfoKey( "ip" ) + ' : '
                + c.getUserInfoKey( "socket" ) + ' \n';
            }
                
        }
        G_Print(msg);
        
        return true;
    }
    */
    else if ( cmdString == "forceAllBotsZombie" )
    {

        if (!client.isOperator) {
            G_PrintMsg(client.getEnt(), S_COLOR_RED + "You are not an operator\n");
            return false;
        }

        if ( match.getState() != MATCH_STATE_PLAYTIME ) {
            G_PrintMsg(client.getEnt(), S_COLOR_RED + "Match has not started\n");
            return false;
        }

        for ( int i = 0; i < maxClients; i++ )
        {
            Entity @ent = @G_GetEntity(i);
            if ( ent.team == TEAM_SPECTATOR || ent.client.state() < CS_SPAWNED )
                continue;


            if (ent.client.isBot()) {
                ApplyZombieStatus(ent);
            }
            else {
                isInfected[ent.playerNum] = false;
                playerTeam[ent.playerNum] = TEAM_ALPHA;
                ent.maxHealth = 100;
                ent.client.team = TEAM_ALPHA;
                ent.client.respawn( false );
                ent.team = TEAM_ALPHA;
            }
        }
        ApplyZombieStatus(G_GetTeam(TEAM_BETA).ent(0));

    }
    else if ( cmdString == "forceSurvivorWin" ) {
        if (!client.isOperator) {
            G_PrintMsg(client.getEnt(), S_COLOR_RED + "You are not an operator\n");
            return false;
        }
        if (!roundIsBeingPlayed) {
            G_PrintMsg(client.getEnt(), S_COLOR_RED + "Round has not started\n");
            return false;
        }
        G_PrintMsg(null, client.name + S_COLOR_WHITE + " forced the round to end with SURVIVORS winning!\n");
        Infection_EndRound(TEAM_ALPHA);
    }
    else if ( cmdString == "forceZombieWin" ) {
        if (!client.isOperator) {
            G_PrintMsg(client.getEnt(), S_COLOR_RED + "You are not an operator\n");
            return false;
        }
        if (!roundIsBeingPlayed) {
            G_PrintMsg(client.getEnt(), S_COLOR_RED + "Round has not started\n");
            return false;
        }
        G_PrintMsg(null, client.name + S_COLOR_WHITE + " forced the round to end with ZOMBIES winning!\n");
        Infection_EndRound(TEAM_BETA);
    }
    else if ( cmdString == "forceDrawRound" ) {
        if (!client.isOperator) {
            G_PrintMsg(client.getEnt(), S_COLOR_RED + "You are not an operator\n");
            return false;
        }
        if (!roundIsBeingPlayed) {
            G_PrintMsg(client.getEnt(), S_COLOR_RED + "Round has not started\n");
            return false;
        }
        G_PrintMsg(null, client.name + S_COLOR_WHITE + " forced the round to end with a draw!\n");
        Infection_EndRound();
    }
    else if ( cmdString == "forceRestartRound" ) {
        if (!client.isOperator) {
            G_PrintMsg(client.getEnt(), S_COLOR_RED + "You are not an operator\n");
            return false;
        }
        if (match.getState() != MATCH_STATE_PLAYTIME ) {
            G_PrintMsg(client.getEnt(), S_COLOR_RED + "Match is not being played\n");
            return false;
        }
        G_PrintMsg(null, client.name + S_COLOR_WHITE + " forced the round to restart!\n");
        Infection_StartRound();
    }
    else if ( cmdString == "forceNextmap" ) {
        if (!client.isOperator) {
            G_PrintMsg(client.getEnt(), S_COLOR_RED + "You are not an operator\n");
            return false;
        }
        fallbackDisabled = true;
        match.launchState(MATCH_STATE_POSTMATCH);
    }
    else if ( cmdString == "join" ) {
        String chosenTeam = argsString.getToken( 0 );
        return joinCommand(client, chosenTeam);
    }
    else if ( cmdString == "gametype" )
    {
        String response = "";
        Cvar fs_game( "fs_game", "", 0 );
        String manifest = gametype.manifest;

        response += "\n";
        response += "Gametype " + gametype.name + " : " + gametype.title + "\n";
        response += "----------------\n";
        response += "Version: " + gametype.version + "\n";
        response += "Author: " + gametype.author + "\n";
        response += "Mod: " + fs_game.string + (!manifest.empty() ? " (manifest: " + manifest + ")" : "") + "\n";
        response += "----------------\n";

        G_PrintMsg( client.getEnt(), response );
        return true;
    }
    else if ( cmdString == "callvotevalidate" )
    {
        String votename = argsString.getToken( 0 );

        if ( bannedCallvotes.find(votename) >= 0 ) {
            client.printMessage( "Callvote " + votename + " is not allowed in gametype" + gametype.name + "\n" );
            return false;
        }


        if ( votename == "timelimit" )
        {
            String voteArg = argsString.getToken( 1 );
            if ( voteArg.len() < 1 )
            {
                client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
                return false;
            }

            int value = voteArg.toInt();
            if ( value < 30 && voteArg > 900 )
            {
                client.printMessage( "Callvote " + votename + " should be in range [30-900]\n" );
                return false;
            }

            if ( roundTimeLimit.value == value )
            {
                client.printMessage( "Round time limit already set to" + value + "\n" );
                return false;
            }

            return true;
        }
        /*
        if ( votename == "ca_mode" )
        {
            String voteArg = argsString.getToken( 1 );
            if ( voteArg.len() < 1 )
            {
                client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
                return false;
            }

            int value = voteArg.toInt();
            if ( voteArg != "0" && voteArg != "1" )
            {
                client.printMessage( "Callvote " + votename + " expects a 1 or a 0 as argument\n" );
                return false;
            }

            if ( voteArg == "0" && !caMode.boolean )
            {
                client.printMessage( "CA mode is already off\n" );
                return false;
            }

            if ( voteArg == "1" && caMode.boolean )
            {
                client.printMessage( "CA mode is already on\n" );
                return false;
            }

            return true;
        }
        */

        if ( votename == "spawn_with_mg" )
        {
            String voteArg = argsString.getToken( 1 );
            if ( voteArg.len() < 1 )
            {
                client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
                return false;
            }

            int value = voteArg.toInt();
            if ( voteArg != "0" && voteArg != "1" )
            {
                client.printMessage( "Callvote " + votename + " expects a 1 or a 0 as argument\n" );
                return false;
            }

            if ( voteArg == "0" && !spawnWithMG.boolean )
            {
                client.printMessage( "Spawing with MG is already off\n" );
                return false;
            }

            if ( voteArg == "1" && spawnWithMG.boolean )
            {
                client.printMessage( "Spawning with MG is already on\n" );
                return false;
            }

            return true;
        }

        // if ( votename == "next_patientzero" )
        // {
        //     String voteArg = argsString.getToken( 1 );
        //     if ( voteArg.len() < 1 )
        //     {
        //         client.printMessage( "Callvote " + votename + " requires at least one argument\n" );
        //         return false;
        //     }
        //
        //     Entity @votedPatientZero = @getPlayerEntByName(voteArg);
        //     if ( @votedPatientZero == null) {
        //         client.printMessage( S_COLOR_RED + "No such player\n" );
        //         printAllClients();
        //         return false;
        //     }
        //     if ( @patientZero == @votedPatientZero )
        //     {
        //         client.printMessage( patientZero.client.name + " is already patient zero\n" );
        //         return false;
        //     }
        //
        //     // G_PrintMsg(null, S_COLOR_YELLOW + "CALLVOTE: ^7" + votedPatientZero.client.name + S_COLOR_WHITE + "\n");
        //     return true;
        // }


        client.printMessage( "Unknown callvote " + votename + "\n" );
        return false;
    }
    else if ( cmdString == "callvotepassed" )
    {
        String votename = argsString.getToken( 0 );

        if ( votename == "timelimit" )
        {
            int value = argsString.getToken( 1 ).toInt();
            
            roundTimeLimit.set(value);
        }
        /*
        if ( votename == "ca_mode" )
        {
            if ( argsString.getToken( 1 ).toInt() > 0 )
                caMode.set( 1 );
            else
                caMode.set( 0 );
            
            Infection_EndRound();
        }
        */
        if ( votename == "spawn_with_mg" )
        {
            if ( argsString.getToken( 1 ).toInt() > 0 )
                spawnWithMG.set( 1 );
            else
                spawnWithMG.set( 0 );
            
            Infection_EndRound();
        }

        // if ( votename == "next_patientzero" )
        // {
        //     String voteArg = argsString.getToken( 1 );
        //     Entity @nextPatientZero = @getPlayerEntByName(voteArg);
        //     if ( @nextPatientZero == null )
        //         return false;
        //
        //     @patientZero = @nextPatientZero;
        //     G_PrintMsg(null, nextPatientZero.client.name + " will be the next Patient Zero\n");
        // }

        return true;
    }

    return false;
}

// When this function is called the weights of items have been reset to their default values,
// this means, the weights *are set*, and what this function does is scaling them depending
// on the current bot status.
// Player, and non-item entities don't have any weight set. So they will be ignored by the bot
// unless a weight is assigned here.
bool GT_UpdateBotStatus( Entity @self )
{

    Entity @goal;
    Bot @bot;

    @bot = @self.client.getBot();
    if ( @bot == null )
        return false;

    //float offensiveStatus = GENERIC_OffensiveStatus( self );
    float offensiveStatus = 2.0f;

    // loop all the goal entities
    for ( int i = AI::GetNextGoal( AI::GetRootGoal() ); i != AI::GetRootGoal(); i = AI::GetNextGoal( i ) )
    {
        @goal = @AI::GetGoalEntity( i );

        // by now, always full-ignore not solid entities
        if ( goal.solid == SOLID_NOT )
        {
            bot.setGoalWeight( i, 0 );
            continue;
        }

        if ( @goal.client != null )
        {
            bot.setGoalWeight( i, Infection_bot_PlayerWeight( self, goal ) * offensiveStatus );
            continue;
        }


        if ( @goal.item != null )
        {

            // all the following entities are items
            
            if ( ( goal.item.type & IT_WEAPON ) != 0 )
            {
                bot.setGoalWeight( i, 2*GENERIC_WeaponWeight( self, goal ) );
            }
            else if ( ( goal.item.type & IT_AMMO ) != 0 )
            {
                bot.setGoalWeight( i, 1.5*GENERIC_AmmoWeight( self, goal ) );
            }
            else if ( ( goal.item.type & IT_ARMOR ) != 0 )
            {
                bot.setGoalWeight( i, GENERIC_ArmorWeight( self, goal ) );
            }
            else if ( ( goal.item.type & IT_HEALTH ) != 0 )
            {
                bot.setGoalWeight( i, GENERIC_HealthWeight( self, goal ) );
            }
            else if ( ( goal.item.type & IT_POWERUP ) != 0 )
            {
                bot.setGoalWeight( i, bot.getItemWeight( goal.item ) * offensiveStatus );
            }
            
            if ( isInfected[self.playerNum] )
                bot.setGoalWeight( i, 0 );


            continue;
        }

        // we don't know what entity is this, so ignore it
        bot.setGoalWeight( i, 0 );
    }

    return true; // handled by the script

}

// select a spawning point for a player
Entity @GT_SelectSpawnPoint( Entity @self )
{
    return GENERIC_SelectBestRandomSpawnPoint( self, "info_player_deathmatch" );
}

String @GT_ScoreboardMessage( uint maxlen )
{
        String scoreboardMessage = "";
        String entry;
        Team @team;
        Entity @ent;
        int i, t;

        for ( t = TEAM_ALPHA; t < GS_MAX_TEAMS; t++ )
        {
            @team = @G_GetTeam( t );

            // &t = team tab, team tag, team score, team ping
            entry = "&t " + t + " " + team.stats.score + " " + team.ping + " ";
            if ( scoreboardMessage.len() + entry.len() < maxlen )
                scoreboardMessage += entry;

            for ( i = 0; @team.ent( i ) != null; i++ )
            {
                @ent = @team.ent( i );

                int playerID = ( ent.isGhosting() && ( match.getState() == MATCH_STATE_PLAYTIME ) ) ? -( ent.playerNum + 1 ) : ent.playerNum;

                // "AVATAR Name Clan Frags Infects MVPs Ping R"
                entry = "&p " + playerID + " " + playerID + " "
                        + ent.client.clanName + " "
                        + survivorFrags[ent.playerNum] + " "
                        + infects[ent.playerNum] + " "
                        + mvps[ent.playerNum] + " "
                        + ent.client.ping + " "
                        + ( ent.client.isReady() ? "1" : "0" ) + " ";

                if ( scoreboardMessage.len() + entry.len() < maxlen )
                    scoreboardMessage += entry;
            }
        }

        return scoreboardMessage;
}

// Some game actions trigger score events. These are events not related to killing
// oponents, like capturing a flag
// Warning: client can be null

/*
award, kill, dmg, projectilehit, pickup, enterGame, userinfochanged, connect, disconnect, shuffle, rebalance
*/
void GT_ScoreEvent( Client @client, const String &score_event, const String &args )
{
    if ( score_event == "dmg" )
    {   
        if (match.getState() != MATCH_STATE_PLAYTIME)
            return;

        Entity @victim = @G_GetEntity( args.getToken( 0 ).toInt() );
        float damage = args.getToken( 1 ).toFloat();

        if ( @client == null || @client == @victim.client )
		{
            if ( @client == @victim.client ) {
                victim.health -= damage;
            }
            if (@victim != null)
            {
                lastDamageTime[victim.playerNum] = levelTime;
            }
			return;
        }

        Entity @attacker = @client.getEnt();


        
        if (victim.team == TEAM_ALPHA && attacker.team == TEAM_BETA) {
            if (isInfected[victim.playerNum])
                return;
            if ( victim.health > 0 )
                victim.health = 100 + damage;
            infects[client.playerNum]++;
            thisRoundInfects[client.playerNum]++;

            // fakeObituary( victim.playerNum, attacker.playerNum, MOD_TRIGGER_HURT );

            Infection_setScore(client);

            G_PrintMsg(null, victim.client.name + S_COLOR_WHITE + " was infected by " + client.name + "\n");

            G_CenterPrintMsg(victim, client.name + S_COLOR_WHITE + " infected you!" + (!finalSurvivorAcknowledged ? "\nInfect others!" : ""));
            G_CenterPrintMsg(attacker, "YOU INFECTED " + victim.client.name.toupper());

            int soundIndex = G_SoundIndex( "sounds/misc/kill" );
            G_LocalSound( client, CHAN_AUTO, soundIndex );
            InfectPlayer(victim, damage);
        }
            
    }

    else if ( score_event == "kill" )
    {

        Entity @attacker = null;

        if ( @client != null )
            @attacker = @client.getEnt();

        int arg1 = args.getToken( 0 ).toInt();
        int arg2 = args.getToken( 1 ).toInt();

        // target, attacker, inflictor
        TDM_playerKilled( G_GetEntity( arg1 ), attacker, G_GetEntity( arg2 ) );
    }
    else if ( score_event == "pickup" )
    {
        String pickedUpClassname = args.getToken( 0 );
        // G_Print(pickedUpClassname + "\n");

        if ( pickedUpClassname == "ammo_gunblade" )
            client.inventorySetCount( WEAP_GUNBLADE , 1);

        else if ( pickedUpClassname == "ammo_machinegun" )
            client.inventorySetCount( WEAP_MACHINEGUN , 1);

        else if ( pickedUpClassname == "ammo_riotgun" )
            client.inventorySetCount( WEAP_RIOTGUN , 1);

        else if ( pickedUpClassname == "ammo_grenadelauncher" )
            client.inventorySetCount( WEAP_GRENADELAUNCHER , 1);

        else if ( pickedUpClassname == "ammo_rocketlauncher" )
            client.inventorySetCount( WEAP_ROCKETLAUNCHER , 1);

        else if ( pickedUpClassname == "ammo_plasmagun" )
            client.inventorySetCount( WEAP_PLASMAGUN , 1);

        else if ( pickedUpClassname == "ammo_lasergun" )
            client.inventorySetCount( WEAP_LASERGUN , 1);

        else if ( pickedUpClassname == "ammo_electrobolt" )
            client.inventorySetCount( WEAP_ELECTROBOLT , 1);

        else if ( pickedUpClassname == "ammo_instagun" )
            client.inventorySetCount( WEAP_INSTAGUN , 1);


    }

    else if ( score_event == "enterGame" ) {
        Infection_InitPlayer(client.playerNum);
    }
    // else if ( score_event == "connect" ) {

    // }
    else if ( score_event == "disconnect" ) {
        Infection_InitPlayer(client.playerNum, true);
    }
}

// a player is being respawned. This can happen from several ways, as dying, changing team,
// being moved to ghost state, be placed in respawn queue, being spawned from spawn queue, etc
void GT_PlayerRespawn( Entity @ent, int old_team, int new_team )
{

	Client @client = @ent.client;

    if ( ent.isGhosting() )
	{
		GENERIC_ClearQuickMenu( @client );
        ent.svflags &= ~SVF_FORCETEAM;
        return;
	}
    ent.svflags |= SVF_FORCETEAM;

    if ( gametype.isInstagib && @ent != @camper ) {
        client.inventorySetCount( WEAP_INSTAGUN, 1 );
        client.inventorySetCount( AMMO_INSTAS, 1 );
    }
    else {
        client.inventorySetCount( WEAP_GUNBLADE, 1 );
    }


    if ( spawnWithMG.boolean ) {
        client.inventorySetCount( WEAP_MACHINEGUN, 1 );
        client.inventorySetCount( AMMO_BULLETS, MG_AMMO );
    }
    //if ( caMode.boolean )
    //    client.inventorySetCount( AMMO_GUNBLADE, 1 );

    client.selectWeapon(-1);

    if (match.getState() == MATCH_STATE_PLAYTIME) {
        if (!isInfected[client.playerNum] && ent.team == TEAM_BETA && ent.health > 0) {
            //G_Print("^5PlayerRespawn: debug test ^7" + client.name + "\n");
            InfectPlayer(client.getEnt());
        }
        if (isInfected[client.playerNum]) {
            ApplyZombieStatus(client.getEnt(), "PlayerRespawn:");
        }
    }

/*
    if ( caMode.boolean ) {
        if (!isInfected[client.playerNum]) {
    	// give the weapons and ammo as defined in cvars
    	String token, weakammotoken, ammotoken;
    	String itemList = g_noclass_inventory.string;
    	String ammoCounts = g_class_strong_ammo.string;

    	ent.client.inventoryClear();

        for ( int i = 0; ;i++ )
        {
            token = itemList.getToken( i );
            if ( token.len() == 0 )
                break; // done

            Item @item = @G_GetItemByName( token );
            if ( @item == null )
                continue;

            ent.client.inventoryGiveItem( item.tag );

            // if it's ammo, set the ammo count as defined in the cvar
            if ( ( item.type & IT_AMMO ) != 0 )
            {
                token = ammoCounts.getToken( item.tag - AMMO_GUNBLADE );

                if ( token.len() > 0 )
                {
                    ent.client.inventorySetCount( item.tag, token.toInt() );
                }
            }
        }


        // select rocket launcher
        ent.client.selectWeapon( WEAP_ROCKETLAUNCHER );
        }
    // give armor
    ent.client.armor = 150;
    }
*/

	
    // add a teleportation effect
    ent.respawnEffect();
}

// Thinking function. Called each frame
void GT_ThinkRules()
{
    if ( match.timeLimitHit() )
    {
        match.launchState( match.getState() + 1 );
    }
  
    if ( match.getState() == MATCH_STATE_PLAYTIME )
    {
        if (roundIsBeingPlayed)
        {
            roundEndTime = roundStartTime + ( roundTimeLimit.value * 1000);
            match.setClockOverride( roundEndTime - levelTime );

        
            if ( endRoundCountdownNumber != 0 && levelTime > roundEndTime - endRoundCountdownNumber * 1000) {
                
                if (endRoundCountdownNumber <= 3) {
                    int soundIndex = G_SoundIndex( "sounds/announcer/countdown/" + endRoundCountdownNumber + "_0" + (1 + (rand() & 1)) );
                    G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
                    G_CenterPrintMsg(null, endRoundCountdownNumber + "\n" );
                }
                

                endRoundCountdownNumber--;
            }
            if ( levelTime > roundEndTime ) {
                Infection_EndRound(TEAM_ALPHA);
                return;
            }


            if ( !finalSurvivorAcknowledged && G_GetTeam(TEAM_ALPHA).numPlayers == 1 )
            {
                finalSurvivorAcknowledged = true;
                @finalSurvivor = G_GetTeam( TEAM_ALPHA ).ent( 0 );
                finalSurvivor.client.addAward( S_COLOR_ORANGE + "You're the final survivor!" );
                String msg = finalSurvivor.client.name + S_COLOR_WHITE + " is the final survivor!";
                G_CenterPrintMsg( null, msg );
                G_PrintMsg( null, msg + "\n");
            }
        }
        else if ( roundTransitionTime != 0 && levelTime > roundTransitionTime ) {
            Infection_StartRound();
        }
      
        

        if ( countdownForRoundStart != 0 ) {

            if ( nextRoundCountdownNumber != 0 && levelTime > countdownForRoundStart - nextRoundCountdownNumber * 1000) {
                
                if (nextRoundCountdownNumber == 4) {
                    int soundIndex = G_SoundIndex( "sounds/announcer/countdown/ready0" + (1 + (rand() & 1)) );
                    G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
                }
                else if (nextRoundCountdownNumber <= 3) {
                    int soundIndex = G_SoundIndex( "sounds/announcer/countdown/" + nextRoundCountdownNumber + "_0" + (1 + (rand() & 1)) );
                    G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
                }

                if (nextRoundCountdownNumber <= 4)
                    G_CenterPrintMsg(null, nextRoundCountdownNumber + "\n" );
                

                nextRoundCountdownNumber--;
            }
        

            if ( levelTime > countdownForRoundStart )
            {
                countdownForRoundStart = 0;
                nextRoundCountdownNumber = 0;

                roundIsBeingPlayed = true;

                roundStartTime = levelTime;
                unfreezeZombies();

                int soundIndex = G_SoundIndex( "sounds/announcer/countdown/go0" + (1 + (rand() & 1)) );
                G_AnnouncerSound( null, soundIndex, GS_MAX_TEAMS, false, null );
                G_CenterPrintMsg( null, "GO!" );
                gametype.shootingDisabled = false;
            }
        }
    }

    GENERIC_UpdateMatchScore();

    if ( match.getState() != MATCH_STATE_PLAYTIME )
        return;

    for ( int i = 0; i < maxClients; i++ )
    {
        Entity @ent = @G_GetClient( i ).getEnt();

        if ( ent.health > ent.maxHealth ) {

            ent.health -= ( frameTime * 0.001f );

            if ( isInfected[ent.playerNum] ) {
                ent.maxHealth = zombieHealth.integer;
                ent.health = zombieHealth.integer;
            }
            // fix possible rounding errors
            if( ent.health < ent.maxHealth ) {
                ent.health = ent.maxHealth;
            }
        }
        if ( ent.health < ent.maxHealth ) {
            if ( !isInfected[ent.playerNum] && lastDamageTime[ent.playerNum] + (regainHealthTimer * 1000) < levelTime ) {
                ent.health += ( frameTime * 0.025f );
                if ( ent.health > ent.maxHealth )
                    ent.health = ent.maxHealth;
            }

        }

        G_ConfigString( CS_GENERAL, "" + G_GetTeam(TEAM_ALPHA).numPlayers );
        G_ConfigString( CS_GENERAL + 1, "" + G_GetTeam(TEAM_BETA).numPlayers );
        
        ent.client.setHUDStat( STAT_MESSAGE_ALPHA, CS_GENERAL );
        ent.client.setHUDStat( STAT_MESSAGE_BETA, CS_GENERAL + 1);

        if (!isInfected[ent.playerNum] && ent.team == TEAM_SPECTATOR )
            isInfected[ent.playerNum] = true;

        if ( ent.client.state() >= CS_SPAWNED && ent.team != TEAM_SPECTATOR )
        {
            if ( !isInfected[ ent.playerNum ] && ent.team != TEAM_ALPHA )
                    ent.team = TEAM_ALPHA;
            if ( isInfected[ent.playerNum] && ent.team != TEAM_BETA ) {
                    ApplyZombieStatus(ent, "Think:");
            }
        }
    }

    if ( @camper != null ) {
        camper.effects |= EF_SHELL;
        camper.client.pmoveFeatures = camper_PMFEATS;
        camper.client.pmoveMaxSpeed = 200;
        camper.client.pmoveDashSpeed = 250;
    }
}

// The game has detected the end of the match state, but it
// doesn't advance it before calling this function.
// This function must give permission to move into the next
// state by returning true.
bool GT_MatchStateFinished( int incomingMatchState )
{
    if ( incomingMatchState == MATCH_STATE_POSTMATCH ) {
        if ( match.scoreLimitHit() )
            return true;
        if ( match.getState() != MATCH_STATE_PLAYTIME )
            return true;
        if ( fallbackDisabled )
            return true;
        if ( amountPlayersPlaying() >= 2 ) {
            if (infectionDebug.boolean)
                G_Print(S_COLOR_ORANGE + "Fallback for players leaving triggered\n");
            G_PrintMsg(null, S_COLOR_RED + "Fallback for players leaving was triggered, restarting round..\n");
            if (G_GetTeam(TEAM_ALPHA).numPlayers == 0 && roundIsBeingPlayed) {
                Infection_EndRound(TEAM_BETA, true);
            }
            if (G_GetTeam(TEAM_BETA).numPlayers == 0 && roundIsBeingPlayed ) {
                Infection_EndRound(TEAM_ALPHA, true);
            }

            // switch random player to other team and restart the round
            Entity @chosenPlayer = randomPlayer();
            int otherTeam = chosenPlayer.client.team == TEAM_ALPHA ? TEAM_ALPHA : TEAM_BETA;
            chosenPlayer.client.team = otherTeam;
            chosenPlayer.team = otherTeam;
            playerTeam[chosenPlayer.playerNum] = otherTeam;
            isInfected[chosenPlayer.playerNum] = !isInfected[chosenPlayer.playerNum];
            chosenPlayer.client.respawn( true );

            Infection_StartRound();
            return false;
        }
    }
    if ( match.getState() <= MATCH_STATE_WARMUP && incomingMatchState > MATCH_STATE_WARMUP
            && incomingMatchState < MATCH_STATE_POSTMATCH )
        match.startAutorecord();

    if ( match.getState() == MATCH_STATE_POSTMATCH )
        match.stopAutorecord();

    return true;
}

// the match state has just moved into a new state. Here is the
// place to set up the new state rules
void GT_MatchStateStarted()
{
    switch ( match.getState() )
    {
    case MATCH_STATE_WARMUP:
        gametype.pickableItemsMask = gametype.spawnableItemsMask;
        gametype.dropableItemsMask = gametype.spawnableItemsMask;

        GENERIC_SetUpWarmup();
		// SpawnIndicators::Create( "info_player_deathmatch", TEAM_BETA );
        break;

    case MATCH_STATE_COUNTDOWN:
        gametype.pickableItemsMask = 0; // disallow item pickup
        gametype.dropableItemsMask = 0; // disallow item drop

        GENERIC_SetUpCountdown();
		// SpawnIndicators::Delete();
        break;

    case MATCH_STATE_PLAYTIME:
        gametype.pickableItemsMask = gametype.spawnableItemsMask;
        gametype.dropableItemsMask = gametype.spawnableItemsMask;


        Infection_StartRound();
        break;

    case MATCH_STATE_POSTMATCH:
        gametype.pickableItemsMask = 0; // disallow item pickup
        gametype.dropableItemsMask = 0; // disallow item drop

        GENERIC_SetUpEndMatch();
        break;

    default:
        break;
    }
}

// the gametype is shutting down cause of a match restart or map change
void GT_Shutdown()
{
}

// The map entities have just been spawned. The level is initialized for
// playing, but nothing has yet started.
void GT_SpawnGametype()
{
    // removeAllEntitiesByClassname("item_health_ultra");
    // removeAllEntitiesByClassname("item_health_mega");

    // removeAllEntitiesByClassname("weapon_machinegun");
    // removeAllEntitiesByClassname("ammo_machinegun");

    changePickupToAmmo("weapon_gunblade", AMMO_GUNBLADE, PICKUP_AMMO_GUNBLADE);
    changePickupToAmmo("weapon_machinegun", AMMO_BULLETS, PICKUP_AMMO_BULLETS);
    changePickupToAmmo("weapon_riotgun", AMMO_SHELLS, PICKUP_AMMO_SHELLS);
    changePickupToAmmo("weapon_grenadelauncher", AMMO_GRENADES, PICKUP_AMMO_GRENADES);
    changePickupToAmmo("weapon_rocketlauncher", AMMO_ROCKETS, PICKUP_AMMO_ROCKETS);
    changePickupToAmmo("weapon_plasmagun", AMMO_PLASMA, PICKUP_AMMO_PLASMA);
    changePickupToAmmo("weapon_lasergun", AMMO_LASERS, PICKUP_AMMO_LASERS);
    changePickupToAmmo("weapon_electrobolt", AMMO_BOLTS, PICKUP_AMMO_BOLTS);
    changePickupToAmmo("weapon_instagun", AMMO_INSTAS, PICKUP_AMMO_INSTAS);

    changePickupToAmmo("ammo_gunblade", AMMO_GUNBLADE, PICKUP_AMMO_GUNBLADE);
    changePickupToAmmo("ammo_machinegun", AMMO_BULLETS, PICKUP_AMMO_BULLETS);
    changePickupToAmmo("ammo_riotgun", AMMO_SHELLS, PICKUP_AMMO_SHELLS);
    changePickupToAmmo("ammo_grenadelauncher", AMMO_GRENADES, PICKUP_AMMO_GRENADES);
    changePickupToAmmo("ammo_rocketlauncher", AMMO_ROCKETS, PICKUP_AMMO_ROCKETS);
    changePickupToAmmo("ammo_plasmagun", AMMO_PLASMA, PICKUP_AMMO_PLASMA);
    changePickupToAmmo("ammo_lasergun", AMMO_LASERS, PICKUP_AMMO_LASERS);
    changePickupToAmmo("ammo_electrobolt", AMMO_BOLTS, PICKUP_AMMO_BOLTS);
    changePickupToAmmo("ammo_instagun", AMMO_INSTAS, PICKUP_AMMO_INSTAS);
}

// Important: This function is called before any entity is spawned, and
// spawning entities from it is forbidden. If you want to make any entity
// spawning at initialization do it in GT_SpawnGametype, which is called
// right after the map entities spawning.

void GT_InitGametype()
{
    gametype.title = "Infection";
    gametype.version = "0.1";
    gametype.author = "algolineu";

    // if the gametype doesn't have a config file, create it
    if ( !G_FileExists( "configs/server/gametypes/" + gametype.name + ".cfg" ) )
    // if ( true )
    {
        String config;

        // the config file doesn't exist or it's empty, create it
        config = "// '" + gametype.title + "' gametype configuration file\n"
                 + "// This config will be executed each time the gametype is started\n"
                 + "\n\n// map rotation\n"
                 + "set g_maplist \"wfdm3 wfdm7 wfdm9 wfdm10 wfdm11 wfdm12 wfdm13 wfdm18 wfda4 wfda5\" // list of maps in automatic rotation\n"
                 + "//set g_maplist \"wfdm3 wfdm7 wfdm9 wfdm10 wfdm11 wfdm12 wfdm13 wfdm18 wfda4 wfda5 acidwdm2 acid3dm7 estatica kodex\" // uncomment for custom maps\n"
                 + "set g_maprotation \"2\"   // 0 = same map, 1 = in order, 2 = random\n"
                 + "\n// game settings\n"
                 + "set g_scorelimit \"11\"\n"
                 + "set g_timelimit \"0\"\n"
                 + "set g_warmup_timelimit \"1\"\n"
                 + "set g_match_extendedtime \"0\"\n"
                 + "set g_allow_falldamage \"1\"\n"
                 + "set g_allow_selfdamage \"1\"\n"
                 + "set g_allow_teamdamage \"0\"\n"
                 + "set g_allow_stun \"1\"\n"
                 + "set g_teams_maxplayers \"0\"\n"
                 + "set g_teams_allow_uneven \"1\"\n"
                 + "set g_countdown_time \"5\"\n"
                 + "set g_maxtimeouts \"0\" // -1 = unlimited\n"
                 + "\necho \"" + gametype.name + ".cfg executed\"\n";

        G_WriteFile( "configs/server/gametypes/" + gametype.name + ".cfg", config );
        G_Print( "Created default config file for '" + gametype.name + "'\n" );
        G_CmdExecute( "exec configs/server/gametypes/" + gametype.name + ".cfg silent" );
    }

    g_disable_vote_rebalance.set("1");
    g_disable_vote_shuffle.set("1");
    g_disable_opcall_rebalance.set("1");
    g_disable_opcall_shuffle.set("1");
    g_teams_allow_uneven.set("1");
    if ( gametype.isInstagib )
        g_instajump.set("0");


    gametype.spawnableItemsMask = ( IT_WEAPON | IT_AMMO );
    if ( gametype.isInstagib )
        gametype.spawnableItemsMask &= ~uint(G_INSTAGIB_NEGATE_ITEMMASK);

    gametype.respawnableItemsMask = gametype.spawnableItemsMask;
    gametype.dropableItemsMask = gametype.spawnableItemsMask;
    gametype.pickableItemsMask = ( gametype.spawnableItemsMask | gametype.dropableItemsMask );

    gametype.isTeamBased = true;
    gametype.isRace = false;
    gametype.hasChallengersQueue = false;
    gametype.maxPlayersPerTeam = 0;

    gametype.weaponRespawn = 10;
    gametype.ammoRespawn = gametype.weaponRespawn;

    // inapplicable
    gametype.armorRespawn = 15;
    gametype.healthRespawn = 10;
    gametype.powerupRespawn = 90;
    gametype.megahealthRespawn = 25;
    gametype.ultrahealthRespawn = 25;

    gametype.readyAnnouncementEnabled = false;
    gametype.scoreAnnouncementEnabled = false;
    gametype.countdownEnabled = false;
    gametype.mathAbortDisabled = false;
    gametype.shootingDisabled = false;
    gametype.infiniteAmmo = false;
    gametype.canForceModels = true;
    gametype.canShowMinimap = false;
    gametype.teamOnlyMinimap = true;


	gametype.mmCompatible = false;
	
    gametype.spawnpointRadius = 256;

    if ( gametype.isInstagib )
        gametype.spawnpointRadius *= 2;

    // set spawnsystem type
    for ( int team = TEAM_PLAYERS; team < GS_MAX_TEAMS; team++ )
        gametype.setTeamSpawnsystem( team, SPAWNSYSTEM_INSTANT, 0, 0, false );

    // define the scoreboard layout
    G_ConfigString( CS_SCB_PLAYERTAB_LAYOUT, "%a l1 %n 112 %s 52 %i 40 %i 40 %i 36 %l 36 %r l1" );
    G_ConfigString( CS_SCB_PLAYERTAB_TITLES, "AVATAR Name Clan Frags Infects MVPs Ping R" );

    // add commands
    //G_RegisterCommand( "kill" );
    G_RegisterCommand( "forceZombieWin" );
    G_RegisterCommand( "forceSurvivorWin" );
    G_RegisterCommand( "forceDrawRound" );
    G_RegisterCommand( "forceRestartRound" );
    G_RegisterCommand( "forceNextmap" );
    G_RegisterCommand( "forceAllBotsZombie" );
    G_RegisterCommand( "join" );
    G_RegisterCommand( "gametype" );
    // G_RegisterCommand( "debugTest" );

    G_RegisterCallvote( "timelimit", "<30-900>", "integer", "Round time limit" );
    G_RegisterCallvote( "spawn_with_mg", "<1 or 0>", "bool", "Survivors spawn with a Machinegun" );
    // G_RegisterCallvote( "next_patientzero", "<player>", "", "Choose the next patient zero (only works in console)" );
    //G_RegisterCallvote( "ca_mode", "<1 or 0>", "bool", "Noob mode" );

    G_Print( "Gametype '" + gametype.title + "' initialized\n" );
    G_GetTeam( TEAM_ALPHA ).name = "SURVIVORS";
    G_GetTeam( TEAM_BETA ).name = "ZOMBIES";
}
