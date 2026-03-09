vector attacker_spawn;
vector defender_spawn;
vector spawn;
integer safe;
integer target;
list defender_groups = [];

// vector bottom_southwest, vector top_northeast
list safezones = [];

key agent;
key parent;

integer in_safezone(vector pos) {
    integer count = llGetListLength(safezones);
    if (!count) return FALSE;
    integer i;
    for (i = 0; i < count; i += 2) {
        vector bottom_southwest = (vector)llList2String(safezones, i);
        vector top_northeast = (vector)llList2String(safezones, i + 1);
        if (pos.x >= bottom_southwest.x && pos.x <= top_northeast.x &&
            pos.y >= bottom_southwest.y && pos.y <= top_northeast.y &&
            pos.z >= bottom_southwest.z && pos.z <= top_northeast.z) {
            return TRUE;
        }
    }
    return FALSE;
}

integer is_defender(key id) {
    key attached = llList2Key(llGetAttachedList(id),0);
    string group = (string)llGetObjectDetails(attached, [OBJECT_GROUP]);
    
    if (llListFindList(defender_groups, [group]) != -1) return TRUE;
    return FALSE;
}
    


default
{
    on_rez(integer start_param)
    {
        string start = llGetStartString();
        if(start){
            agent = (key)llJsonGetValue(start, ["agent"]);
            attacker_spawn = (vector)llJsonGetValue(start, ["attacker_spawn"]);
            defender_spawn = (vector)llJsonGetValue(start, ["defender_spawn"]);
            safezones = llParseString2List(llJsonGetValue(start, ["safezones"]), ["|"], [""]);
            parent = llList2Key(llGetObjectDetails(llGetKey(), [OBJECT_REZZER_KEY]),0);
        }

        if (agent) {
            if(llGetAttached()){
                llRequestExperiencePermissions(llGetOwner(), "");
            } else {
                llRequestExperiencePermissions(agent, "");
                llSetTimerEvent(30); // Self destruct after 30 seconds if not attached
            }
        }
    }
    attach(key id)
    {
        if(id) {
            llSetTimerEvent(0);
            llTakeControls(CONTROL_FWD | CONTROL_BACK | CONTROL_LEFT | CONTROL_RIGHT | CONTROL_UP | CONTROL_DOWN, TRUE, TRUE);
            llListen(-56175,"","","attach");
            llWhisper(-56175,"attach");
            llOwnerSay("Ready.");
            if(is_defender(agent)) {
                spawn = defender_spawn;
            } else {
                spawn = attacker_spawn;
            }

            target = llTarget(llGetPos(), 3.0);
        }
    }
    not_at_target()
    {
        llTargetRemove(target);
        vector pos = llGetPos();
        safe = in_safezone(pos);
        target = llTarget(pos, 3.0);
    }
    timer()
    {
        if(llGetAgentSize(agent)==ZERO_VECTOR){ llDie(); }
        if(!llGetAttached()) {
            llDie();
        }
    }

    listen(integer channel, string name, key id, string message)
    {
        if (channel == -56175) {
            if(llGetOwnerKey(id) == agent || id == parent){
                if (message == "attach") {
                    llOwnerSay("Detaching");
                    llRequestPermissions(llGetOwner(), PERMISSION_ATTACH | PERMISSION_TAKE_CONTROLS );
                }
            }
        }
    }
    
    experience_permissions(key agent_id)
    {
        if (!llGetAttached()) {
            
            llAttachToAvatarTemp(ATTACH_HUD_TOP_CENTER);
        }
    }
    experience_permissions_denied(key agent_id, integer reason)
    {
        llDie(); 
    }

    // detach from the avatar when we leave the region
    changed(integer change)
    {
        if (change & CHANGED_REGION) {
            llOwnerSay("Detached.");
            llRequestPermissions(agent, PERMISSION_ATTACH);
        }
    }
    run_time_permissions(integer perm)
    {
        if(perm & PERMISSION_ATTACH){
            llDetachFromAvatar();
        }
    }

    on_damage(integer count) {
        if(!safe) return;
        while(count --) { 
            llAdjustDamage(count,0);
        }
    }

    on_death() {
        llTeleportAgent(agent, "", spawn, <128,128,1>);
    }
}
