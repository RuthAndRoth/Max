// max_hud_receiver.lsl - Max v1 HUD Receiver
// SPDX-License-Identifier: MIT
// Copyright 2023 Serie Sumei

// v0.1 - Maxine v1 Draft 1.1

// We make some assumptions about the body linkset that hosts this script:
// * The root object is not any of the body parts. It is common practice to
//   Make the root a small cube and link all of the mesh bits to it.
// * Each link must be named as follows so the script can find them:
//   * 'body'
//   * 'left eye'
//   * 'right eye'
//   * 'eyelashes'
// * Two hand poses may be added to the object inventory, if present they will
//   be started when the script is reset automatically.  They should be priority
//   1 or 2.  The default animations are 05_Bento_LHandRelax3 and 06_Bento_RHandRelax3
//   that may be found in the original Ruth hand pose HUD or in Ruth2 v3+ HUDs.

// The object ID is used to calculate the channel number used for HUD communication
// and must match in both the HUD and receivers
integer OBJ_ID = 20181024; //20231124;

// Listen on multiple channels
integer MULTI_LISTEN = FALSE;

// Only listen when attached
integer ATTACHED_ONLY = TRUE;

// Which API version do we implement?
integer API_VERSION = 2;

// Enumerate the faces in the Max body mesh

list max_body_faces = [
    "feet",
    "hands",
    "head",
    "legs",
    "neck",
    "pelvis",
    "arms",
    "torso"
];

// Map alpha section names and body region names to the link name and face
// <link-name>, <face>, <alpha-section>, <body-region>
integer element_stride = 4;
list element_map = [
    "body", 0, "feet", 2,
    "body", 1, "hands", 1,
    "body", 2, "head", 0,
    "body", 3, "legs", 2,
    "body", 4, "neck", 1,
    "body", 5, "pelvis", 2,
    "body", 6, "arms", 1,
    "body", 7, "torso", 1,

    "left eye", -1, "lefteye", 3,
    "right eye", -1, "righteye", 3,
    "eyelashes", -1, "eyelashes", 8,

    0
];

// Enumerate the body region types as of Bakes on Mesh
// We added our fingernail and toenail types at the end
// The index of this list is the value of <body-region> in the element_map

list body_regions = [
    "head",
    "upper",
    "lower",
    "eyes",
    "skirt",
    "hair",
    "leftarm",
    "leftleg",
    "aux1",
    "aux2",
    "aux3",
    "fnails",
    "tnails"
];

// Any linkset that includes a part named "hands" will run the
// default hand pose
integer has_hands = TRUE;
string hand_animation = "bentohandrelaxedP1";
string hand_animation_left = "05_Bento_LHandRelax3";
string hand_animation_right = "06_Bento_RHandRelax3";

// Refresh hand animation wait, in seconds
// Set to 0.0 to disable the refresh
float hand_refresh = 30.0;

// Map prim name and descriptions to link numbers
list prim_map = [];
list prim_desc = [];

// Spew some info
integer VERBOSE = TRUE;

// Memory limit
integer MEM_LIMIT = 48000;

// The name of the XTEA script
string XTEA_NAME = "max_xtea";

// Set to encrypt 'message' and re-send on channel 'id'
integer XTEAENCRYPT = 13475896;

// Set in the reply to a received XTEAENCRYPT if the passed channel is 0 or ""
integer XTEAENCRYPTED = 8303877;

// Set to decrypt 'message' and reply vi llMessageLinked()
integer XTEADECRYPT = 4690862;

// Set in the reply to a received XTEADECRYPT
integer XTEADECRYPTED = 3450924;

integer haz_xtea = FALSE;

// save the listen handles
integer listen_1;
integer listen_2;
integer channel_1;
integer channel_2;
integer last_attach = 0;

log(string msg) {
    if (VERBOSE == 1) {
        llOwnerSay(msg);
    }
}

// Is the config notecard present in object inventory?
integer can_haz_notecard(string name) {
    integer count = llGetInventoryNumber(INVENTORY_NOTECARD);
    while (count--) {
        if (llGetInventoryName(INVENTORY_NOTECARD, count) == name) {
            log("Found notecard: " + name);
            return TRUE;
        }
    }
    llOwnerSay("Notecard " + name + " not found");
    return FALSE;
}

