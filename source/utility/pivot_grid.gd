class_name PivotGrid

var grid_size : float
var index_grid : Dictionary

func initialize_grid(size, points):
	grid_size = size
	index_grid = {}
	for idx in points.size():
		var pos = points[idx]
		var coords = cell_from_position(pos)
		if not coords[0] in index_grid.keys():
			index_grid[coords[0]] = {coords[1] : [idx]}
			continue
		if not coords[1] in index_grid[coords[0]].keys():
			index_grid[coords[0]][coords[1]] = [idx]
			continue
		index_grid[coords[0]][coords[1]].append(idx)
	print('Initialized Grid with '+str(index_grid.keys().size())+' Cells')

func cell_from_position(pos):
	pos /= grid_size
	var coords = [int(pos.x)-int(pos.x<0), int(pos.z)-int(pos.z<0)]
	return coords

func cells_along_point_sequence(points):
	var cells : Dictionary
	for pos in points:
		var coords = cell_from_position(pos)
		cells[coords] = true
		
	var point_cells = cells.keys()
	
	if point_cells.size() == 1:
		return point_cells
	
	#TODO: trace lines
	## trace lines with bresenham algorithm
	for p_idx in point_cells.size() - 1:
		var p0 = point_cells[p_idx]
		var p1 = point_cells[p_idx+1]
		
		var line_coords := Geometry2D.bresenham_line(Vector2i(p0[0], p0[1]), Vector2i(p1[0], p1[1]))
		for p in line_coords:
			cells[[p.x, p.y]] = true
			
	#print(cells.keys())
	
	return cells.keys()

func pivots_around_cells(cells : Array, k := 1):
	var expanded_cells : Dictionary
	for c in cells:
		expanded_cells[c] = true
	
	for coords in cells:
		for i in range(coords[0]-k, coords[0]+k+1):
			for j in range(coords[1]-k, coords[1]+k+1):
				expanded_cells[[i, j]] = true
	
	var pivots : Array
	for cell in expanded_cells.keys():
		var cell_pivots = pivots_in_cell(cell)
		for p in cell_pivots:
			pivots.push_back(p)
					
	return pivots

func pivots_in_cell(coords):
	if coords[0] not in index_grid.keys():
		return []
	if coords[1] not in index_grid[coords[0]].keys():
		return []
	return index_grid[coords[0]][coords[1]]

func pivots_around_position(pos, k := 1):
	var coords = cell_from_position(pos)
	var prox_pivots = Array()
	
	for i in range(coords[0]-k, coords[0]+k+1):
		if i not in index_grid.keys():
			continue
		for j in range(coords[1]-k, coords[1]+k+1):
			if j not in index_grid[i].keys():
				continue
			for p in index_grid[i][j]:
				prox_pivots.push_back(p)
	return prox_pivots
	
