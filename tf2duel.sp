#include <sourcemod>
#pragma semicolon 1

#define PLUGIN_VERSION "0.1"

new requests[MAXPLAYERS];
new duels[MAXPLAYERS];
new duelscorea[MAXPLAYERS];
new duelscoreb[MAXPLAYERS];

public Plugin:myinfo =
{
    name = "TF2 Duel",
    author = "FernFerret",
    description = "Duel other players! Don't win any prizes!",
    version = PLUGIN_VERSION,
    url = "http://fernferret.github.com"
};

public OnPluginStart()
{
    PrintToServer("Starting the things!");
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say2");
    AddCommandListener(Command_Say, "say_team");
    HookEvent("player_death", onPlayerDeath);
}
public onPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    decl String:challengerName[256];
    decl String:victimName[256];
    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    PrintToChat(victim, "You died.");
    PrintToChat(attacker, "You killed someone.");
    new bool:increment = false;
    for (new i = 1; i <= MaxClients; i++) {
        if (i == attacker && duels[i] == victim) {
            duelscorea[i]++;
            increment = true;
            GetClientName(victim, victimName, 256);
            GetClientName(attacker, challengerName, 256);
        }
        else if (i == victim && duels[i] == attacker) {
            duelscoreb[duels[i]]++;
            increment = true;
            GetClientName(attacker, victimName, 256);
            GetClientName(victim, challengerName, 256);
        }
        if (increment) {
            PrintToChat(victim, "The score is: %s: %d, %s:%d", challengerName, duelscorea[i], victimName, duelscoreb[duels[i]]);
            PrintToChat(attacker, "The score is: %s: %d, %s:%d", challengerName, duelscorea[i], victimName, duelscoreb[duels[i]]);
            break;
        }
    }
}

public playerCanAcceptDuel(victim) {
    for (new i = 1; i <= MaxClients; i++) {
        // Check the challenger
        if (duels[i] == victim) {
            // No, already in a duel
            PrintToServer("Already dueling: %d", i);
            return false;
        }
        if (i == victim && duels[i] != 0) {
            // No, already in a duel
            PrintToServer("Already dueling: %d", duels[i]);
            return false;
        }
    }
    PrintToServer("Not dueling!");
    return true;
}

public isPlayerValid(const String:searchName[], client) {
    // Get the in game clients
    new bool:foundmatch = false;
    new bool:multimatch = false;
    new maxplayers = MaxClients;
    new maxNameLength = 256;
    new clientmatch = 0;
    new duelpartner = -1;
    decl String:nameString[maxNameLength];
    decl String:steamIDString[maxNameLength];
    for (new i = 1; i <= maxplayers; i++) {
        if (IsClientInGame(i)) {
            GetClientName(i, nameString, maxNameLength);
            //GetClientAuthString(i, steamIDString, maxNameLength);
            clientmatch = StrContains(nameString, searchName, false);
            PrintToServer("Looking at... %s", nameString);
            if (clientmatch > -1) {
                if (foundmatch) {
                    multimatch = true;
                }
                // We got a match!
                PrintToServer("Found matching client: %s", nameString);
                foundmatch = true;
                duelpartner = i;
            }
        }
    }
    if (multimatch) {
        PrintToServer("Whoops! Multiple matches!");
        PrintToChat(client, "Sorry! '%s' matched multiple players on the other team! Be more specific!", searchName);
        return -1;
    }
    if (!foundmatch) {
        PrintToChat(client, "Sorry! '%s' didn't match anyone on the other team!", searchName);
        return -1;
    }
    // Ok we have a match. Let's do work!
    if (client == duelpartner) {
        PrintToChat(client, "Sorry! You can't duel yourself!");
        return -1;
    }
    // Get the name
    GetClientName(duelpartner, nameString, maxNameLength);
    // Get the team
    new partnerteam = GetClientTeam(duelpartner);
    new mainteam = GetClientTeam(client);
    if (mainteam < 2) {
        PrintToChat(client, "Sorry! You can't duel from spectator!");
        return -1;
    }
    if (partnerteam < 2) {
        PrintToChat(client, "Sorry! %s isn't on a team!", nameString);
        return -1;
    }
    if (mainteam == partnerteam) {
        PrintToChat(client, "Sorry! You can't duel %s, because they're on your team!", nameString);
        return -1;
    }
    if (!playerCanAcceptDuel(duelpartner)) {
        //TODO: Make this say who.
        PrintToChat(client, "Sorry! %s is already dueling!(%d)", nameString);
        return -1;
    }
    
    PrintToChat(client, "Yay%d! %s", client, nameString);
    return duelpartner;
}

public Action:Command_Say(client, const String:command[], argc){
    PrintToServer("Got it boss!");

    decl String:duelstring[192];
    decl String:challengerName[256];
    decl String:victimName[256];

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
            new partner = isPlayerValid(duelstring, client);
            if (partner < 0) {
                return Plugin_Continue;
            }
            GetClientName(client, challengerName, 256);
            requests[client] = partner;            
            PrintCenterText(partner, "%s has challanged you to a duel!", challengerName);
            PrintToChat(partner, "Type \"!accept\" to Mann Up!");
        }
    }
    thing = StrContains(duelstring[startidx], "!accept", false);
    if (thing == 0) {
        if (playerCanAcceptDuel(client)) {
            for(new i = 1; i < MAXPLAYERS; i++) {
                if (requests[i] == client) {
                    GetClientName(i, challengerName, 256);
                    GetClientName(client, victimName, 256);
                    PrintToChat(i, "%s has accepted your duel request!", victimName);
                    PrintToChat(client, "You have accepted %s's duel request!", challengerName);
                    duels[i] = client;
                }
            }
        }
    } 
    return Plugin_Continue;
}
