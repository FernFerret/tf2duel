#include <sourcemod>
#pragma semicolon 1

#define PLUGIN_VERSION "0.1"

new String:Players[50];

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
    //HookEvent("player_spawn", PlayerSpawnEvent);
}
//public PlayerSpawnEvent(Handle:event, const String:name[], bool:dontBroadcast)
//{
//
//}

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
            new didstrip = StripQuotes(duelstring);
            PrintToServer("Let's do this....'%s' %b", duelstring, didstrip);
            PrintToServer("Let's do this....%d", spaceloc);
        }
    }
    else {
        PrintToServer("nope.avi");
    }
    
    return Plugin_Continue;
}
