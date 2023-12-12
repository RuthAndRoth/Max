# Contrib/Ada Radius

Export-Import Fitted Mesh from Blender to the SL/OS viewer

Make sure armature, with all bones used, is visible in scene, along with mesh pieces we want to export. Everything else in the file (Outliner) should be hidden. 

Armature and child mesh pieces should face forward, -Y, (hotkey numpad 1) in Blender and all transforms applied. 

Select all mesh components without selecting armature. File > Export Collada (dae.)

Export settings - click gear icon, upper right, if they're not visible:

    Main tab: check boxes for "Selection Only", "Include Children", "Include Armatures"
        Global Orientation Check box "Apply", Forward Axis -X, Up Axis Z
        Texture Options check box UV "Only Selected Map"

    Geom tab: check boxes Triangulate, Apply Modifiers Viewport, Transform Matrix

    Arm tab: check boxes for "Deform Bones Only" and "Export to SL/OpenSim

    Extra tab: Check all boxes except "Limit Precision". The "Keep Bind Info" box
    is to get the volume bones custom settings into the dae file data, not needed
    if you're not using them and don't expect to export to another ap. 

Upload to FS viewer:
your preferences for LOD and physics, it depends on what you're using it for. 

Rigging tab: Check boxes for "Include skin weight" and "Include joint positions" (for fitted mesh). 

last updated 2023-12-12 Ada Radius
