#include <sourcemod>
#include <tf2>
#include <morecolors>
#include <clientprefs>
#include <sdktools>
#pragma semicolon 1

#define PLUGIN_VERSION "0.2"
#define CHALLENGE_SND         "ui/duel_challenge.wav"
#define CHALLENGE_ACCEPT_SND  "ui/duel_challenge_accepted.wav"
#define DUEL_SCORE_SND        "ui/duel_event.wav"
#define DUEL_SCORE_BEHIND_SND "ui/duel_score_behind.wav"


const MAXNAMELENGTH = 256;

new requests[MAXPLAYERS];
new duels[MAXPLAYERS];
new dsChallenger[MAXPLAYERS];
new dsVictim[MAXPLAYERS];
new String:challengerName[MAXNAMELENGTH];
new String:victimName[MAXNAMELENGTH];
new String:lastToDisconnectName[MAXNAMELENGTH];
new lastToDisconnect = 0;
new Handle:autoduelCookie = INVALID_HANDLE;

public Plugin:myinfo = {
    name = "TF2 Duel",
    author = "FernFerret",
    description = "Duel other players! Don't win any prizes!",
    version = PLUGIN_VERSION,
    url = "http://fernferret.github.com"
};

public OnPluginStart() {
    PrintToServer("Starting the things!");
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say2");
    AddCommandListener(Command_Say, "say_team");
    HookEvent("player_death", onPlayerDeath);
    HookEvent("player_team", onChangeTeam);
    //HookEvent("player_team", onChangeTeam, EventHookMode_Pre);
    HookEvent("player_disconnect", onPlayerDisconnect);
    HookEvent("teamplay_round_win", onRoundOver);
    HookEvent("teamplay_suddendeath_begin", onRoundOver);

    autoduelCookie = RegClientCookie("autoduel", "Auto Duel Enabled", CookieAccess_Protected);
    cacheSounds();
}

public OnMapStart() {
    cacheSounds();
}

public cacheSounds() {
    PrecacheSound(CHALLENGE_SND);
    PrecacheSound(CHALLENGE_ACCEPT_SND);
    PrecacheSound(DUEL_SCORE_SND);
    PrecacheSound(DUEL_SCORE_BEHIND_SND);
}

public onRoundOver(Handle:event, const String:name[], bool:dontBroadcast) {
    finalizeDuels();
}

public Action:onPlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast) {
    lastToDisconnect = GetClientOfUserId(GetEventInt(event, "userid"));
    GetClientName(lastToDisconnect, lastToDisconnectName, MAXNAMELENGTH);
    return Plugin_Continue;
}
public Action:onChangeTeam(Handle:event, const String:name[], bool:dontBroadcast) {
    new oldteam = GetEventInt(event, "oldteam");
    new newteam = GetEventInt(event, "team");
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new bool:disconnect = GetEventBool(event, "disconnect");
    if (disconnect) {
        client = lastToDisconnect;
        lastToDisconnect = 0;
    }
    // If they're not dueling, we don't care.
    if (!isDueling(client)) {
        return Plugin_Continue;
    }
    // Somehow, they didn't actually change teams.
    if (oldteam == newteam) {
        return Plugin_Continue;
    }
    overrideDuel(client, disconnect);
    return Plugin_Continue;
}

public finalizeDuels() {
    for (new i = 1; i <= MaxClients; i++) {
        if (duels[i] != 0) {
            // The challenger is i
            new challenger = i;
            new victim = duels[i];
            getNames(challenger, victim);
            if (dsChallenger[challenger] > dsVictim[challenger]) {
                PrintToChatAll("%s defeated %s with a score of %d to %d!", challengerName, victimName , dsChallenger[i], dsVictim[i]);
            } else if (dsChallenger[challenger] < dsVictim[challenger]) {
                PrintToChatAll("%s defeated %s with a score of %d to %d!", victimName, challengerName , dsVictim[i], dsChallenger[i]);
            } else {
                PrintToChatAll("You're both losers! %s and %s tied with a score of %d to %d!", challengerName, victimName , dsChallenger[i], dsVictim[i]);
            }
        }
        // Now reset the duels, regardless if the duelstatus was set.
        resetDuel(i);
    }
}

