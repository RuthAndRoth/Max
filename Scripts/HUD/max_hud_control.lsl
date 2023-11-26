// max_hud_control.lsl - Max HUD Controller
// SPDX-License-Identifier: MIT
// Copyright 2023 Serie Sumei

// v0.1 - Maxine v1 Draft 1.1

// Older OpenSimulator builds may not have the PRIM_ALPHA_MODE_*
// constants defined.  If you get a compiler error that these are not defined
// uncomment the following lines:
// integer PRIM_ALPHA_MODE_NONE = 0;
// integer PRIM_ALPHA_MODE_BLEND = 1;
// integer PRIM_ALPHA_MODE_MASK = 2;
// integer PRIM_ALPHA_MODE_EMISSIVE = 3;

// The object ID is used to calculate the channel number used for HUD communication
// and must match in both the HUD and receivers
integer OBJ_ID = 20181024; //20231124;

// Which API version do we implement?
integer API_VERSION = 2;

// Spew log info
integer VERBOSE = FALSE;

// Memory limit
integer MEM_LIMIT = 65000;

// HUD colors
vector alphaOnColor = <0.000, 0.000, 0.000>;
vector buttonOnColor = <0.400, 0.700, 0.400>;
vector faceOnColor = <0.800, 1.000, 0.800>;
vector offColor = <1.000, 1.000, 1.000>;

// ****************************************
// HUD Positioning

// HUD Positioning offsets
float bottom_offset = 0.78;
float center_offset = 0.00;
float left_offset = -0.17;
float right_offset = 0.24;
float top_offset = -0.20;

integer last_attach = 0;
integer attach_bottom = FALSE;

do_hide(integer minimize) {
    log("hide("+(string)minimize+") attach_bottom: "+(string)attach_bottom);
    if (minimize) {
        float rot = PI_BY_TWO;
//#        if (!attach_bottom) {
            rot *= -1;
//#        }
        rotation localRot = llList2Rot(llGetLinkPrimitiveParams(LINK_ROOT, [PRIM_ROT_LOCAL]), 0);
        llSetLinkPrimitiveParamsFast(LINK_ROOT, [PRIM_ROT_LOCAL, llEuler2Rot(<0.0, 0.0, rot>)*localRot]);
    } else {
        llSetLinkPrimitiveParamsFast(LINK_ROOT, [PRIM_ROT_LOCAL, ZERO_ROTATION]);
    }
//    set_text(!minimize);
}

// ****************************************
// HUD Rotation

// HUD page rotations
vector MIN_ROT = <0.0, 0.0, 0.0>;
vector ALPHA_ROT = <0.0, PI_BY_TWO, 0.0>;
vector OPTION_ROT = <0.0, -PI_BY_TWO, PI>;
vector SKIN_ROT = <PI_BY_TWO, 0.0, -PI_BY_TWO>;
vector SET_ROT = <-PI_BY_TWO, 0.0, PI_BY_TWO>;
vector last_rot;

// ****************************************
// XTEA Configuration

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

// ****************************************
// Mesh Configuration Variables

// A JSON buffer to save the alpha values of elements:
// key - element name
// value - 16-bit alpha values, 1 bit per face: 0 == visible, 1 == invisible
// Note this representation is opposite of the usage in the rest of this script where
// alpha values are integer representations of the actual face alpha float
string current_alpha = "{}";

// Alpha HUD button map
// These are also used as section names in mapping alpha sections in the mesh
list alpha_buttons = [
    // alpha0
    "",
    "head",
    "neck",
    "arms",
    "hands",
    "fingernails",
    "",
    "hide",
    // alpha1
    "",
    "torso",
    "pelvis",
    "legs",
    "feet",
    "toenails",
    "",
    "show"
];

// Hand poses
string hp_last_right = "";
string hp_last_left = "";
integer hp_index = 0;
integer do_hp = FALSE;

// Foot poses
integer fp_offset = 30;     // Add to the fp1 index (face) to get the actual anim in inventory
string fp_last = "";
integer fp_index = 0;
integer do_fp = FALSE;

// Ankle lock
string AnkleLockAnim = "30_anklelock";      // The index value must match the fp_offset above
integer AnkleLockEnabled = FALSE;
integer anklelock_link = 0;
integer anklelock_face = 4;

// ***
// Skin / Bakes on Mesh
integer current_skin = -1;
integer current_eye = -1;
integer alpha_mode;
integer mask_cutoff = 128;

// Map skin selections to button faces
// Stride 2: <sk0+N>, <face>
list skin_button_faces = [
    // 0, 0,    unused
    // 0, 2,    BoM
    0, 4,
    0, 6,
    1, 0,
    1, 2,
    1, 4,
    // 1, 6,    unused
    // 2, 0,    unused
    2, 2,
    2, 4,
    2, 6,
    3, 0,
    3, 2,
    3, 4
    // 3, 6,    unused
];

