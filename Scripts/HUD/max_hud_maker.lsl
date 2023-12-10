// max_hud_maker.lsl - Max HUD Creation
// SPDX-License-Identifier: MIT
// Copyright 2023 Serie Sumei

// v0.2 03Dec2023 <seriesumei@avimail.org> - Rewrite for Max HUD

// This builds a multi-paned HUD for Max that includes panes for alpha cuts,
// skin applier and an Options pane that has fingernail
// shape/color and toenail color buttons as well as hand and foot pose buttons.
//
// To build the HUD from scratch you will need to:
// * Create a new empty box prim named 'Object'
// * Take a copy of the new box into inventory and leave the original on the ground
// * Rename the box on the ground "HUD maker"
// * Copy the following objects into the inventory of the new box:
//   * the new box created above (from inventory) named 'Object'
//   * the button meshes: '4x1_outline_button', '5x1-s_button' and '6x1_button'
//   * the max_hud_maker.lsl script (this script)
// * Take a copy of the HUD maker box because trying again is much simpler from
//   this stage than un-doing what the script is about to do
// * Light fuse (touch the box prim) and get away, the new HUD will be
//   assembled around the box prim which will become the root prim of the HUD.
// * Remove this script and the other objects from the HUD root prim and copy
//   in the HUD script(s).
// * The other objects are also not needed any longer in the root prim and
//   can be removed.

vector build_pos;
integer link_me = FALSE;
integer FINI = FALSE;
integer counter = 0;
integer num_repeat = 0;

key hud_texture;
key header_texture;
key skin_texture;
key options_texture;
key fingernails_shape_texture;
key alpha_button_texture;
key alpha_doll_texture;

vector bar_size = <0.3, 0.3, 0.025>;
vector hud_size = <0.29, 0.29, 0.29>;
vector color_button_size = <0.01, 0.09, 0.0165>;
vector shape_button_size = <0.01, 0.14, 0.025>;
vector alpha_button_scale = <0.25, 0.125, 0.0>;

vector alpha_doll_pos;
integer num_alpha_buttons;
vector alpha_button_size;
list alpha_button_pos = [
    <-0.057,  0.1, -0.15>,
    < 0.068,  0.1, -0.15>,
    <-0.057, -0.1, -0.15>,
    < 0.068, -0.1, -0.15>
];

list alpha_button_hoffset;

// Vertical offset for alpha button textures
list alpha_button_voffset = [
    0.4375, 0.3125, 0.1875, 0.0625, -0.0625, -0.1875, -0.3125, -0.4375
];

list hand_button_pos = [
    <0.037, -0.08, 0.15>,
    <0.037,  0.00, 0.15>,
    <0.037,  0.08, 0.15>,
    <0.054, -0.08, 0.15>,
    <0.054,  0.00, 0.15>,
    <0.054,  0.08, 0.15>
];

// Spew debug info
integer VERBOSE = TRUE;

// Hack to detect Second Life vs OpenSim
// Relies on a bug in llParseString2List() in SL
// http://grimore.org/fuss/lsl/bugs#splitting_strings_to_lists
integer is_SL() {
    string sa = "12999";
//    list OS = [1,2,9,9,9];
    list SL = [1,2,999];
    list la = llParseString2List(sa, [], ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]);
    return (la == SL);
}

// Wrapper for osGetGridName to simplify transition between environments
string GetGridName() {
    string grid_name;
    // Comment out this line to run in SecondLife, un-comment it to run in OpenSim
    grid_name = osGetGridName();
    if (is_SL()) {
        grid_name = llGetEnv("sim_channel");
    }
    llOwnerSay("grid: " + grid_name);
    return grid_name;
}

// The textures used in the HUD referenced below are included in the repo:
// hud_texture: ruth2_v3_hud_gradient.png
// header_texture: max_hud_header-512.png
// skin_texture: ruth2_v3_hud_skin.png
// options_texture: ruth2_v3_hud_options.png
// alpha_button_texture: r2_hud_alpha_buttons.png
// alpha_doll_texture: r2_hud_alpha_doll.png
// fingernails_shape_texture: ruth 2.0 hud fingernails shape.png