// Used if a player changes or disconnects
public overrideDuel(loser, disconnect) {
    new partner = getDuelPartner(loser);
    new duelid = getDuelId(loser);
    if (partner < 1 || duelid < 1) {
        return false;
    }
    // Override the names because disconnect is wonky
    if (disconnect) {
        getNames(-1, partner);
        challengerName = lastToDisconnectName;
    } else {
        getNames(loser, partner);
    }
    if (isChallenger(loser) == 1) {
        if(dsChallenger[duelid] >= dsVictim[duelid]) {
            // Reset the score because this guy was in the lead.
            dsChallenger[duelid] = 0;
            if (dsVictim[duelid] == 0) {
                dsVictim[duelid] = 1;
            }
        }
        PrintToChatAll("%s chickened out, so %s won with a score of %d to %d!1", challengerName, victimName, dsVictim[duelid], dsChallenger[duelid]);
    } else {
        if(dsChallenger[duelid] <= dsVictim[duelid]) {
            // Reset the score because this guy was in the lead.
            dsVictim[duelid] = 0;
            if (dsChallenger[duelid] == 0) {
                dsChallenger[duelid] = 1;
            }
        }
        PrintToChatAll("%s chickened out, so %s won with a score of %d to %d!", challengerName, victimName, dsChallenger[duelid], dsVictim[duelid]);
    }
    // Reset this duelid
    resetDuel(duelid);
    return true;
}

// Used so you can see if this guy, or the
// other guy is the one that holds the score
// Returns 1 for client being the challenger
// 0 if it's not client, and -1 if client
// wasn't dueling.
public isChallenger(client) {
    for (new i = 1; i <= MaxClients; i++) {
        if (duels[i] == client) {
            return 0;
        }
        if (i == client && duels[i] != 0) {
            return 1;
        }
    }
    return -1;
}
// Returns the ID of the duel for the player given,
// even if they didn't start the duel
public getDuelId(client) {
    for (new i = 1; i <= MaxClients; i++) {
        if (duels[i] == client) {
            return i;
        }
        if (i == client && duels[i] != 0) {
            return i;
        }
    }
    return -1;
}

public resetDuel(slot) {
    duels[slot] = 0;
    requests[slot] = 0;
    dsChallenger[slot] = 0;
    dsVictim[slot] = 0;
}

public getNames(challenger, victim) {
    if (challenger > 0) {
        GetClientName(challenger, challengerName, MAXNAMELENGTH);
    }
    if (victim > 0) {
        GetClientName(victim, victimName, MAXNAMELENGTH);
    }
}

public onPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    new assister = GetClientOfUserId(GetEventInt(event, "assister"));
    new bool:increment = false;
    for (new i = 1; i <= MaxClients; i++) {
        if (((attacker > 0 && i == attacker) || (assister > 0 && assister == i)) && duels[i] == victim) {
            PrintToServer("Putting a point in Score A: %d", i);
            PrintToServer("Assister: %d", assister);
            dsChallenger[i]++;
            increment = true;
            // Make sure we got the right person in the kill
            if (i != attacker) {
                attacker = assister;
            }
            // Don't Call getNames here!
            GetClientName(victim, victimName, MAXNAMELENGTH);
            GetClientName(attacker, challengerName, MAXNAMELENGTH);
        }
        else if (i == victim && ((attacker > 0 && duels[i] == attacker) || (assister > 0 && duels[i] == assister))) {
            PrintToServer("Putting a point in Score B: %d", i);
            PrintToServer("Assister: %d", assister);

            dsVictim[i]++;
            increment = true;
            // Make sure we got the right person in the kill
            if (duels[i] != attacker) {
                attacker = assister;
            }
            // Don't Call getNames here!
            GetClientName(attacker, victimName, MAXNAMELENGTH);
            GetClientName(victim, challengerName, MAXNAMELENGTH);
        }
        if (increment) {
            playScoreSounds(attacker, victim);
            // Don't Call getNames here!
            // We're doing shenanigans with the names.

            PrintToChatAll("The score is: %s: %d, %s: %d", challengerName, dsChallenger[i], victimName, dsVictim[i]);
            break;
        }
    }
}