// Map eye selections to button faces
// Stride 2: <eye0+N>, <face>
list eye_button_faces = [
    // 0, 0,    unused
    // 0, 2,    BoM
    0, 4,
    0, 6,
    1, 0,
    1, 2,
    1, 4
    // 1, 6,    unused
];

// ***

// ****************************************
// State Variables

// Alpha settings for 'on' nails: [top, under, tip]
list nail_alpha = [0.20, 1.00, 0.80];

// Configured values read from notecard
list nail_colors;
string nail_texture;

// Save last selected color
vector fingernail_color = ZERO_VECTOR;
vector toenail_color = ZERO_VECTOR;

// Nail BoM channels
string FINGERNAILS_BOM = IMG_USE_BAKED_AUX1;
string TOENAILS_BOM = IMG_USE_BAKED_AUX2;

// Keep a mapping of link number to prim name
list link_map = [];

integer num_links = 0;

// Ruth link messages
integer LINK_RUTH_HUD = 40;
integer LINK_RUTH_APP = 42;

integer max_channel;
integer visible_fingernails = 0;

// ****************************************
// Button Handler

button(integer link, integer face, vector pos, integer long) {
    string name = llGetLinkName(link);
    log("button() name: " + name + "  face: " + (string)face + "  pos: " + (string)pos);

    if (name == "minbar" && long) {
        // RESET button
        llResetScript();
    }
    else if (name == "minbar" || name == "navbar") {
        integer bx = (integer)(pos.x * 10);
        integer by = (integer)(pos.y * 10);
        log("x,y="+(string)bx+","+(string)by);

        if (name == "minbar") {
            // on min
            log("init");
            vector next_rot;
            vector current_rot = llRot2Euler(llList2Rot(llGetLinkPrimitiveParams(LINK_ROOT,[PRIM_ROT_LOCAL]),0));
            log("currot: " + (string)current_rot);
            log("lastrot: " + (string)last_rot);
            if (current_rot == MIN_ROT && last_rot == MIN_ROT) {
                // No history, go to options
                next_rot = OPTION_ROT;
            } else {
                next_rot = last_rot;
            }
            log("nextrot: " + (string)next_rot);
            llSetLinkPrimitiveParamsFast(LINK_ROOT,[PRIM_ROT_LOCAL,llEuler2Rot(next_rot)]);
            last_rot = current_rot;
        }
        else if (bx == 0 || bx == 8) {
            // min
            log("minrot");
            llSetLinkPrimitiveParamsFast(LINK_ROOT,[PRIM_ROT_LOCAL,llEuler2Rot(MIN_ROT)]);
            // Don't save this!
            //last_rot = MIN_ROT;
        }
        else if (bx == 1) {
            // settings
            log("setrot");
            llSetLinkPrimitiveParamsFast(LINK_ROOT,[PRIM_ROT_LOCAL,llEuler2Rot(SET_ROT)]);
            last_rot = SET_ROT;
        }
        else if (bx == 2 || bx == 3) {
            // alpha
            log("alpharot");
            llSetLinkPrimitiveParamsFast(LINK_ROOT,[PRIM_ROT_LOCAL,llEuler2Rot(ALPHA_ROT)]);
            last_rot = ALPHA_ROT;
        }
        else if (bx == 4 || bx == 5) {
            // skin
            log("skinrot");
            llSetLinkPrimitiveParamsFast(LINK_ROOT,[PRIM_ROT_LOCAL,llEuler2Rot(SKIN_ROT)]);
            last_rot = SKIN_ROT;
        }
        else if (bx == 6 || bx == 7) {
            // options
            log("optionrot");
            llSetLinkPrimitiveParamsFast(LINK_ROOT,[PRIM_ROT_LOCAL,llEuler2Rot(OPTION_ROT)]);
            last_rot = OPTION_ROT;
        }
        else if (bx == 9) {
            log("DETACH!");
            llRequestPermissions(llDetectedKey(0), PERMISSION_ATTACH);
        }
    }
    else if (llGetSubString(name, 0, 4) == "alpha") {
        integer b = ((integer)llGetSubString(name, 5, -1));
        if (b == 1 && face == 6) {
            // Hide all
            reset_alpha(0.0);
        }
        else if (b == 3 && face == 6) {
            // Show all
            reset_alpha(1.0);
        }
        else {
            set_alpha_section(llList2String(alpha_buttons, (b * 4) + (face >> 1)), -1);

            // Set button color
            vector face_color = llList2Vector(llGetLinkPrimitiveParams(link, [PRIM_NAME, PRIM_COLOR, face]), 1);
            set_outline_link_face_state("alpha", b, face, 1.0, (face_color == offColor));
        }
    }
    else if (llGetSubString(name, 0, 4) == "amode") {
        // Alpha Mode
        if (face == 2) {
            // Alpha Masking
            alpha_mode = PRIM_ALPHA_MODE_MASK;
            set_outline_link_face_state("amode", 0, 2, 1.0, TRUE);
            set_outline_link_face_state("amode", 0, 4, 1.0, FALSE);
        }
        else if (face == 4) {
            // Alpha Blending
            alpha_mode = PRIM_ALPHA_MODE_BLEND;
            set_outline_link_face_state("amode", 0, 2, 1.0, FALSE);
            set_outline_link_face_state("amode", 0, 4, 1.0, TRUE);
        }
        string cmd = llList2CSV(["ALPHAMODE", "all", -1, alpha_mode, mask_cutoff]);
        log(cmd);
        send(cmd);
    }
    else if (llGetSubString(name, 0, 1) == "sk") {
        // Skin appliers
        integer b = (integer)llGetSubString(name, 2, -1);
        // BoM button is hard coded to xlink 0, face 2
        if (b == 0 && face == 2) {
            // Skin Bakes on Mesh
            if (current_skin >= 0) {
                set_outline_button_state(skin_button_faces, "sk", current_skin, FALSE);
            }
            current_skin = -1;
            set_outline_link_face_state("sk", b, face, 1.0, TRUE);
            llMessageLinked(LINK_THIS, LINK_RUTH_APP, llList2CSV(["skin", "bom"]), "");
        } else {
            integer index = lookup_button(skin_button_faces, b, face);
            if (index >= 0) {
                if (current_skin >= 0) {
                    set_outline_button_state(skin_button_faces, "sk", current_skin, FALSE);
                } else {
                    // BoM button is hard coded to xlink 0, face 2
                    set_outline_link_face_state("sk", 0, 2, 1.0, FALSE);
                }
                current_skin = index;
                set_outline_button_state(skin_button_faces, "sk", index, TRUE);
                llMessageLinked(
                    LINK_THIS,
                    LINK_RUTH_APP,
                    llList2CSV(["skin", (string)(index+1)]),
                    ""
                );
            }
        }
    }
    else if (llGetSubString(name, 0, 2) == "eye") {
        // Eye appliers
        integer b = (integer)llGetSubString(name, 3, -1);
        // BoM button is hard coded to xlink 0, face 2
        if (b == 0 && face == 2) {
            // Eyes Bakes on Mesh
            if (current_eye >= 0) {
                set_outline_button_state(eye_button_faces, "eye", current_eye, FALSE);
            }
            current_eye = -1;
            set_outline_link_face_state("eye", b, face, 1.0, TRUE);
            llMessageLinked(LINK_THIS, LINK_RUTH_APP, llList2CSV(["eyes", "bom"]), "");
       } else {
            integer index = lookup_button(eye_button_faces, b, face);
            if (index >= 0) {
                if (current_eye >= 0) {
                    set_outline_button_state(eye_button_faces, "eye", current_eye, FALSE);
                } else {
                    // BoM button is hard coded to xlink 0, face 2
                    set_outline_link_face_state("eye", 0, 2, 1.0, FALSE);
                }
                current_eye = index;
                set_outline_button_state(eye_button_faces, "eye", index, TRUE);
                llMessageLinked(
                    LINK_THIS,
                    LINK_RUTH_APP,
                    llList2CSV(["eyes", (string)(index+1)]),
                    ""
                );
            }
        }
    }
    else if (llGetSubString(name, 0, 2) == "fnc") {
        // Fingernail color
        integer b = (integer)llGetSubString(name, 3, -1);
        integer index = (b * 5) + face;
        fingernail_color = (vector)llList2String(nail_colors, index);
        if (index == 0) {
            // BoM
            texture_v2(
                "fingernails",
                FINGERNAILS_BOM,
                ALL_SIDES,
                fingernail_color
            );
            send_csv(["ALPHA", "fingernails", -1, 1.0]);
        }
        else if (index >= 1 && index <= 9) {
            fingernails_on(fingernail_color);
        }
    }
    else if (llGetSubString(name, 0, 2) == "fns") {
        // Fingernail shape
        list nail_types = [
            "fingernailsshort",
            "fingernailsmedium",
            "fingernailslong",
            "fingernailspointed",
            "fingernailsnone",
            "fingernailsoval"
        ];
        integer b = (integer)llGetSubString(name, 2, -1);
        if (face >= 0 && face <= 4) {
            integer num = llGetListLength(nail_types);
            integer i = 0;
            visible_fingernails = face;
            for (; i < num; ++i) {
                if (i == face) {
                    send_csv(["ALPHA", llList2String(nail_types, i), ALL_SIDES, 1.0]);
                } else {
                    send_csv(["ALPHA", llList2String(nail_types, i), ALL_SIDES, 0.0]);
                }
            }
        }
    }
    else if (llGetSubString(name, 0, 2) == "tnc") {
        // Toenail color
        integer b = (integer)llGetSubString(name, 3, -1);
        integer index = (b * 5) + face;
        toenail_color = (vector)llList2String(nail_colors, index);
        if (index == 0) {
            // BoM
            texture_v2(
                "toenails",
                TOENAILS_BOM,
                ALL_SIDES,
                toenail_color
            );
        }
        else if (index >= 1 && index <= 9) {
            toenails_on(toenail_color);
        }
    }
    else if (llGetSubString(name, 0, 1) == "hp") {
        // Hand poses
        integer b = ((integer)llGetSubString(name, 2, -1));
        // There are 4 buttons per link but 2 faces per button
        // All of the left buttons (hp0-hp2) come first then all
        // of the right buttons (hp3-hp5) but the animations
        // are L,R,L,R,... order.

        // TODO: add stop button??
        // Stop
        //hp_index = 0;

        // First get the delta for the R side buttons to overlap the left
        integer delta = ((integer)(b / 3) * 3);

        // Calculate the usual 8 face stride and add one for the right side
        // and another one because the list is 1-based
        hp_index = ((b - delta) * 8) + face + ((integer)(b / 3)) + 1;

        integer i;
        for (i=0; i<8; i+=2) {
            set_outline_link_face_state("hp", 0+delta, i, 0.0, FALSE);
            set_outline_link_face_state("hp", 1+delta, i, 0.0, FALSE);
            set_outline_link_face_state("hp", 2+delta, i, 0.0, FALSE);
        }
        set_outline_link_face_state("hp", b, face, 0.4, TRUE);

        do_hp = TRUE;
        llRequestPermissions(llDetectedKey(0), PERMISSION_TRIGGER_ANIMATION);
    }
    else if (llGetSubString(name, 0, 1) == "fp") {
        // Foot poses
        if (name == "fp0") {
            // Ankle Lock
            AnkleLockEnabled = !AnkleLockEnabled;
            log("ankle lock: " + (string)AnkleLockEnabled);
            fp_index = face;
            set_ankle_color(link);
            do_fp = TRUE;
            llRequestPermissions(llDetectedKey(0), PERMISSION_TRIGGER_ANIMATION);
        } else {
            fp_index = face + 1;
            log("index: " + (string)face);
            do_fp = TRUE;
            llRequestPermissions(llDetectedKey(0), PERMISSION_TRIGGER_ANIMATION);
        }
    }
    else {
        // Do nothing here
    }

}

