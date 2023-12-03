 :CATEGORY:Animation
// :NAME:anim_script
// :AUTHOR:Anonymous
// :CREATED:2010-01-10 05:20:56.000
// :EDITED:2020-08-24
// :ID:36
// :NUM:49
// :REV:1.0
// :WORLD:Second Life
// :DESCRIPTION: 2020-08-24 - Simple script to trigger bentohandrelaxedP1 for any body part with hands
// anim script.lsl
// :CODE:

string anim = "bentohandrelaxedP1";

integer attached = FALSE;  
integer permissions = FALSE;

default {
    state_entry() {
        llRequestPermissions(llGetOwner(),  PERMISSION_TRIGGER_ANIMATION);
    }
    
    run_time_permissions(integer permissions) {
        if (permissions > 0) {
            llStartAnimation(anim);
            attached = TRUE;
            permissions = TRUE;
        }
    }

    attach(key attachedAgent) {
        if (attachedAgent != NULL_KEY) {
            attached = TRUE;
            if (!permissions) {
                llRequestPermissions(llGetOwner(),  PERMISSION_TRIGGER_ANIMATION);   
            }
        } else {
            attached = FALSE;
            llStopAnimation(anim);
        }
    }
}

// END //