// Is the XTEA script present in object inventory?
integer can_haz_xtea() {
    integer count = llGetInventoryNumber(INVENTORY_SCRIPT);
    while (count--) {
        if (llGetInventoryName(INVENTORY_SCRIPT, count) == XTEA_NAME) {
            log("XTEA encryption enabled");
            return TRUE;
        }
    }
    return FALSE;
}

send(string msg) {
    llSay(channel_1+1, msg);
    if (VERBOSE == 1) {
        llOwnerSay("S: " + msg);
    }
}

// Send the list of command args as CSV, breaking up into chunks if the
// length exceeds 1000 chars.  Chunked messages have a '+' char prepended
// to the comamnd word (first word in the list) for all but the last chunk.
send_csv(list msg) {
    string strmsg = llList2CSV(msg);
    if (llStringLength(strmsg) > 1000) {
        // break it up
        string cmd = llList2String(msg, 0);
        strmsg = llList2CSV(llList2List(msg, 1, -1));
        do {
            // Send a chunk with a marker on the command
            // Make the chunk a bit smaller than above to allow for command overhead
            send("+" + cmd + "," + llGetSubString(strmsg, 0, 990));
            strmsg = llGetSubString(strmsg, 991, -1);
        } while (llStringLength(strmsg) > 990);
        // Send the remaining bit without the marker so the receiver knows this is the end
        send(cmd + "," + strmsg);
    } else {
        send(strmsg);
    }
}

// Calculate a channel number based on OBJ_ID and owner UUID
integer get_channel(integer id) {
    return 0x80000000 | ((integer)("0x" + (string)llGetOwner()) ^ id);
}

// Create map of all links to prim names
map_linkset() {
    integer i = 0;
    integer num_links = llGetNumberOfPrims() + 1;
    for (; i < num_links; ++i) {
        list p = llGetLinkPrimitiveParams(i, [PRIM_NAME, PRIM_DESC]);
        prim_map += [llToLower(llList2String(p, 0))];
        prim_desc += [llToLower(llList2String(p, 1))];
    }
}

// ALPHA,<target>,<face>,<alpha>
do_alpha(list args) {
    if (llGetListLength(args) > 3) {
        string target = llStringTrim(llToLower(llList2String(args, 1)), STRING_TRIM);
        integer face = llList2Integer(args, 2);
        float alpha = llList2Float(args, 3);
        integer link = llListFindList(prim_map, [target]);
        integer found = FALSE;

        if (target == "all") {
            // Set entire linkset
            integer i;
            integer len = llGetListLength(prim_map);

            for (; i < len; ++i) {
                llSetLinkAlpha(i, alpha, face);
            }
        }
        else if (link >= 0) {
            // Target is a prim name
            llSetLinkAlpha(link, alpha, face);
        }
        else {
            integer region = llListFindList(body_regions, [llToLower(target)]);
            if (region >= 0) {
                // Put a texture on faces belonging to a region
                list e3 = llList2ListStrided(llDeleteSubList(element_map, 0, 2), 0, -1, element_stride);
                integer len = llGetListLength(e3);
                integer i;
                for (; i < len; ++i) {
                    // Look for matching groups in the region
                    if (llList2Integer(e3, i) == region) {
                        // Get link via link name in element_map
                        link = llListFindList(prim_map, [llList2String(element_map, i * element_stride)]);
                        if (link >= 0) {
                            llSetLinkAlpha(
                                link,
                                alpha,
                                llList2Integer(element_map, (i * element_stride) + 1)
                            );
                        }
                    }
                }
            }
            else {
                // Put a texture on faces belonging to a alpha section/group name
                list e2 = llList2ListStrided(llDeleteSubList(element_map, 0, 1), 0, -1, element_stride);
                integer len = llGetListLength(e2);
                integer i;
                for (; i < len; ++i) {
                    if (llList2String(e2, i) == target) {
                        // Get link via link name in element_map
                        link = llListFindList(prim_map, [llList2String(element_map, i * element_stride)]);
                        if (link >= 0) {
                            llSetLinkAlpha(
                                link,
                                alpha,
                                llList2Integer(element_map, (i * element_stride) + 1)
                            );
                        }
                    }
                }
            }
        }
    }
}