configure() {
    num_alpha_buttons = 3;
    alpha_button_size = <0.01, 0.125, 0.080>;
    alpha_button_hoffset = [-0.375, -0.125];
    if (is_SL()) {
        // Textures in SL
        // The textures listed are full-perm uploaded by seriesumei Resident
        hud_texture = "e75bab3a-587e-6a2e-af2f-931b4b6563c0";
        skin_texture = "206804f6-908a-8efb-00de-fe00b2604906";
        alpha_doll_texture = "1e757025-39a0-dcef-dd67-567eadb86fe2";
        alpha_button_texture = "3105f8fe-3219-fd83-33f3-aafa2c4b802b";
        header_texture = "be9b5ded-815b-c240-12a8-54af52878248";
        options_texture = "1006e4d9-ea71-fbb5-c6aa-60c883a66422";
        fingernails_shape_texture = TEXTURE_BLANK;
        alpha_doll_pos = <0.0, 0.57, 0.18457>;
    } else {
        if (GetGridName() == "OSGrid") {
            // Textures in OSGrid
            // TODO: Bad assumption that OpenSim == OSGrid, how do we detect
            //       which grid?  osGetGridName() is an option but does not
            //       compile in SL so editing the script would stll be required.
            //       Maybe we don't care too much about that?
            // The textures listed are full-perm uploaded by serie sumei to OSGrid
            hud_texture = "699c5ee8-5296-4fc0-a771-e6d0a06cc590";
            skin_texture = "64184dac-b33b-4a1b-b200-7d09d8928b64";
            alpha_doll_texture = "45292011-feb6-4d0b-b4b0-5d1464943fdd";
            alpha_button_texture = "d7389b96-54de-4824-90f8-7af8dac01a99";
            header_texture = "bb35fd1d-4a9f-4c92-91c7-e402bc01a7c6";
            options_texture = "891a3136-c767-42ca-9172-cbb980601132";
            fingernails_shape_texture = TEXTURE_BLANK;
            alpha_doll_pos = <0.0, 0.75, 0.0>;
        } else {
            log("OpenSim detected but grid " + GetGridName() + " unknown, using blank textures");
            hud_texture = TEXTURE_BLANK;
            header_texture = TEXTURE_BLANK;
            skin_texture = TEXTURE_BLANK;
            options_texture = TEXTURE_BLANK;
            fingernails_shape_texture = TEXTURE_BLANK;
            alpha_button_texture = TEXTURE_BLANK;
            alpha_doll_texture = TEXTURE_BLANK;
        }
    }
}

log(string txt) {
    if (VERBOSE) {
        llOwnerSay(txt);
    }
}

rez_object(string name, vector delta, vector rot) {
    log("Rezzing " + name);
    llRezObject(
        name,
        build_pos + delta,
        <0.0, 0.0, 0.0>,
        llEuler2Rot(rot),
        0
    );
}

configure_header(string name, float offset_y) {
    log("Configuring " + name);
    llSetLinkPrimitiveParamsFast(2, [
        PRIM_NAME, name,
        PRIM_TEXTURE, ALL_SIDES, header_texture, <1.0, 0.08, 0.0>, <0.0, offset_y, 0.0>, 0.0,
        PRIM_TEXTURE, 0, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
        PRIM_TEXTURE, 5, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
        PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.00,
        PRIM_SIZE, bar_size
    ]);
}

configure_color_buttons(string name) {
    log("Configuring " + name);
    llSetLinkPrimitiveParamsFast(2, [
        PRIM_NAME, name,
        PRIM_TEXTURE, ALL_SIDES, TEXTURE_BLANK, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
        PRIM_TEXTURE, 5, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
        PRIM_TEXTURE, 6, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
        PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.00,
        PRIM_SIZE, color_button_size
    ]);
}

configure_outline_button(string name, vector size, vector taper, vector scale, vector offset) {
    log("Configuring " + name);
    llSetLinkPrimitiveParamsFast(2, [
        PRIM_NAME, name,
        PRIM_TYPE, PRIM_TYPE_BOX, PRIM_HOLE_DEFAULT, <0.0, 1.0, 0.0>, 0.0, ZERO_VECTOR, taper, ZERO_VECTOR,
        PRIM_TEXTURE, 0, skin_texture, scale, offset, 0.0,
        PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.00,
        PRIM_SIZE, size
    ]);

}