// ****************************************
// Library Functions

// See if the notecard is present in object inventory
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

// See if the XTEA script is present in object inventory
integer can_haz_script(string name) {
    integer count = llGetInventoryNumber(INVENTORY_SCRIPT);
    while (count--) {
        if (llGetInventoryName(INVENTORY_SCRIPT, count) == name) {
            log("Found script: " + name);
            return TRUE;
        }
    }
    log("Script " + name + " not found");
    return FALSE;
}

// Calculate a channel number based on OBJ_ID and owner UUID
integer get_channel(integer id) {
    return 0x80000000 | ((integer)("0x" + (string)llGetOwner()) ^ id);
}

vector get_size() {
    return llList2Vector(llGetPrimitiveParams([PRIM_SIZE]), 0);
}

log(string txt) {
    if (VERBOSE) {
        llOwnerSay(txt);
    }
}

send(string msg) {
    if (haz_xtea) {
        llMessageLinked(LINK_THIS, XTEAENCRYPT, msg, (string)max_channel);
    } else {
        llSay(max_channel, msg);
    }
    if (VERBOSE == 1) {
        llOwnerSay("S: " + msg);
    }
}

send_csv(list msg) {
    send(llList2CSV(msg));
}

// ****************************************
// HUD Positioing

adjust_pos() {
    integer attach_point = llGetAttached();

    // See if attachpoint has changed
    if ((attach_point > 0 && attach_point != last_attach) ||
            (last_attach == 0)) {
        vector size = get_size();

        // HUD rotation needs to know if we are on top or bottom
        attach_bottom = FALSE;

        // Nasty if else block
        if (attach_point == ATTACH_HUD_TOP_LEFT) {
            llSetPos(<0.0, left_offset - size.y / 2, top_offset - size.z / 2>);
        }
        else if (attach_point == ATTACH_HUD_TOP_CENTER) {
            llSetPos(<0.0, 0.0, top_offset - size.z / 2>);
        }
        else if (attach_point == ATTACH_HUD_TOP_RIGHT) {
            llSetPos(<0.0, right_offset + size.y / 2, top_offset - size.z / 2>);
        }
        else if (attach_point == ATTACH_HUD_BOTTOM_LEFT) {
            llSetPos(<0.0, left_offset - size.y / 2, bottom_offset - size.z / 2>);
            attach_bottom = TRUE;
        }
        else if (attach_point == ATTACH_HUD_BOTTOM) {
            llSetPos(<0.0, 0.0, bottom_offset + size.z / 2>);
            attach_bottom = TRUE;
        }
        else if (attach_point == ATTACH_HUD_BOTTOM_RIGHT) {
            llSetPos(<0.0, right_offset + size.y / 2, bottom_offset - size.z / 2>);
            attach_bottom = TRUE;
        }
        else if (attach_point == ATTACH_HUD_CENTER_1) {
        }
        else if (attach_point == ATTACH_HUD_CENTER_2) {
        }
        last_attach = attach_point;
    }
}

