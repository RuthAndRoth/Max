# Scripts

The scripts used for the HUD and receiver for Max.  Those scripts that were
derived from prior Ruth script (pre-v3) have been rewritten and relicensed
to the MIT License.

* max_applier.lsl - The texture applier script, also responsible for loading
  the `!CONFIG` notecard.

* max_hud_control.lsl - The primary HUD control script

* max_hud_maker.lsl - A script that will assemble a HUD linkset from the
  mesh button parts and a prim.  Has configurations for multiple grids
  within the script.

* max_hud_receiver.lsl - The body receiver script for the mesh and attachments.
  This script is still mostly compatible with the Ruth2 HUD, which will work
  for setting alpha and skin textures/BoM for the body and eyes, as well as
  hand and foot poses.

  The script will automatically play hand poses if they are present in the
  body's inventory.

* max_xtea.lsl - Optional encryption module for HUD - body communication

  This is a nearly verbatim copy of the script in the Ruth2/Roth2 repos, the
  name has been changed to match development conventions.  To use it, change
  the key on line 50 and put a copy of the script with no-mod permissions in
  both the HUD and the body inventories.  Both objects will detect its
  presence and use it to encrypt communication.
