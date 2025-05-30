// Place this script in an object located in an easily identifiable location
// Clicking this object will allow avatars that have either denied experience permissions or did not have a free attachment slot to re-attempt a HUD attachment
default
{
    touch_start(integer total_number)
    {
        llRegionSay(-5722745,llList2Json(JSON_OBJECT,[
            "command", "clear",
            "agent", (string)llDetectedKey(0)
        ]));
    }
}