// ****************************************
// UI Functions

// Look up link/face in map
integer lookup_button(list face_map, integer xlink, integer face) {
    integer i;
    for (i = 0; i < llGetListLength(face_map); i += 2) {
        if (llList2Integer(face_map, i) == xlink &&
            llList2Integer(face_map, i+1) == face) {
                return i / 2;
        }
    }
    return -1;
}

set_ankle_color(integer link) {
    if (AnkleLockEnabled) {
        llSetLinkPrimitiveParamsFast(link, [PRIM_COLOR, anklelock_face, <0.0, 1.0, 0.0>, 1.0]);
    } else {
        llSetLinkPrimitiveParamsFast(link, [PRIM_COLOR, anklelock_face, <1.0, 1.0, 1.0>, 1.0]);
    }
}

// Sets the texture and outline of an outline button using a map of button
// numbers to link/face
set_outline_button_state(list face_map, string prefix, integer index, integer enabled) {
    integer xlink = llList2Integer(face_map, (index * 2));
    integer face = llList2Integer(face_map, (index * 2) + 1);
    set_outline_link_face_state(prefix, xlink, face, 1.0, enabled);
}

// Sets the texture and outline of an outline button using a map of button
// numbers to link/face
set_outline_button_tex(list face_map, string prefix, integer index, string texture) {
    integer xlink = llList2Integer(face_map, (index * 2));
    integer face = llList2Integer(face_map, (index * 2) + 1);
    integer link = llListFindList(link_map, [prefix + (string)xlink]);
    if (link >= 0) {
        llSetLinkPrimitiveParamsFast(link, [
            PRIM_COLOR, face, <1.0, 1.0, 1.0>, 1.0,
            PRIM_TEXTURE, face, texture, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
            PRIM_COLOR, face+1, offColor, 1.0,
            PRIM_TEXTURE, face+1, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0
        ]);
    }
}

