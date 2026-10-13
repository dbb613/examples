extends RefCounted
## ASCII map helpers shared by the level builder and the level validator.


## Returns the map as an array of equal-length rows (short rows padded with walls).
static func parse(map_text: String) -> PackedStringArray:
	var rows := PackedStringArray()
	for line in map_text.strip_edges().split("\n"):
		rows.append(line.strip_edges())
	var w := 0
	for r in rows:
		w = maxi(w, r.length())
	for i in rows.size():
		rows[i] = rows[i].rpad(w, "#")
	return rows


## Character at (x, y); anything outside the map counts as wall.
static func char_at(rows: PackedStringArray, x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return "#"
	return rows[y][x]
