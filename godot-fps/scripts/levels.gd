extends RefCounted
## Campaign levels, played in order. Each map is ASCII; one character = one
## 3 m grid cell. Add a level by appending a dictionary to LEVELS.
##
## Legend:
##   #  wall                 .  floor
##   P  player start         E  exit pad (ends the level)
##   d  door                 D  locked door (needs the red keycard)
##   k  red keycard          h  health pack       a  ammo box
##   g  grunt (fast melee)   s  soldier (ranged)  b  brute (tank)
##
## Doors must sit between two walls (left/right or above/below).
## Run `tests/validate_levels.gd` after editing to catch broken maps.

const LEVELS := [
	{
		name = "Intake",
		briefing = "The facility's intake wing is overrun.\nFind the red keycard and reach the green exit pad.",
		accent = Color(1.0, 0.88, 0.7),
		ambient = Color(0.35, 0.38, 0.45),
		wall = Color(0.38, 0.39, 0.42),
		floor = Color(0.24, 0.25, 0.27),
		map = """
##########################
#P......#.........#......#
#.......#....g....#...h..#
#.......d.........d......#
#.......#....a....#..g...#
####d####.........####d###
#.......#####d#####......#
#...g...#.........#......#
#.......#....s....#...a..#
#..h....d.........#....g.#
#.......#.........###D####
####d####....k....#......#
#.......#.........#......#
#...g...######d####......#
#.......#.........#...E..#
#....a..d....g....#......#
##########################
""",
	},
	{
		name = "Foundry",
		briefing = "Soldiers hold the foundry floor and a brute guards the keycard route.\nUse cover and keep moving.",
		accent = Color(1.0, 0.7, 0.45),
		ambient = Color(0.45, 0.35, 0.3),
		wall = Color(0.42, 0.34, 0.28),
		floor = Color(0.26, 0.23, 0.21),
		map = """
################################
#P....#..........#.............#
#.....#....s.....#....g....s...#
#.....d..........d.............#
#.....#....##....#.............#
#..a..#....##....#....##.......#
###d###..........#....##...h...#
#.....#....g.....#.............#
#..g..######d#####d#############
#.....#........#.......#.......#
#..h..d....b...d...s...#...E...#
#.....#........#.......#.......#
###d###........#...k...D.......#
#.....#..a.....#.......#..g....#
#..s..d........#..g....#.......#
################################
""",
	},
	{
		name = "Reactor",
		briefing = "The reactor hall. Brutes patrol the core and the exit is sealed.\nThis is the last push.",
		accent = Color(0.6, 0.85, 1.0),
		ambient = Color(0.3, 0.4, 0.5),
		wall = Color(0.3, 0.34, 0.4),
		floor = Color(0.2, 0.22, 0.25),
		map = """
####################################
#P.....#...........................#
#......#....s.........s............#
#......d...........................#
#......#.....####.......####.......#
#..h...#.....####.......####.......#
####d###.....####...b...####...a...#
#......#...........................#
#..g...#....s.........s............#
#......########d#########d##########
#..a...#..........#.........#......#
#......d....g.....d....g....D..b...#
#......#..........#.........#......#
###d####..a.......#....k....#...E..#
#......#....s.....#.........#..h...#
#..g...d..........#..s......#..s...#
####################################
""",
	},
]