// Set state of an outline button given a link and face
set_outline_link_face_state(string prefix, integer xlink, integer face, float alpha, integer enabled) {
    integer link = llListFindList(link_map, [prefix + (string)xlink]);
    if (link >= 0) {
        if (enabled) {
            llSetLinkPrimitiveParamsFast(link, [
                PRIM_COLOR, face, faceOnColor, alpha,
                PRIM_COLOR, face+1, buttonOnColor, alpha,
                PRIM_TEXTURE, face+1, TEXTURE_BLANK, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0
            ]);
        } else {
            llSetLinkPrimitiveParamsFast(link, [
                PRIM_COLOR, face, <1.0, 1.0, 1.0>, alpha,
                PRIM_COLOR, face+1, offColor, alpha,
                PRIM_TEXTURE, face+1, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0
            ]);
        }
    }
}

// ****************************************
// JSON Functions

// *****
// get/set alpha values in JSON buffer

// j - JSON value storage
// name - link_name
// face - integer face, -1 returns the unmasked 16 bit value
// Internal JSON values are ones complement, ie a 1 bit means the face is not visible
integer json_get_alpha(string j, string name, integer face) {
    integer cur_val = (integer)llJsonGetValue(j, [name]);
    if (face < 0) {
        // All faces, return aggregate value masked to 16 bits
        cur_val = ~cur_val & 0xffff;
    } else {
        cur_val = (cur_val & (1 << face)) == 0;
    }
    return cur_val;
}

// j - JSON value storage
// name - link_name
// face - integer face, -1 sets all 16 bits in the value
// value - alpha boolean, 0 = invisible, 1 = visible
// Internal JSON values are ones complement, ie a 1 bit means the face is not visible
string json_set_alpha(string j, string name, integer face, integer value) {
    value = !value;  // logical NOT for internal storage
    integer cur_val = (integer)llJsonGetValue(j, [name]);
    integer mask;
    integer cmd;
    if (face < 0) {
        // All faces
        mask = 0x0000;
        // One's complement
        cmd = -value;
    } else {
        mask = ~(1 << face);
        cmd = (value << face);
    }
    // Mask final value to 16 bits
    cur_val = ((cur_val & mask) | cmd) & 0xffff;
    return llJsonSetValue(j, [name], (string)(cur_val));
}
// *****

// ****************************************
// Body Functions