public playScoreSounds(attacker, victim) {
    for (new i = 1; i <= MaxClients; i++) {
        // If it's not an empty duel, and one or the other is the guy, we've found it
        if (duels[i] != 0 && (attacker == i || victim == i)) {
            new challenger = -1;
            // Sort out who is who for score comparison
            if (attacker == i) {
                challenger = attacker;
            } else {
                challenger = victim;
                victim = attacker;
            }
            // The challenger's score is in A
            if (dsChallenger[challenger] > dsVictim[challenger]) {
                EmitSoundToClient(challenger, DUEL_SCORE_SND);
                EmitSoundToClient(victim, DUEL_SCORE_BEHIND_SND);
            } else if (dsChallenger[challenger] < dsVictim[challenger]) {
                EmitSoundToClient(challenger, DUEL_SCORE_BEHIND_SND);
                EmitSoundToClient(victim, DUEL_SCORE_SND);
            } else {
                EmitSoundToClient(challenger, DUEL_SCORE_SND);
                EmitSoundToClient(victim, DUEL_SCORE_SND);
            }
            break;
        }
    }
}

public checkPartner(client, partner) {
    if (client == partner) {
        PrintToChat(client, "Sorry! You can't duel yourself!");
        return -1;
    }
    // Get the name
    getNames(-1, partner);
    // Get the team
    new partnerteam = GetClientTeam(partner);
    new clientteam = GetClientTeam(client);
    if (clientteam < 2) {
        PrintToChat(client, "Sorry! You can't duel from spectator!");
        return -1;
    }
    if (partnerteam < 2) {
        PrintToChat(client, "Sorry! %s isn't on a team!", victimName);
        return -1;
    }
    if (clientteam == partnerteam) {
        PrintToChat(client, "Sorry! You can't duel %s, because they're on your team!", victimName);
        return -1;
    }
    if (isDueling(partner)) {
        //Get the name of the person who the victim is already dueling!
        getNames(getDuelPartner(partner), -1);
        PrintToChat(client, "Sorry! %s is already dueling %s!", victimName, challengerName);
        return -1;
    }
    return partner;
}

public bool:isDueling(client) {
    if (client < 1) {
        return false;
    }
    if (getDuelPartner(client) != -1) {
        return true;
    }
    return false;
}

public getDuelPartner(client) {
    for (new i = 1; i <= MaxClients; i++) {
        // Check the challenger
        if (duels[i] == client) {
            // No, already in a duel
            PrintToServer("Already dueling: %d", i);
            return i;
        }
        if (i == client && duels[i] != 0) {
            // No, already in a duel
            PrintToServer("Already dueling: %d", duels[i]);
            return duels[i];
        }
    }
    PrintToServer("Not dueling!");
    return -1;
}

public Action:Command_Say(client, const String:command[], argc){
    PrintToServer("Got it boss!");

    decl String:duelstring[192];

    if (GetCmdArgString(duelstring, sizeof(duelstring)) < 1) {
        return Plugin_Continue;
    }
    new startidx = 0;

    if (duelstring[strlen(duelstring)-1] == '"')
    {
        duelstring[strlen(duelstring)-1] = '\0';
        startidx = 1;
    }

    if (strcmp(command, "say2", false) == 0)
    {
        startidx += 4;
    }
    new thing = StrContains(duelstring[startidx], "!duel", false);
    if (thing == 0) {
        // They DID start with !duel
        new spaceloc = StrContains(duelstring[startidx], " ", false);
        if (spaceloc != -1) {
            // Cool, there's a space, they gave a name! get that name!
            ReplaceString(duelstring, 192, "!duel ", "", false);
            ReplaceString(duelstring, 192, "\"", "", false);
            offerDuel(client, duelstring);
        }
    }
    thing = StrContains(duelstring[startidx], "!accept", false);
    if (thing == 0) {
        acceptDuel(client);
    }
    thing = StrContains(duelstring[startidx], "!autoduel", false);
    if (thing == 0) {
        setAutoAccept(client);
    }
    return Plugin_Continue;
}

public findPlayer(client, const String:search[]) {
    new bool:foundmatch = false;
    new bool:multimatch = false;
    new clientteam = GetClientTeam(client);
    new matchteam = -1;
    new searchteam = _:TFTeam_Red;
    if (clientteam == searchteam) {
        searchteam = _:TFTeam_Blue;
    }
    new clientmatch = -1;
    decl String:nameString[MAXNAMELENGTH];
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            GetClientName(i, nameString, MAXNAMELENGTH);
            // Eliminate some work by removing other team players.
            matchteam = GetClientTeam(i);
            PrintToServer("Looking at... %s", nameString);
            if (matchteam == searchteam && StrContains(nameString, search, false) > -1) {
                if (foundmatch) {
                    multimatch = true;
                }
                // We got a match!
                PrintToServer("Found matching client: %s", nameString);
                foundmatch = true;
                clientmatch = i;
            }
        }
    }
    if (multimatch) {
        PrintToServer("Whoops! Multiple matches!");
        PrintToChat(client, "Sorry! '%s' matched multiple players on the other team! Be more specific!", search);
        return -1;
    }
    if (!foundmatch) {
        PrintToChat(client, "Sorry! '%s' didn't match anyone!", search);
        return -1;
    }
    return clientmatch;
}

