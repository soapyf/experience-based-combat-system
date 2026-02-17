// Experience-Based Combat System region monitor script
// Place this script along with an object containing the configured ebcs_handler.lsl script into an object in your region
// Compile this script with the same experience you compile ebcs_handler.lsl or it will not function correctly

string hud_name = "EBCS HUD v1.2";

// Example safezone coordinates: bottom_southwest, top_northeast
list safezones = [
    <0,0,500>, <256,256,4096>, // Example safezone covering an entire region above 500m
    <232.12500, 226.25000, 25.29415>,<252.71875, 250.75000, 29.25000>,
    <3.93750, 1.93750, 26.12635>,<40.37500, 38.50000, 34.00000>
];

vector attacker_spawn = <243,239,26>; // Example attacker spawn point
vector defender_spawn = <15,13,27>; // Example defender spawn point

integer active_huds;
integer rezqueue = FALSE;


integer have_hud(key id) {
    list attachments = llGetAttachedListFiltered(id, [FILTER_FLAGS, ATTACH_ANY_HUD]);
    integer count = llGetListLength(attachments);
    while (count--) {
        if (llKey2Name(llList2String(attachments, count)) == hud_name) {
            return TRUE;
        }
    }
    return FALSE;
}

integer free_slot(key id) {
    return llList2Integer(llGetObjectDetails(id, [OBJECT_ATTACHED_SLOTS_AVAILABLE]), 0) > 0;
}

integer in_safezone(vector pos) {
    integer count = llGetListLength(safezones);
    integer i;for (; i < count; i += 2) {
        vector bottom_southwest = llList2Vector(safezones, i);
        vector top_northeast = llList2Vector(safezones, i + 1);
        if (pos.x >= bottom_southwest.x && pos.x <= top_northeast.x &&
            pos.y >= bottom_southwest.y && pos.y <= top_northeast.y &&
            pos.z >= bottom_southwest.z && pos.z <= top_northeast.z) {
            return TRUE;
        }
    }
    return FALSE;
}

handle_agent(key agent) {
    string agentData = llLinksetDataRead((string)agent);
    if (agentData == "") {
        agentData = "{}"; 
    }

    // Get the current status of the agent
    string status = llJsonGetValue(agentData, ["status"]); 

    // Check if the agent is part of the experience
    if (llAgentInExperience(agent) && rezqueue == FALSE && status != "hud_rezzed") {
        if (free_slot(agent)) {
            key hud_key = llRezObjectWithParams(hud_name, [
                REZ_FLAGS, REZ_FLAG_TEMP,
                REZ_PARAM_STRING, llList2Json(JSON_OBJECT , [
                    "agent", (string)agent,
                    "attacker_spawn", attacker_spawn,
                    "defender_spawn", defender_spawn,
                    "safezones", llDumpList2String(safezones, "|")
                ])
            ]);
            if(hud_key != NULL_KEY){
                agentData = llJsonSetValue(agentData, ["status"], "hud_rezzed");
                llLinksetDataWrite(hud_key, (string)agent); // Store the hud key with agent key, this will be used to delete the data from the linkset when it is successfully rezzed
            } else {
                rezqueue = TRUE; // Set rezqueue to true to prevent further rez attempts until the next timer event
            }
            
            //llLinksetDataDelete((string)agent);
        } 
        else if (status != "notified") {
            // Notify the agent about the lack of free attachment slots
            llRegionSayTo(agent, 0, "A free attachment slot is required to participate in combat. Please clear an attachment slot.");
            agentData = llJsonSetValue(agentData, ["status"], "notified");
        }
    } else if (status != "experience_permissions_requested") {
        llRequestExperiencePermissions(agent, "");
        agentData = llJsonSetValue(agentData, ["status"], "experience_permissions_requested");
    }

    llLinksetDataWrite((string)agent, agentData);
}