integer is_ankle_lock_running() {
    return (
        llListFindList(
            llGetAnimationList(llGetOwner()),
            [llGetInventoryKey(AnkleLockAnim)]
        ) >= 0
    );
}

reset_alpha(float alpha) {
    // Reset body and HUD doll
    integer len = llGetListLength(alpha_buttons);
    integer section;
    for (section = 0; section < len; ++section) {
        string section_name = llList2String(alpha_buttons, section);
        if (alpha > 0 && (section_name == "fingernails")) {
            fingernails_on(fingernail_color);
        }
        else if (alpha > 0 && (section_name == "toenails")) {
            toenails_on(toenail_color);
        }
        else {
            send_csv(["ALPHA", section_name, -1, alpha]);
        }
        current_alpha = json_set_alpha(current_alpha, section_name, 0, (integer)alpha);
    }

    // Reset HUD buttons
    integer link;
    integer j;
    for (link = 0; link <= 3; ++link) {
        for (j=0; j < 8; j+=2) {
            set_outline_link_face_state("alpha", link, j, 1.0, (alpha < 0.01));
        }
    }
}

// Set the alpha val of all links matching name
set_alpha(string name, integer face, float alpha) {
    log("set_alpha(): name="+name+" face="+(string)face+" alpha="+(string)alpha);
    send_csv(["ALPHA", name, face, alpha]);
    current_alpha = json_set_alpha(current_alpha, name, face, (integer)alpha);
    integer link;
    for (; link < num_links; ++link) {
        // Set color for all matching link names
        if (llList2String(link_map, link) == name) {
            // Reset links that appear in the list of body parts
            if (alpha == 0) {
                llSetLinkPrimitiveParamsFast(link, [PRIM_COLOR, face, alphaOnColor, 1.0]);
            } else {
                llSetLinkPrimitiveParamsFast(link, [PRIM_COLOR, face, offColor, 1.0]);
            }
        }
    }
}

// alpha = -1 toggles the current saved value
set_alpha_section(string section_name, integer alpha) {
    integer i;
    integer len = llGetListLength(alpha_buttons);
    for (i = 0; i <= len; ++i) {
        if (llList2String(alpha_buttons, i) == section_name) {
            if (alpha < 0) {
                // Toggle the current value
                log("json: " + current_alpha);
                alpha = !json_get_alpha(current_alpha, section_name, 0);
                log("val: " + (string)alpha);
            }
            if (alpha > 0 && (section_name == "fingernails")) {
                fingernails_on(fingernail_color);
            }
            else if (alpha > 0 && (section_name == "toenails")) {
                toenails_on(toenail_color);
            }
            else {
                send_csv(["ALPHA", section_name, -1, alpha]);
            }
            current_alpha = json_set_alpha(current_alpha, section_name, 0, (integer)alpha);
        }
    }
}

// Literal API for TEXTURE v2 command
texture_v2(string name, string tex, integer face, vector color) {
    string cmd = llList2CSV(["TEXTURE", name, tex, face, color]);
    log(cmd);
    send(cmd);
}


fingernails_on(vector color) {
    send_csv(["ALPHAMODE", "fingernailunder", 1, PRIM_ALPHA_MODE_MASK, mask_cutoff]);
    send_csv(["ALPHA", "fingernailtop", 0, llList2Float(nail_alpha, 0)]);
    send_csv(["ALPHA", "fingernailunder", 1, llList2Float(nail_alpha, 1)]);
    send_csv(["ALPHA", "fingernailtip", 2, llList2Float(nail_alpha, 2)]);
    send_csv(["TEXTURE", "fingernails", nail_texture, 0, <237,227,222>]);
    send_csv(["TEXTURE", "fingernails", nail_texture, 2, <237,227,222>]);
    send_csv(["TEXTURE", "fingernails", nail_texture, 1, color]);
}

toenails_on(vector color) {
    send_csv(["ALPHAMODE", "toenailunder", 1, PRIM_ALPHA_MODE_MASK, mask_cutoff]);
    send_csv(["ALPHA", "toenailtop", 0, llList2Float(nail_alpha, 0)]);
    send_csv(["ALPHA", "toenailunder", 1, llList2Float(nail_alpha, 1)]);
    send_csv(["ALPHA", "toenailtip", 2, llList2Float(nail_alpha, 2)]);
    send_csv(["TEXTURE", "toenails", nail_texture, 0, <237,227,222>]);
    send_csv(["TEXTURE", "toenails", nail_texture, 2, <237,227,222>]);
    send_csv(["TEXTURE", "toenails", nail_texture, 1, color]);
}

// ****************************************