public bool:offerDuel(challenger, const String:victimString[]) {
    // Search for a player with a fluffy string (not full name).
    new victim = findPlayer(challenger, victimString);
    // If we don't find a player, return.
    if (victim < 1) {
        return false;
    }
    // Make sure the person found didn't duel us first!
    //If so, we fraking accept!
    if (requests[victim] == challenger) {
        acceptDuel(challenger);
        return false;
    }
    // Make sure someone hasn't already requested a duel
    getNames(challenger, victim);
    if (hasOpenRequest(victim)) {
        PrintToChat(challenger, "%s has already been asked to duel, try again later!", victimName);
        return false;
    }
    // Add a request.
    requests[challenger] = victim;
    PrintCenterText(victim, "%s has challenged you to a duel!", challengerName);
    PrintToChat(victim, "Type \"!accept\" to Mann Up!");
    EmitSoundToClient(victim, CHALLENGE_SND);
    EmitSoundToClient(challenger, CHALLENGE_SND);
    CreateTimer(2.0, autoAcceptRequest, challenger);
    CreateTimer(20.0, autoCancelRequest, challenger);
    return true;
}

// Cancel the request, either manually or automatically!
// returns true on a cancel, false if the duel is already going on.
public Action:autoCancelRequest(Handle:timer, any:challenger) {
    return cancelRequest(challenger);
}

public bool:setAutoAccept(client) {
    new String:cookie[4];
    new String:color[16];
    GetClientCookie(client, autoduelCookie, cookie, sizeof(cookie));
    if (StrEqual(cookie, "on")) {
        cookie = "off";
        color = "{red}";
    } else if(StrEqual(cookie, "off")) {
        cookie = "on";
        color = "{green}";
    } else {
        cookie = "off";
        color = "{red}";
        // Set cookie if client connects the first time
    }
    CPrintToChat(client, "{springgreen}Auto Duel {white}has been turned %s%s{white}!", color, cookie);
    SetClientCookie(client, autoduelCookie, cookie);
}

public Action:autoAcceptRequest(Handle:timer, any:challenger) {
    new String:cookie[4];
    GetClientCookie(requests[challenger], autoduelCookie, cookie, sizeof(cookie));
    if (StrEqual(cookie, "on")) {
        acceptDuel(requests[challenger]);
        return Plugin_Continue;
    } else if(StrEqual(cookie, "off")) {
        return Plugin_Continue;
    } else {
        // Set cookie if client connects the first time
        SetClientCookie(requests[challenger], autoduelCookie, "off");
    }
    return Plugin_Continue;
}



public Action:cancelRequest(any:challenger) {
    //PrintToChatAll("Maybe no duel?");
    if (duels[challenger] != 0) {
        return Plugin_Continue;
    }
    if (requests[challenger] == 0) {
        // there was nothing
        return Plugin_Continue;
    }
    new victim = requests[challenger];
    requests[challenger] = 0;
    getNames(challenger, victim);
    PrintToChatAll("%s is far too cowardly to duel %s. For. Shame.", victimName, challengerName);
    return Plugin_Continue;
}

public bool:hasOpenRequest(victim) {
    for(new i = 1; i < MaxClients; i++) {
        if (requests[i] == victim) {
            return true;
        }
    }
    return false;

}

public acceptDuel(victim) {
    if (!isDueling(victim)) {
        for(new i = 1; i < MaxClients; i++) {
            if (requests[i] == victim) {
                getNames(i, victim);
                PrintToChatAll("%s has accepted %s's duel request!", victimName, challengerName);
                duels[i] = victim;
                EmitSoundToClient(i, CHALLENGE_ACCEPT_SND);
                EmitSoundToClient(victim, CHALLENGE_ACCEPT_SND);
                return true;
            }
        }
    }
    return false;
}
