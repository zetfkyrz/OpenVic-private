class_name NationManagementScreensEventsObject
extends RefCounted

signal update_active_nation_management_screen(screen: NationManagement.Screen)
## The plate "Technology" of the top bar opens the tree of OpenVic (ArmyTechWindow), not the screen of Victoria 2
signal army_tech_window_toggle_requested

var _current_screen: NationManagement.Screen = NationManagement.Screen.NONE

# Set the current nation management screen. This emits an update signal to force
# the argument screen to update, even if it was already the current screen.
# Used by miscellaneous screen opening buttons (e.g. in province overview panel)
# and by the close and toggle functions below.


func open_nation_management_screen(screen: NationManagement.Screen) -> void:
	_current_screen = screen
	update_active_nation_management_screen.emit(_current_screen)

# Close the screen if it is already open. Used for screens' close buttons.


func close_nation_management_screen(screen: NationManagement.Screen) -> void:
	if screen == _current_screen:
		open_nation_management_screen(NationManagement.Screen.NONE)

# Either switch to the screen or close it if it is already open. Used for topbar's buttons.


func toggle_nation_management_screen(screen: NationManagement.Screen) -> void:
	if screen == _current_screen:
		screen = NationManagement.Screen.NONE
	open_nation_management_screen(screen)