default {
    touch_start(integer total_number) {
        configure();
        build_pos = llGetPos();
        counter = 0;
        // set up root prim
        log("Configuring root");
        llSetLinkPrimitiveParamsFast(LINK_THIS, [
            PRIM_NAME, "HUD base",
            PRIM_SIZE, <0.1, 0.1, 0.1>,
            PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <0,0,0>, <0.0, 0.455, 0.0>, 0.0,
            PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.00
        ]);

        // See if we'll be able to link to trigger build
        llRequestPermissions(llGetOwner(), PERMISSION_CHANGE_LINKS);
    }

    run_time_permissions(integer perm) {
        // Only bother rezzing the object if will be able to link it.
        if (perm & PERMISSION_CHANGE_LINKS) {
            // log("Rezzing minbar");
            link_me = TRUE;
            rez_object("Object", <-0.17, 0.12, 0.1575>, <0.0, 0.0, 0.0>);
        } else {
            llOwnerSay("unable to link objects, aborting build");
        }
    }

    object_rez(key id) {
        counter++;
        integer i = llGetNumberOfPrims();
        log("counter="+(string)counter);

        if (link_me) {
            llCreateLink(id, TRUE);
            link_me = FALSE;
        }

        if (counter == 1) {
            configure_header("minbar", 0.440);
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
//                PRIM_TEXTURE, 2, header_texture, <0.2, 0.08, 0.0>, <-0.4, 0.437, 0.0>, 0.0,
                PRIM_TEXTURE, 4, header_texture, <0.2, 0.08, 0.0>, <-0.4, -0.437, 0.0>, 0.0,
                PRIM_SIZE, <0.01, 0.06, 0.025>
            ]);

        // ***** HUD Nav Bar*****

            log("Rezzing navbar");
            link_me = TRUE;
            rez_object("Object", <-0.1575, 0.0, 0.0>, <0.0, -PI_BY_TWO, 0.0>);
        }
        else if (counter == 2) {
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "navbar",
                PRIM_TEXTURE, 0, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 1, header_texture, <1.0, 0.08, 0.0>, <0.0, 0.187, 0.0>, 0.0,
                PRIM_TEXTURE, 2, header_texture, <1.0, 0.08, 0.0>, <0.0, 0.062, 0.0>, 0.0,
                PRIM_TEXTURE, 3, header_texture, <1.0, 0.08, 0.0>, <0.0, 0.436, 0.0>, 0.0,
                PRIM_TEXTURE, 4, header_texture, <1.0, 0.08, 0.0>, <0.0, 0.312, 0.0>, 0.0,
                PRIM_TEXTURE, 5, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.00,
                PRIM_SIZE, bar_size
            ]);

        // ***** Base HUD Box *****

            log("Rezzing HUD box");
            link_me = TRUE;
            rez_object("Object", <0.0, 0.0, 0.0>, <0.0, 0.0, 0.0>);
        }
        else if (counter == 3) {
            log("Configuring HUD box");
                llSetLinkPrimitiveParamsFast(2, [
                    PRIM_NAME, "hudbox",
                    PRIM_TEXTURE, 0, options_texture, <0.9, 0.78, 0.0>, <0.0, 0.06, 0.0>, 90.0 * DEG_TO_RAD,
                    PRIM_TEXTURE, 1, skin_texture, <1.0, 0.8, 0.0>, <0.0, 0.1, 0.0>, 90.0 * DEG_TO_RAD,
                    PRIM_TEXTURE, 2, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 1.0,
                    PRIM_TEXTURE, 3, hud_texture, <0.9, 0.78, 0.0>, <0.0, 0.06, 0.0>, 90.0 * DEG_TO_RAD,
                    PRIM_TEXTURE, 4, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 1.0,
                    PRIM_TEXTURE, 5, hud_texture, <0.9, 0.78, 0.0>, <0.0, 0.06, 0.0>, 90.0 * DEG_TO_RAD,
                    PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.00,
                    PRIM_ALPHA_MODE, ALL_SIDES, PRIM_ALPHA_MODE_NONE, 0,
                    PRIM_ALPHA_MODE, 2, PRIM_ALPHA_MODE_BLEND, 0,
                    PRIM_ALPHA_MODE, 4, PRIM_ALPHA_MODE_BLEND, 0,
                    PRIM_SIZE, hud_size
                ]);

        // ***** Alpha HUD *****

                log("Rezzing alpha doll");
                link_me = TRUE;
                rez_object("Object", <0.0, 0.0, -0.145>, <0.0, -PI_BY_TWO, 0.0>);
        }
        else if (counter == 4) {
            log("Configuring alpha doll");
                llSetLinkPrimitiveParamsFast(2, [
                    PRIM_NAME, "alphadoll",
                    PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                    PRIM_TEXTURE, 4, alpha_doll_texture, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                    PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.00,
                    PRIM_SIZE, <0.01, 0.29, 0.275>
                ]);

            log("Rezzing alpha button 0");
            link_me = TRUE;
            num_repeat = 0;
            rez_object("4x1_outline_button", llList2Vector(alpha_button_pos, 0), <PI_BY_TWO, 0.0, PI_BY_TWO>);
        }
        else if (counter == 5) {
            // Roth: 0,1 = left; 2,3 = right
            // Ruth: 0,1,2,3 = left; 4,5,6,7 = right
            integer hindex = (num_repeat & 6) >> 1;
            // even = 0, odd = 4
            integer vindex = (num_repeat & 1) << 2;

            log("Configuring alpha button " + (string)num_repeat);
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "alpha" + (string)num_repeat,
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 0, alpha_button_texture, alpha_button_scale, (vector)("<"+llList2String(alpha_button_hoffset, hindex)+","+llList2String(alpha_button_voffset, vindex)+",0.0>"), PI_BY_TWO,
                PRIM_TEXTURE, 2, alpha_button_texture, alpha_button_scale, (vector)("<"+llList2String(alpha_button_hoffset, hindex)+","+llList2String(alpha_button_voffset, vindex+1)+",0.0>"), PI_BY_TWO,
                PRIM_TEXTURE, 4, alpha_button_texture, alpha_button_scale, (vector)("<"+llList2String(alpha_button_hoffset, hindex)+","+llList2String(alpha_button_voffset, vindex+2)+",0.0>"), PI_BY_TWO,
                PRIM_TEXTURE, 6, alpha_button_texture, alpha_button_scale, (vector)("<"+llList2String(alpha_button_hoffset, hindex)+","+llList2String(alpha_button_voffset, vindex+3)+",0.0>"), PI_BY_TWO,
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.00,
                PRIM_SIZE, alpha_button_size
            ]);
            if (num_repeat < num_alpha_buttons) {
                // do another one
                num_repeat++;
                counter--;
                log("Rezzing alpha button " + (string)num_repeat);
                link_me = TRUE;
                rez_object("4x1_outline_button", llList2Vector(alpha_button_pos, num_repeat), <PI_BY_TWO, 0.0, PI_BY_TWO>);
            } else {
                // move on to next

        // ***** Skin HUD *****

                // Set counter for skin panel
                counter = 10;

                log("Rezzing skin button 0");
                link_me = TRUE;
                rez_object("4x1_outline_button", <-0.1, -0.15000, -0.075>, <0.0, -PI_BY_TWO, PI_BY_TWO>);
            }
        }
        else if (counter == 11) {
            log("Configuring skin tone button 0");
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "sk0",
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 2, skin_texture, <0.087, 0.087, 0.00>, <-0.375, -0.437, 0.0>, 0.0,
                PRIM_TEXTURE, 4, TEXTURE_BLANK, <0.0, 0.0, 0.00>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 6, TEXTURE_BLANK, <0.0, 0.0, 0.00>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_SIZE, <0.01, 0.15, 0.04>
            ]);

            log("Rezzing skin button 1");
            link_me = TRUE;
            rez_object("4x1_outline_button", <-0.1, -0.15000, 0.075>, <0.0, -PI_BY_TWO, PI_BY_TWO>);
        }
        else if (counter == 12) {
            log("Configuring skin tone button 1");
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "sk1",
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 0, TEXTURE_BLANK, <0.0, 0.0, 0.00>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 2, TEXTURE_BLANK, <0.0, 0.0, 0.00>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 4, TEXTURE_BLANK, <0.0, 0.0, 0.00>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_SIZE, <0.01, 0.15, 0.04>
            ]);

            log("Rezzing skin button 2");
            link_me = TRUE;
            rez_object("4x1_outline_button", <-0.06, -0.15000, -0.075>, <0.0, -PI_BY_TWO, PI_BY_TWO>);
        }
        else if (counter == 13) {
            log("Configuring skin tone button 2");
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "sk2",
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 4, TEXTURE_BLANK, <0.0, 0.0, 0.00>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 6, TEXTURE_BLANK, <0.0, 0.0, 0.00>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_SIZE, <0.01, 0.15, 0.04>
            ]);

            log("Rezzing skin button 3");
            link_me = TRUE;
            rez_object("4x1_outline_button", <-0.06, -0.15000, 0.075>, <0.0, -PI_BY_TWO, PI_BY_TWO>);
        }
        else if (counter == 14) {
            log("Configuring skin tone button 3");
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "sk3",
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 0, TEXTURE_BLANK, <0.0, 0.0, 0.00>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 2, TEXTURE_BLANK, <0.0, 0.0, 0.00>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 4, TEXTURE_BLANK, <0.0, 0.0, 0.00>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_SIZE, <0.01, 0.15, 0.04>
            ]);

            log("Rezzing amode button");
            link_me = TRUE;
            rez_object("4x1_outline_button", <-0.01, -0.15, 0.0>, <0.0, -PI_BY_TWO, PI_BY_TWO>);
        }
        else if (counter == 15) {
            log("Configuring alpha mode button");
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "amode0",
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 2, skin_texture, <0.255, 0.064, 0.00>, <0.0, -0.438, 0.0>, 0.0,
                PRIM_TEXTURE, 4, skin_texture, <0.255, 0.064, 0.00>, <0.3134, -0.438, 0.0>, 0.0,
                PRIM_SIZE, <0.01, 0.300, 0.03>
            ]);

            log("Rezzing eye button 0");
            link_me = TRUE;
            rez_object("4x1_outline_button", <0.06, -0.15000, -0.075>, <0.0, -PI_BY_TWO, PI_BY_TWO>);
        }
        else if (counter == 16) {
            log("Configuring eye button 0");
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "eye0",
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 2, skin_texture, <0.087, 0.087, 0.00>, <-0.375, -0.437, 0.0>, 0.0,
                PRIM_TEXTURE, 4, TEXTURE_BLANK, <0.0, 0.0, 0.00>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 6, TEXTURE_BLANK, <0.0, 0.0, 0.00>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_SIZE, <0.01, 0.15, 0.04>
            ]);

            log("Rezzing eye button 1");
            link_me = TRUE;
            rez_object("4x1_outline_button", <0.06, -0.15000, 0.075>, <0.0, -PI_BY_TWO, PI_BY_TWO>);
        }
        else if (counter == 17) {
            log("Configuring eye button 1");
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "eye1",
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 0, TEXTURE_BLANK, <0.0, 0.0, 0.00>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 2, TEXTURE_BLANK, <0.0, 0.0, 0.00>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 4, TEXTURE_BLANK, <0.0, 0.0, 0.00>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_SIZE, <0.01, 0.15, 0.04>
            ]);

        // ***** Option HUD *****

            // Set counter for option panel
            counter = 20;

            log("Rezzing fingernails off button");
            link_me = TRUE;
            rez_object("Object", <-0.125, -0.11, 0.15>, <0.0, -PI_BY_TWO, PI>);
        }
        else if (counter == 21) {
            log("Configuring fingernails off button");
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "fno",
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 4, options_texture, <0.12, 0.118, 0.0>, <0.065, -0.44, 0.0>, 0.0,
                PRIM_COLOR, 4, <0.75, 0.75, 0.75>, 1.00,
                PRIM_SIZE, <0.01, 0.0165, 0.0165>
            ]);

            log("Rezzing fingernail shape buttons");
            link_me = TRUE;
            rez_object("5x1-s_button", <-0.081, -0.0515, 0.15>, <0.0, -PI_BY_TWO, PI>);
        }
        else if (counter == 22) {
            log("Configuring fingernail shape buttons");
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "fns0",
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 0, fingernails_shape_texture, <0.2, 0.9, 0.0>, <-0.375, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 1, fingernails_shape_texture, <0.2, 0.9, 0.0>, <-0.125, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 2, fingernails_shape_texture, <0.2, 0.9, 0.0>, <0.125, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 3, fingernails_shape_texture, <0.2, 0.9, 0.0>, <0.375, 0.0, 0.0>, 0.0,
                PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.00,
                PRIM_COLOR, 3, <0.3, 0.3, 0.3>, 1.00,
                PRIM_SIZE, <0.01, 0.09, 0.0165>
            ]);

            log("Rezzing fingernail color buttons");
            link_me = TRUE;
            rez_object("5x1-s_button", <-0.105, -0.07, 0.15>, <0.0, -PI_BY_TWO, PI>);
        }
        else if (counter == 23) {
            configure_color_buttons("fnc0");
            // Make first button BoM
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_TEXTURE, 0, options_texture, <0.087, 0.087, 0.00>, <0.313, -0.437, 0.0>, 0.0,
                PRIM_COLOR, 0, <0.0, 0.0, 0.0>, 1.00
            ]);

            log("Rezzing fingernail color buttons");
            link_me = TRUE;
            rez_object("5x1-s_button", <-0.105, 0.023, 0.15>, <0.0, -PI_BY_TWO, PI>);
        }
        else if (counter == 24) {
            configure_color_buttons("fnc1");

            log("Rezzing toenails off button");
            link_me = TRUE;
            rez_object("Object", <-0.053, -0.11, 0.15>, <0.0, -PI_BY_TWO, PI>);
        }
        else if (counter == 25) {
            log("Configuring toenails off button");
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "tno",
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 4, options_texture, <0.12, 0.118, 0.0>, <0.065, -0.44, 0.0>, 0.0,
                PRIM_COLOR, 4, <0.75, 0.75, 0.75>, 1.00,
                PRIM_SIZE, <0.01, 0.0165, 0.0165>
            ]);

            log("Rezzing toenail color buttons");
            link_me = TRUE;
            rez_object("5x1-s_button", <-0.035, -0.07, 0.15>, <0.0, -PI_BY_TWO, PI>);
        }
        else if (counter == 26) {
            configure_color_buttons("tnc0");
            // Make first button BoM
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_TEXTURE, 0, options_texture, <0.087, 0.087, 0.00>, <0.313, -0.437, 0.0>, 0.0,
                PRIM_COLOR, 0, <0.0, 0.0, 0.0>, 1.00
            ]);

            log("Rezzing toenail color buttons");
            link_me = TRUE;
            rez_object("5x1-s_button", <-0.035, 0.023, 0.15>, <0.0, -PI_BY_TWO, PI>);
        }
        else if (counter == 27) {
            configure_color_buttons("tnc1");

            log("Rezzing hand pose off button");
            link_me = TRUE;
            rez_object("Object", <0.015, -0.11, 0.15>, <0.0, -PI_BY_TWO, PI>);
        }
        else if (counter == 28) {
            log("Configuring hand pose off button");
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "hpo",
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 4, options_texture, <0.12, 0.118, 0.0>, <0.065, -0.44, 0.0>, 0.0,
                PRIM_COLOR, 4, <0.75, 0.75, 0.75>, 1.00,
                PRIM_SIZE, <0.01, 0.02, 0.02>
            ]);

            log("Rezzing hand pose button 0");
            link_me = TRUE;
            num_repeat = 0;
            rez_object("4x1_outline_button", llList2Vector(hand_button_pos, 0), <0.0, -PI_BY_TWO, PI>);
        }
        else if (counter == 29) {
            log("Configuring hand pose button " + (string)num_repeat);
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "hp" + (string)num_repeat,
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_SIZE, <0.01, 0.08, 0.02>
            ]);

            if (num_repeat < 6) {
                // do another one
                num_repeat++;
                counter--;
                log("Rezzing hand pose button " + (string)num_repeat);
                link_me = TRUE;
                rez_object("4x1_outline_button", llList2Vector(hand_button_pos, num_repeat), <0.0, -PI_BY_TWO, PI>);
            } else {
                // move on to next
                // Set counter for next panel
                counter = 34;

                log("Rezzing foot pose off button");
                link_me = TRUE;
                rez_object("Object", <0.0845, -0.11, 0.15>, <0.0, -PI_BY_TWO, PI>);
            }
        }
        else if (counter == 35) {
            log("Configuring foot pose off button");
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "fpo",
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 4, options_texture, <0.12, 0.118, 0.0>, <0.065, -0.44, 0.0>, 0.0,
                PRIM_COLOR, 4, <0.75, 0.75, 0.75>, 1.00,
                PRIM_SIZE, <0.01, 0.02, 0.02>
            ]);

            log("Rezzing ankle lock button");
            link_me = TRUE;
            rez_object("Object", <0.108, -0.105, 0.15>, <0.0, -PI_BY_TWO, PI>);
        }
        else if (counter == 36) {
            log("Configuring ankle lock button");
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "fp0",
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_TEXTURE, 4, options_texture, <0.13, 0.12, 0.0>, <0.44, -0.44, 0.0>, 0.0,
                PRIM_COLOR, 4, <0.0, 0.0, 0.0>, 1.00,
                PRIM_SIZE, <0.01, 0.04, 0.04>
            ]);

            log("Rezzing foot pose buttons");
            link_me = TRUE;
            rez_object("6x1_button", <0.115, 0.016, 0.15>, <0.0, -PI_BY_TWO, PI>);
        }
        else if (counter == 37) {
            log("Configuring foot pose button");
            llSetLinkPrimitiveParamsFast(2, [
                PRIM_NAME, "fp1",
                PRIM_TEXTURE, ALL_SIDES, TEXTURE_TRANSPARENT, <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
                PRIM_SIZE, <1.0, 0.22, 0.04>
            ]);
        }
        else {
            counter++;
        }
    }
}
