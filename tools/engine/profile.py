# What goes into SnapRacers' own build of the Godot engine, as options for
# scons. Anything the game doesn't use is left out, which makes the engine
# library, and so the APK, a lot smaller.
#
# The game draws with the Compatibility renderer (OpenGL ES 3), runs its
# physics with Jolt, and has no video, XR, navigation or 2D physics. Sound
# stays in, with Ogg Vorbis for the music, and so does networking, for
# racing online later.
#
# tools/build-engine.sh runs this and passes every name it sets to scons, so
# it's plain Python. The target (release or debug) and link time optimisation
# come from the script, which only does the slow full optimisation for
# builds going out to people.

production = "yes"
optimize = "size"
deprecated = "no"
minizip = "no"

# Rendering: OpenGL ES 3 only.
vulkan = "no"
opengl3 = "yes"
openxr = "no"
disable_xr = "yes"

disable_navigation_2d = "yes"
disable_navigation_3d = "yes"
disable_physics_2d = "yes"

# Text: the simple text server is enough for the game's Latin text.
module_text_server_adv_enabled = "no"
module_text_server_fb_enabled = "yes"
module_msdfgen_enabled = "no"

# Noise stays in: the hills around the courses are made with FastNoiseLite.

# Everything else the game doesn't use.
for module in [
    "astcenc", "basis_universal", "bcdec", "betsy", "bmp", "camera", "csg", "cvtt",
    "dds", "etcpak", "fbx", "glslang", "gltf", "godot_physics_2d", "godot_physics_3d",
    "gridmap", "hdr", "interactive_music", "jpg", "jsonrpc", "ktx", "lightmapper_rd",
    "meshoptimizer", "mobile_vr", "mp3", "navigation_2d", "navigation_3d",
    "objectdb_profiler", "openxr", "raycast", "regex", "svg", "tga", "theora",
    "tinyexr", "upnp", "vhacd", "visual_shader", "webrtc", "webxr",
    "xatlas_unwrap", "zip",
]:
    globals()["module_%s_enabled" % module] = "no"
del module