integer valid(key agent)
{
    if(agent == NULL_KEY) return FALSE;
        
    string animation = llGetAnimation(agent);
    string legacyName = llKey2Name(agent); // Ghosted avatars have an empty string
    string displayName = llGetDisplayName(agent); // May not always be non-empty string?
    string userName = llGetUsername(agent); // May not always be non-empty string?
    list attachments = llGetAttachedList(agent);
    
    if(animation == ""
    || animation == "Init"
    || legacyName == ""
    || displayName == ""
    || userName == ""
    || llGetListLength(attachments) == 0){
        return FALSE;
    }
    return TRUE;
}
default {
    state_entry() {
        llRegionSay(-56175,"attach");
        llListen(-5722745, "", "", "");
        llListen(COMBAT_CHANNEL, "", COMBAT_LOG_ID, "");
        llSetTimerEvent(5.0);
        llLinksetDataReset();
        llOwnerSay("Combat System Online.");
    }

    listen(integer channel, string name, key id, string message) {
        if (channel == COMBAT_CHANNEL && id == COMBAT_LOG_ID) {
            list payloads = llJson2List(message);
            integer count = llGetListLength(payloads);
            integer i; for (; i < count; ++i) {
                string payload = llList2String(payloads, i);
                string eventName = llJsonGetValue(payload, ["event"]);
                if (eventName == "DEATH") {
                    vector pos = (vector)llJsonGetValue(payload, ["target_pos"]);
                    key target = llJsonGetValue(payload, ["target"]);
                    if (!have_hud(target) && !in_safezone(pos)) {
                        llTeleportAgentHome(target);
                    }
                }
            }
        }
        else if(channel == -5722745 && llGetOwnerKey(id) == llGetOwner()) {
            if(llJsonGetValue(message, ["command"]) == "clear") {
                key agent = llJsonGetValue(message, ["agent"]);
                if(agent){
                    if(llLinksetDataRead((string)agent)){
                        llLinksetDataDelete((string)agent); // Clear any previous data for the agent
                        llRegionSayTo(agent, 0, "Request recieved...");
                    }
                }
            }
        }
    }

    timer() {
        active_huds = 0;
        list agents = llGetAgentList(AGENT_LIST_REGION, []);
        integer agentCount = llGetListLength(agents);

        while (agentCount--) {
            key agent = llList2Key(agents, agentCount);
            if(valid(agent)){
                if (!have_hud(agent)) {
                    handle_agent(agent);
                } else {
                    active_huds++;
                }
            }
        }

        // We store some data in linkset memory to track if agents have granted experience permissions
        // or if they have been notified about the experience. this is to prevent spamming the agent with notifications.
        //
        // Clear this data if memory reaches over 95% 

        integer percent_used_memory = (131072 - llLinksetDataAvailable()) * 100 / 131072; // Calculate percentage of used memory based off 128 KiB total memory
        if(percent_used_memory > 95){
            llLinksetDataReset(); // Reset linkset data if memory usage exceeds 95%
        }
        // Update display
        llSetText("Active HUDs: " + (string)active_huds +"\nMem: "+(string)percent_used_memory+"%" , <1,1,1>, 1.0);
    }

    object_rez(key id)
    {
        rezqueue = FALSE; // Reset rezqueue flag on object rez event
        key agentData = (key)llLinksetDataRead((string)id);
        if (agentData != NULL_KEY) {
            llLinksetDataDelete((string)agentData); // Delete the agent data associated with this hud
            llLinksetDataDelete((string)id); // Delete the hud data
        }
    }

    experience_permissions(key agent_id) {
        string agentData = llLinksetDataRead((string)agent_id);
        llLinksetDataWrite((string)agent_id, llJsonSetValue(agentData, ["status"], ""));
    }

    experience_permissions_denied(key agent_id, integer reason) {
        string agentData = llLinksetDataRead((string)agent_id); 
        if (llJsonGetValue(agentData, ["status"]) != "notified") {
            llRegionSayTo(agent_id, 0, "By declining the experience, you cannot use the combat system in this region. If you die, you will be teleported home. Ensure you have a free attachment slot. You can see details about the experience and join it here: secondlife:///app/experience/" + llList2String(llGetExperienceDetails(NULL_KEY), 2) + "/profile");
            llLinksetDataWrite((string)agent_id, llJsonSetValue(agentData, ["status"], "notified"));
        }
    }
}