// ALPHAMODE,<target>,<face>,<alpha-mode>,<mask-cutoff>
do_alphamode(list args) {
    if (llGetListLength(args) > 4) {
        string target = llStringTrim(llToLower(llList2String(args, 1)), STRING_TRIM);
        integer face = llList2Integer(args, 2);
        integer alpha_mode = llList2Integer(args, 3);
        integer mask_cutoff =  llList2Integer(args, 4);

        integer i;
        integer len = llGetListLength(prim_map);

        for (; i < len; ++i) {
            string name = llList2String(prim_map, i);
            if (name == target || target == "all") {
                llSetLinkPrimitiveParamsFast(i, [
                    PRIM_ALPHA_MODE, face, alpha_mode, mask_cutoff
                ]);
            }
        }
    }
}

// STATUS,<hud-api-version>
do_status(list args) {
    send_csv(["STATUS", API_VERSION, last_attach]);
}

set_texture(string target, integer face, string texture, vector color) {
    integer link = llListFindList(prim_map, [target]);
    if (link >= 0) {
        if (texture != "") {
            llSetLinkPrimitiveParamsFast(
                link,
                [
                    PRIM_TEXTURE,
                    face,
                    texture,
                    <1,1,0>,
                    <0,0,0>,
                    0
                ]
            );
        }
        if (color.x > -1) {
            // Only set if color is valid
            llSetLinkColor(link, color, face);
        }
    }
}

// TEXTURE,<target>,<texture>[,<face>,<color>]
do_texture(list args) {
    // Check for v1 args
    if (llGetListLength(args) >= 3) {
        string target = llStringTrim(llToLower(llList2String(args, 1)), STRING_TRIM);
        string texture = llList2String(args, 2);
        integer face = ALL_SIDES;
        vector color = <-1, 0, 0>;  // not a legal color so we can test for it
        if (llGetListLength(args) > 3) {
            // Get v2 face
            face = llList2Integer(args, 3);
            // Get v2 color arg
            color = (vector)llList2String(args, 4);
        }
        integer region = llListFindList(body_regions, [llToLower(target)]);
        if (region < 0) {
            // Assume target is a prim name
            set_texture(target, face, texture, color);
        } else {
            // Put a texture on faces belonging to a body region
            list e3 = llList2ListStrided(llDeleteSubList(element_map, 0, 2), 0, -1, element_stride);
            integer len = llGetListLength(e3);
            integer i;
            for (; i < len; ++i) {
                // Look for matching groups in the region
                if (llList2Integer(e3, i) == region) {
                    set_texture(
                        llList2String(element_map, i * element_stride),
                        llList2Integer(element_map, (i * element_stride) + 1),
                        texture,
                        color
                    );
                }
            }
        }
    }
}

factory_defaults() {
    // Reset body textures to BoM
    do_texture(["", "head", IMG_USE_BAKED_HEAD]);
    do_texture(["", "upper", IMG_USE_BAKED_UPPER]);
    do_texture(["", "lower", IMG_USE_BAKED_LOWER]);
    do_texture(["", "eyes", IMG_USE_BAKED_EYES]);

    do_alpha(["", "all", ALL_SIDES, 1.0]);
    // Turn off eyelashes until we get textures for them
    do_alpha(["", "eyelashes", ALL_SIDES, 0.0]);

    // Put everything into alpha mask mode to try to ley clothes and hair have the blending order
    do_alphamode(["", "all", ALL_SIDES, PRIM_ALPHA_MODE_MASK, 128]);
}

// Initialization after notecard has been completely read
late_init() {
    has_hands = TRUE;
    if (has_hands) {
        llRequestPermissions(llGetOwner(), PERMISSION_TRIGGER_ANIMATION);
    }

    // Set up listener
    listen_1 = 0;
    listen_2 = 0;
    channel_1 = get_channel(OBJ_ID);
    channel_2 = get_channel(OBJ_ID + 2);
    if (!ATTACHED_ONLY || last_attach > 0) {
        listen_1 = llListen(channel_1, "", "", "");
        if (MULTI_LISTEN) {
            listen_2 = llListen(channel_2, "", "", "");
        }
    }
}