// Reset HUD
reset() {
    //owner = llGetOwner();
    last_attach = llGetAttached();
    attach_bottom = (llListFindList(
        [ATTACH_HUD_BOTTOM_LEFT, ATTACH_HUD_BOTTOM, ATTACH_HUD_BOTTOM_RIGHT],
        [last_attach]
    ) >= 0);



    alpha_mode = PRIM_ALPHA_MODE_MASK;

    max_channel = get_channel(OBJ_ID);
    llListen(max_channel+1, "", "", "");
    llMessageLinked(LINK_THIS, LINK_RUTH_APP,  llList2CSV(["appid", OBJ_ID]), "");
    send_csv(["STATUS", API_VERSION]);

    // Create map of all links to prim names
    integer i;
    num_links = llGetNumberOfPrims() + 1;
    for (; i < num_links; ++i) {
        list p = llGetLinkPrimitiveParams(i, [PRIM_NAME]);
        string name = llList2String(p, 0);
        link_map += [name];
        if (name == "fp0") {
            anklelock_link = i;
        }
    }

    haz_xtea = can_haz_script(XTEA_NAME);

    AnkleLockEnabled = is_ankle_lock_running();
    set_ankle_color(anklelock_link);

    // Save current actual rotation
    last_rot =  llRot2Euler(llList2Rot(llGetLinkPrimitiveParams(LINK_ROOT,[PRIM_ROT_LOCAL]),0));



    log("HUD Memory: used="+(string)llGetUsedMemory()+" free="+(string)llGetFreeMemory());
}

// ****************************************
// States

