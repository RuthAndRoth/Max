# Contrib/Ada Radius

Current Blender export/viewer import workflow

Make sure armature, with all bones used, is visible in scene. 
With mesh facing forward in Blender and all transforms applied, select all components except armature, File > Export Collada (dae.)

Export settings - click gear icon, upper right, if they're not visible:

Main tab: check boxes for "Selection Only", "Include Children", "Include Armatures"
Include Armatures

Global Orientation Check box "Apply"
Forward Axis -X
Up Axis Z

Texture Options check box UV "Only Selected Map"

Geom tab: check boxes Triangulate, Apply Modifiers Viewport, Transform Matrix

Arm tab: check boxes for "Deform Bones Only" and "Export to SL/OpenSim

Anim tab: no animations are included,so the settings do not matter.

Extra tab: Check all boxes except "Limit Precision". The "Keep Bind Info" box is to get the volume bones custom settings into the dae file data, not needed if you're not using them and don't expect to export to another ap. 

On upload to FS viewer:
your preferences for LOD and physics, it depends on what you're using it for. 

Rigging tab: Check boxes for "Include skin weight" and "Include joint positions"

Many thanks to Zai Dium @ Discovery Grid. 

last updated 2023-11-15 Ada Radius
