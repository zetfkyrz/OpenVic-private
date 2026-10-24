extends Resource
## Look of the map: colours, line widths and strength of the lighting. All values are applied to the shaders of the map
## by MapBaker (see map_theme.tres for the defaults). Widths are in pixels of the map image (5632x2048 in vanilla).

@export_group("Borders")
## Colour of the dark outline of the countries
@export var border_colour: Color = Color(0.015, 0.015, 0.025)
@export_range(0.0, 1.0) var border_opacity: float = 0.55
## Half width of the crisp line of a border
@export_range(0.3, 6.0) var border_width: float = 1.5
## How wide the soft inner glow (the "silhouette" of the country) next to the border is
@export_range(0.0, 20.0) var glow_width: float = 6.0
@export_range(0.0, 1.0) var glow_opacity: float = 0.2
## Line along the coasts
@export var coast_colour: Color = Color(0.03, 0.04, 0.06)
@export_range(0.0, 1.0) var coast_opacity: float = 0.55
@export_range(0.3, 4.0) var coast_width: float = 1.1

@export_group("Relief")
## How strongly the relief shades the map (0 is flat)
@export_range(0.0, 2.0) var relief_strength: float = 1.0
## Slope strength used when the normal map is baked
@export_range(0.5, 30.0) var normal_strength: float = 16.0
## Height of the highest mountains in map pixels (longer shadows and steeper slopes)
@export_range(5.0, 300.0) var height_scale: float = 90.0
## Radius of the blur that turns terrain types into smooth hills
@export_range(2.0, 40.0) var terrain_blur: float = 12.0
## Amount of the fine noise added to the heights
@export_range(0.0, 1.0) var height_detail: float = 0.35
@export_range(0.0, 1.0) var ambient: float = 0.5
@export_range(0.0, 2.0) var diffuse: float = 0.95
@export var sun_colour: Color = Color(1.0, 0.96, 0.88)
## Direction the light comes from: 0 is north, 90 east, 315 north west
@export_range(0.0, 360.0) var sun_azimuth: float = 315.0
## Height of the sun over the horizon when the camera is far / close
@export_range(10.0, 80.0) var sun_elevation_far: float = 55.0
@export_range(10.0, 80.0) var sun_elevation_near: float = 38.0
## How far the light moves with the camera
@export_range(0.0, 40.0) var light_sway: float = 12.0
@export_range(0.0, 1.0) var shadow_strength: float = 0.65
## Length of the baked shadows in map pixels
@export_range(4.0, 200.0) var shadow_length: float = 60.0
@export_range(0.0, 1.0) var ao_strength: float = 0.6
## Radius of the ambient occlusion in map pixels
@export_range(2.0, 40.0) var ao_radius: float = 9.0

## How much higher the land is than the sea at the coast: the coast stands out with light on one side and shadow on the other
@export_range(0.0, 0.8) var coast_cliff: float = 0.55

@export_group("Water")
@export var shallow_colour: Color = Color(0.55, 0.85, 0.95)
@export var deep_colour: Color = Color(0.12, 0.28, 0.5)
@export_range(0.0, 1.0) var depth_strength: float = 0.55
## Distance from the coast (in map pixels) over which the water turns deep
@export_range(4.0, 120.0) var shore_distance: float = 32.0
## Light shelf of shallow water along the coast, with a darker rim where it meets the deep sea (like in HOI4)
@export var shelf_colour: Color = Color(0.45, 0.64, 0.88)
@export_range(0.0, 1.0) var shelf_strength: float = 0.4
## Where the shelf ends, as the share of land around the water (about 0.5 on the coast, smaller further out): 0.17 is about 17 pixels from a straight coast
@export_range(0.05, 0.4) var shelf_edge: float = 0.17
@export_range(0.0, 1.0) var rim_strength: float = 0.06
## Width of the surf along the coast in map pixels
@export_range(2.0, 30.0) var foam_distance: float = 9.0
## Colour of the foam, close to the colour of the sea so that it is not too bright
@export var foam_colour: Color = Color(0.62, 0.8, 0.9)
@export_range(0.0, 1.0) var foam_opacity: float = 0.4
@export_range(0.0, 4.0) var wave_speed: float = 0.8
@export_range(0.0, 1.0) var specular_strength: float = 0.35