default {
    state_entry() {
        // Set up memory constraints
        llSetMemoryLimit(MEM_LIMIT);

        haz_xtea = can_haz_xtea();

        // Initialize attach state
        last_attach = llGetAttached();
        log("state_entry() attached="+(string)last_attach);

        map_linkset();

//        reading_notecard = FALSE;
//        load_notecard(notecard_name);
        factory_defaults();
        late_init();

        log("Free memory " + (string)llGetFreeMemory() + "  Limit: " + (string)MEM_LIMIT);
    }

    run_time_permissions(integer perm) {
        if (has_hands && (perm & PERMISSION_TRIGGER_ANIMATION)) {
            llStopAnimation(hand_animation_left);
            llStartAnimation(hand_animation_left);
            llStopAnimation(hand_animation_right);
            llStartAnimation(hand_animation_right);
            llSetTimerEvent(hand_refresh);
        }
    }

    timer() {
        if (has_hands) {
            llRequestPermissions(llGetOwner(), PERMISSION_TRIGGER_ANIMATION);
        }
    }

    listen(integer channel, string name, key id, string message) {
        if (llGetOwnerKey(id) == llGetOwner()) {
            if (channel == channel_1 || channel == channel_2) {
                log("R: " + message);
                list cmdargs = llCSV2List(message);
                string command = llToUpper(llList2String(cmdargs, 0));

                if (command == "RESET") {
                    // Reset object to factory defaults
                    factory_defaults();
                }
                else if (command == "ALPHA") {
                    do_alpha(cmdargs);
                }
                else if (command == "ALPHAMODE") {
                    do_alphamode(cmdargs);
                }
                else if (command == "ELEMENTS") {
//                    send_csv(["ELEMENTS", ""]);
  //                    send_csv(["ELEMENTS", llList2Json(JSON_ARRAY, element_map)]);
                }
                else if (command == "RESETANIM") {
                    llRequestPermissions(llGetOwner(), PERMISSION_TRIGGER_ANIMATION);
                }
                else if (command == "STATUS") {
                    do_status(cmdargs);
                }
                else if (command == "TEXTURE") {
                    do_texture(cmdargs);
                }
                else {
                    if (haz_xtea) {
                        llMessageLinked(LINK_THIS, XTEADECRYPT, message, "");
                    }
                }
            }
        }
    }

    link_message(integer sender_number, integer number, string message, key id) {
        if (number == XTEADECRYPTED) {
            list cmdargs = llCSV2List(message);
            string command = llToUpper(llList2String(cmdargs, 0));

                if (command == "RESET") {
                    // Reset object to factory defaults
                    factory_defaults();
                }
                else if (command == "ALPHA") {
                    do_alpha(cmdargs);
                }
                else if (command == "ALPHAMODE") {
                    do_alphamode(cmdargs);
                }
                else if (command == "ELEMENTS") {
//                    send_csv(["ELEMENTS", ""]);
  //                    send_csv(["ELEMENTS", llList2Json(JSON_ARRAY, element_map)]);
                }
                else if (command == "RESETANIM") {
                    llRequestPermissions(llGetOwner(), PERMISSION_TRIGGER_ANIMATION);
                }
                else if (command == "STATUS") {
                    do_status(cmdargs);
                }
                else if (command == "TEXTURE") {
                    do_texture(cmdargs);
                }
        }
    }

    attach(key id) {
        if (id == NULL_KEY) {
            // Reset attach state
            last_attach = 0;
            llListenRemove(listen_1);
            llListenRemove(listen_2);
        } else {
            // Record attach state
            last_attach = llGetAttached();
            late_init();
        }
        log("attach() attached="+(string)last_attach);
    }

    changed(integer change) {
        if (change & (CHANGED_OWNER | CHANGED_INVENTORY)) {
            llResetScript();
        }
    }
}
