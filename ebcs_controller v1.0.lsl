// Experience-Based Combat System region monitor script

string hud_name = "EBCS HUD v1.0";

// Example safezone coordinates: bottom_southwest, top_northeast
list safezones = [
    <0,0,500>, <256,256,4096> // Example safezone covering an entire region above 500m
];


integer active_huds;



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
    string exp_status = llJsonGetValue(agentData, ["exp_status"]);

    // Check if the agent is part of the experience
    if (llAgentInExperience(agent)) {
        if (free_slot(agent)) {
            llRezObjectWithParams(hud_name, [REZ_PARAM_STRING, (string)agent]);
            llLinksetDataDelete((string)agent);
        } 
        else if (status != "notified") {
            // Notify the agent about the lack of free attachment slots
            llRegionSayTo(agent, 0, "A free attachment slot is required to participate in combat. Please clear an attachment slot.");
            agentData = llJsonSetValue(agentData, ["status"], "notified");
        }
    } else if (exp_status != "requested") {
        llRequestExperiencePermissions(agent, "");
        agentData = llJsonSetValue(agentData, ["exp_status"], "requested");
    }

    llLinksetDataWrite((string)agent, agentData);
}

default {
    state_entry() {
        llListen(-5722745, "", "", "");
        llListen(COMBAT_CHANNEL, "", COMBAT_LOG_ID, "");
        llSetTimerEvent(5.0);
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
                        llRegionSayTo(agent, 0, "Re-sending experience permissions request...");
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
            if (!have_hud(agent)) {
                handle_agent(agent);
            } else {
                active_huds++;
            }
        }

        // We store some data in linkset memory to track if agents have granted experience permissions
        // or if they have been notified about the experience. this is to prevent spamming the agent with notifications.
        //
        // This data shouldnt be filled up since its deleted when an agent grants permissions but we check it anyway.

        integer percent_used_memory = (131072 - llLinksetDataAvailable()) * 100 / 131072; // Calculate percentage of used memory based off 128 KiB total memory
        if(percent_used_memory > 95){
            llLinksetDataReset(); // Reset linkset data if memory usage exceeds 95%
        }
        // Update display
        llSetText("Active HUDs: " + (string)active_huds +"\nMem: "+(string)percent_used_memory+"%" , <1,1,1>, 1.0);
    }

    experience_permissions(key agent_id) {
        string agentData = llLinksetDataRead((string)agent_id);
        llLinksetDataWrite((string)agent_id, llJsonSetValue(agentData, ["status"], ""));
    }

    experience_permissions_denied(key agent_id, integer reason) {
        string agentData = llLinksetDataRead((string)agent_id); 
        if (llJsonGetValue(agentData, ["status"]) != "notified") {
            llRegionSayTo(agent_id, 0, "By declining the experience, you cannot use the combat system in this region. If you die, you will be teleported home. To join click an experience kiosk and ensure you have a free attachment slot.");
            llLinksetDataWrite((string)agent_id, llJsonSetValue(agentData, ["status"], "notified"));
        }
    }
}


