@tool
extends EditorExportPlugin

## Puts the network plugin's AAR (built by tools/build-plugin.sh) into the
## Android build. Its permissions are in its own manifest, which Gradle joins
## onto the game's.


func _get_name() -> String:
	return "SnapRacersNet"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray(["snapracers_net/bin/snapracers-net.aar"])
