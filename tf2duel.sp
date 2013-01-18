#include <sourcemod>
#pragma semicolon 1

#define PLUGIN_VERSION "0.2"

new requests[MAXPLAYERS];
new duels[MAXPLAYERS];
new duelscorea[MAXPLAYERS];
new duelscoreb[MAXPLAYERS];
new String:challengerName[256];
new String:victimName[256];

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
    HookEvent("teamplay_round_win", onRoundOver);
    HookEvent("teamplay_suddendeath_begin", onRoundOver);
}

public onRoundOver(Handle:event, const String:name[], bool:dontBroadcast) {
    for (new i = 1; i <= MaxClients; i++) {
        if (duels[i] != 0) {
            // The challenger is i
            new challenger = i;
            new victim = duels[i];
            getNames(challenger, victim);
            if (duelscorea[challenger] > duelscoreb[challenger]) {
                PrintToChat(victim, "%s defeated %s with a score of %d to %d!", challengerName, victimName , duelscorea[i], duelscoreb[i]);
                PrintToChat(challenger, "%s defeated %s with a score of %d to %d!", challengerName, victimName , duelscorea[i], duelscoreb[i]);
                
            } else if (duelscorea[challenger] < duelscoreb[challenger]) {
                PrintToChat(victim, "%s defeated %s with a score of %d to %d!", victimName, challengerName , duelscoreb[i], duelscorea[i]);
                PrintToChat(challenger, "%s defeated %s with a score of %d to %d!", victimName, challengerName , duelscoreb[i], duelscorea[i]);
            } else {
                PrintToChat(victim, "You're both losers! %s and %s tied with a score of %d to %d!", challengerName, victimName , duelscorea[i], duelscoreb[i]);
                PrintToChat(challenger, "You're both losers! %s and %s tied with a score of %d to %d!", challengerName, victimName , duelscorea[i], duelscoreb[i]);

            }
            // Now reset the duels
            resetDuel(i);
        }
    }
}

public resetDuel(slot) {
    duels[slot] = 0;
    requests[slot] = 0;
    duelscorea[slot] = 0;
    duelscoreb[slot] = 0;
}

public getNames(challenger, victim) {
    if (challenger > 0) {
        GetClientName(challenger, challengerName, 256);
    }
    if (victim > 0) {
        GetClientName(victim, victimName, 256);
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
            duelscorea[i]++;
            increment = true;
            // Make sure we got the right person in the kill
            if (i != attacker) {
                attacker = assister;
            } 
            GetClientName(victim, victimName, 256);
            GetClientName(attacker, challengerName, 256);
        }
        else if (i == victim && ((attacker > 0 && duels[i] == attacker) || (assister > 0 && duels[i] == assister))) {
            PrintToServer("Putting a point in Score B: %d", i);
            PrintToServer("Assister: %d", assister);
            
            duelscoreb[i]++;
            increment = true;
            // Make sure we got the right person in the kill
            if (duels[i] != attacker) {
                attacker = assister;
            } 
            GetClientName(attacker, victimName, 256);
            GetClientName(victim, challengerName, 256);
        }
        if (increment) {
            getNames(attacker, victim);
            PrintToChatAll("The score is: %s: %d, %s:%d", challengerName, duelscorea[i], victimName, duelscoreb[i]);
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
        //TODO: Make this say who.
        PrintToChat(client, "Sorry! %s is already dueling!(%d)", victimName);
        return -1;
    }
    return partner;
}

public isDueling(client) {
    for (new i = 1; i <= MaxClients; i++) {
        // Check the challenger
        if (duels[i] == client) {
            // No, already in a duel
            PrintToServer("Already dueling: %d", i);
            return true;
        }
        if (i == client && duels[i] != 0) {
            // No, already in a duel
            PrintToServer("Already dueling: %d", duels[i]);
            return true;
        }
    }
    PrintToServer("Not dueling!");
    return false;
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
    return Plugin_Continue;
}

public findPlayer(client, const String:search[]) {
    new bool:foundmatch = false;
    new bool:multimatch = false;
    new maxNameLength = 256;
    new clientmatch = 0;
    new duelpartner = -1;
    decl String:nameString[maxNameLength];
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            GetClientName(i, nameString, maxNameLength);
            PrintToServer("Looking at... %s", nameString);
            if (StrContains(nameString, search, false) > -1) {
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
        PrintToChat(client, "Sorry! '%s' matched multiple players! Be more specific!", search);
        return -1;
    }
    if (!foundmatch) {
        PrintToChat(client, "Sorry! '%s' didn't match anyone!", search);
        return -1;
    }
    return clientmatch;
}

public offerDuel(challenger, const String:victimString[]) {
    // Search for a player with a fluffy string (not full name).
    new victim = findPlayer(challenger, victimString);
    // If we don't find a player, return.
    if (victim < 1) {
        return false;
    }
    // Run through another series of checks for valididity
    victim = checkPartner(challenger, victim);
    if (victim < 1) {
        return false;
    }
    // Add a request.
    requests[challenger] = victim;            
    PrintCenterText(victim, "%s has challanged you to a duel!", challengerName);
    PrintToChat(victim, "Type \"!accept\" to Mann Up!");
}

public acceptDuel(victim) {
    if (!isDueling(victim)) {
        for(new i = 1; i < MAXPLAYERS; i++) {
            if (requests[i] == victim) {
                GetClientName(i, challengerName, 256);
                GetClientName(victim, victimName, 256);
                PrintToChat(i, "%s has accepted your duel request!", victimName);
                PrintToChat(victim, "You have accepted %s's duel request!", challengerName);
                duels[i] = victim;
                return true;
            }
        }
    }
    return false;
}
