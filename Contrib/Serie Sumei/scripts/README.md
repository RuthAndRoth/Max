# Contrib/Serie Sumei/scripts

These scripts are experimental/development versions of the scripts
in the main Scripts directory.

## Scripts

* max_hud_receiver.lsl - A cleanup of the Ruth2/Roth2 receiver script that most
  notably changes the license to MIT.  This script is still mostly compatible
  with the Ruth2 HUD, which will work for setting alpha and skin textures/BoM for
  the body and eyes, as well as hand and foot poses.

  The script will automatically play hand poses if they are present in the
  body's inventory.

* max_xtea.lsl - Optional encryption module for HUD - body communication

  This is a nearly verbatim copy of the script in the Ruth2/Roth2 repos, the name
  has been changed to match development conventions.  To use it, change the key
  on line 50 and put a copy of the script with no-mod permissions in both the HUD
  and the body inventories.  Both objects will detect its presence and use it to
  encrypt communication.
