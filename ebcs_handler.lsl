// This script should be placed inside an object that will be attached to avatars that have granted experience permissions inside your combat region
// After adding this script to an object make sure you compile it with an experience found at the bottom of the script window when editing inside of an object
// Pick up a copy after that and place it inside an object along with the controller script
// It is advised that you set this script to "no modify" to prevent users from tampering with it once its been attached to their avatar

vector attacker_spawn = <244,245,21>;
vector defender_spawn = <8,12,21>;

list defender_groups = [
    "64064c89-25aa-008b-cfe7-0c34e28ae523", 
    "86376bab-a5c9-d551-1866-7f6ac222c96f"
];
// Example safezone coordinates: bottom_southwest, top_northeast
list safezones = [
    <0,0,500>, <256,256,4096>, // Example safezone covering the entire region above z=500
    <0,0,20>, <18,23,28>, // Example safezone in the southwest corner
    <239,234,20>, <255,255,28> // Example safezone in the northeast corner
];

key agent;

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

integer is_defender(key id) {
    list attached_objects = llGetAttachedList(id);
    integer count = llGetListLength(attached_objects);

    integer i;
    for (i = 0; i < count; ++i) {
        key object_id = llList2Key(attached_objects, i);
        list details = llGetObjectDetails(object_id, [OBJECT_GROUP]);
        
        if (llGetListLength(details) > 0) {
            key group_id = llList2Key(details, 0);
            if (llListFindList(defender_groups, [(string)group_id]) != -1) {
                return TRUE; // Object belongs to a defender group
            }
        }
    }
    return FALSE; // No attached objects belong to a defender group
}
    


default
{
    on_rez(integer start_param)
    {
        agent = (key)llGetStartString();
        if (agent) {
            llRequestExperiencePermissions(agent, "");
            llSetTimerEvent(30); // Self destruct after 30 seconds if not attached
        } else if (llGetAttached()) {
            llRequestExperiencePermissions(llGetOwner(), "");
        }
    }
    attach(key id)
    {
        if(id) {
            llSetTimerEvent(0);
            llListen(-56175,"","","attach");
            llWhisper(-56175,"attach");
        }
    }
    timer()
    {
        if(llGetAgentSize(agent)==ZERO_VECTOR){ llDie(); }
        if(!llGetAttached()) {
            llDie();
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
        if (llGetAttached()) {
            llDetachFromAvatar();
        }
        llDie(); 
    }

    // detach from the avatar when we leave the region
    changed(integer change)
    {
        if (change & CHANGED_REGION_START) {
            llRequestPermissions(llGetOwner(), PERMISSION_ATTACH);
        }
    }
    run_time_permissions(integer perm)
    {
        if(perm & PERMISSION_ATTACH){
            llDetachFromAvatar();
        }
    }

    on_damage(integer count) {
        while(count--) {
            if(in_safezone(llGetPos())) {
                llAdjustDamage(count,0);
            }
        }
    }

    on_death() {
        if(!in_safezone(llGetPos())) {
            if(is_defender(llGetOwner())) {
                llTeleportAgent(llGetOwner(), "", defender_spawn, attacker_spawn);
            } else {
                llTeleportAgent(llGetOwner(), "", attacker_spawn, defender_spawn);
            }
        }
    }
}