default {
    state_entry() {
        llSetMemoryLimit(MEM_LIMIT);
        reset();
    }

    touch_start(integer num) {
        llResetTime();
    }

    touch_end(integer num) {
        integer long = (llGetTime() > 2.0);

        integer link = llDetectedLinkNumber(0);
        integer face = llDetectedTouchFace(0);
        vector pos = llDetectedTouchST(0);

        button(link, face, pos, long);
    }

    listen(integer channel, string name, key id, string message) {
        if (llGetOwnerKey(id) == llGetOwner()) {
            if (channel == max_channel+1) {
                log("R: " + message);
                list cmdargs = llCSV2List(message);
                string command = llToUpper(llList2String(cmdargs, 0));

                if (command == "STATUS") {
                    log(
                        "STATUS: " +
                        "API v" + llList2String(cmdargs, 1) + ", " +
                        "Type " + llList2String(cmdargs, 2) + ", " +
                        "Attached " + llList2String(cmdargs, 3)
                    );
                }
            }
        }
    }

    link_message(integer sender, integer number, string message, key id) {
        log("l_m: num: " + (string)number + " msg: " + message + " id: " + (string)id);
        if (number == LINK_RUTH_HUD) {
            // <command>,<arg1>,...
            list cmdargs = llCSV2List(message);
            string command = llToUpper(llList2String(cmdargs, 0));
            if (command == "STATUS") {
                log("Loaded notecard: " + llList2String(cmdargs, 1));
            }
            else if (command == "SKIN_THUMBNAILS") {
                log("Loaded notecard: " + llList2String(cmdargs, 1));
                integer len = llGetListLength(skin_button_faces);
                integer i;
                // Walk returned thumbnail list
                for (i = 0; i < len; ++i) {
                    string tex = llList2String(cmdargs, i + 2);
                    if (tex == "") {
                        tex = TEXTURE_TRANSPARENT;
                    }
                    set_outline_button_tex(skin_button_faces, "sk", i, tex);
                }
                if (current_skin == -1) {
                    // Skin Bakes on Mesh
                    set_outline_link_face_state("sk", 0, 2, 1.0, TRUE);
                } else {
                    set_outline_button_state(skin_button_faces, "sk", current_skin, TRUE);
                }
            }
            else if (command == "EYE_THUMBNAILS") {
                log("Loaded notecard: " + llList2String(cmdargs, 1));
                integer len = llGetListLength(eye_button_faces);
                integer i;
                // Walk returned thumbnail list
                for (i = 0; i < len; ++i) {
                    string tex = llList2String(cmdargs, i + 2);
                    if (tex == "") {
                        tex = TEXTURE_TRANSPARENT;
                    }
                    set_outline_button_tex(eye_button_faces, "eye", i, tex);
                }
                if (current_eye == -1) {
                    // Eyes Bakes on Mesh
                    set_outline_link_face_state("eye", 0, 2, 1.0, TRUE);
                } else {
                    set_outline_button_state(eye_button_faces, "eye", current_eye, TRUE);
                }
            }
            else if (command == "NAILS") {
                nail_texture = llList2String(cmdargs, 1);
                list links = [
                    llListFindList(link_map, ["fnc0"]),
                    llListFindList(link_map, ["fnc1"]),
                    llListFindList(link_map, ["tnc0"]),
                    llListFindList(link_map, ["tnc1"])
                ];
                integer len = llGetListLength(cmdargs) - 2;
                integer i;
                nail_colors = [llList2String(cmdargs, 2)];
                // Walk returned color list
                for (i = 1; i < len; ++i) {
                    string tex = TEXTURE_BLANK;
                    string color = llList2String(cmdargs, i + 2);
                    if (color == "") {
                        tex = TEXTURE_TRANSPARENT;
                        color = "<1,1,1>";
                    }
                    integer link = i / 5;
                    integer face = i % 5;
                    llSetLinkPrimitiveParamsFast(llList2Integer(links, link), [
                        PRIM_COLOR, face, (vector)color, 1.0,
                        PRIM_TEXTURE, face, tex, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0
                    ]);
                    llSetLinkPrimitiveParamsFast(llList2Integer(links, link+2), [
                        PRIM_COLOR, face, (vector)color, 1.0,
                        PRIM_TEXTURE, face, tex, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0
                    ]);
                    nail_colors += color;
                }
            }
        }
    }

    run_time_permissions(integer perm) {
        if (perm & PERMISSION_ATTACH) {
            llDetachFromAvatar();
        }
        if (perm & PERMISSION_TRIGGER_ANIMATION) {
            if (do_hp && hp_index == 0) {
                // Stop all animations
                list anims = llGetAnimationList(llGetPermissionsKey());
                integer len = llGetListLength(anims);
                integer i;
                for (i = 0; i < len; ++i) {
                    llStopAnimation(llList2Key(anims, i));
                }
                // removing all anims can create problems - this sorts things out
                llStartAnimation("stand");
//                llOwnerSay("All finished: " + (string)len + llGetSubString(" animations",0,-1 - (len == 1))+" stopped.\n");
                do_hp = FALSE;
            }
            else if (do_hp && hp_index > 0) {
                // Locate and play a pose animation
                integer nCounter = -1;
                integer lFlag = FALSE;
                integer nTotCount = llGetInventoryNumber(INVENTORY_ANIMATION);
                integer nItemNo;
                string anim = "";
                do {
                    nCounter++;
                    anim = llGetInventoryName(INVENTORY_ANIMATION, nCounter);
                    nItemNo = (integer)anim;
                    if (nItemNo == hp_index) {
                        //When the Animation number matches the button number
                        if (anim != "") {
                            log("hp anim: " + anim);

                            if ((hp_index % 2) == 1) {
                                log(" left");
                                // Left side is odd
                                if (hp_last_left != "") {
                                    llStopAnimation(hp_last_left);
                                }
                                hp_last_left = anim;
                            } else {
                                log(" right");
                                // Right side
                                if (hp_last_right != "") {
                                    llStopAnimation(hp_last_right);
                                }
                                hp_last_right = anim;
                            }
                            llStartAnimation(anim);
                            lFlag = TRUE; //We found the animation
                        }
                    }
                }
                while (nCounter < nTotCount && !lFlag);

                if (!lFlag) {
                    //Error messages - explanations of common problems a user might have if they assemble the HUD or add their own animations
                    if (nItemNo == 0) {
                        llOwnerSay("There's a problem.  First check to make sure you've loaded all of the hand animations in the HUD inventory.  There should be 24 of them.  If that's not the problem, you may have used an incorrect name for one of the prims making up the HUD. Finally, double check to make sure that the backboard of the HUD is the last prim you linked (the root prim).\n");
                    }
                    else {
                        llOwnerSay("Animation # "+(string)nItemNo + " was not found.  Check the animations in the inventory of the HUD.  When numbering the animations, you may have left this number out.\n");
                    }
                }
                do_hp = FALSE;
            }
            if (do_fp) {
                fp_index += fp_offset;
                if (fp_index == fp_offset) {
                    // Handle ankle lock
                    if (AnkleLockEnabled) {
                        log(" start " + AnkleLockAnim);
                        llStartAnimation(AnkleLockAnim);
                    } else {
                        log(" stop " + AnkleLockAnim);
                        llStopAnimation(AnkleLockAnim);
                    }
                } else {
                    // Handle foot poses
                    integer nCounter = -1;
                    integer nTotCount = llGetInventoryNumber(INVENTORY_ANIMATION);
                    string anim = "";
                    // Adjust for the foot pose animation index
                    do {
                        nCounter++;
                        anim = llGetInventoryName(INVENTORY_ANIMATION, nCounter);
                        if ((integer)anim == fp_index) {
                            log("fp anim: " + anim);
                            if (fp_last != "") {
                                log(" stopping: " + fp_last);
                                llStopAnimation(fp_last);
                            }
                            fp_last = anim;
                            llStartAnimation(anim);
                            nCounter = nTotCount;   // Implicit break
                        }
                    }
                    while (nCounter < nTotCount);
                }
                do_fp = FALSE;
            }
        }
    }

// ****************************************
// HUD Positioing

    attach(key id) {
        if (id != NULL_KEY) {
            // Fix up our location
            adjust_pos();
            reset();
        }
    }
// ****************************************

    changed(integer change) {
        if (change & (CHANGED_OWNER)) {
            llResetScript();
        }
    }
}
