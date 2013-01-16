#include <sourcemod>

#define PLUGIN_VERSION "0.1"

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
}

public Action:Command_Say(client, const String:command[], argc){
    PrintToChatAll("Got it boss!");

    decl String:speech[192];

    if (GetCmdArgString(speech, sizeof(speech)) < 1) {
        return Plugin_Continue;
    }

    new startidx = 0;
    
    if (speech[strlen(speech)-1] == '"')
    {
        speech[strlen(speech)-1] = '\0';
        startidx = 1;
    }
    
    if (strcmp(command, "say2", false) == 0)
    {
        startidx += 4;
    }
    if (strcmp(speech[startidx],"!duel",false) == 0) {
        PrintToChatAll("Let's do this....");
    }
    else {
        PrintToChatAll("nope.avi");
        PrintToChatAll(speech[startidx]);
    }
    
    return Plugin_Continue;
}
