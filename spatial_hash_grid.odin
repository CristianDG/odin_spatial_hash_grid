package spatial_hash_grid

/*
TODO:
- tests :D
- error handling
- better `update`
- strict initialization
*/

import "core:math"
import "core:slice"

Grid :: struct($T: typeid) {
  position : [2]i32,
  grid_size: [2]i32,
  cell_size: [2]i32,
  _cells: map[i32][dynamic]i32,
  _entries: [dynamic]Entry(T),
  _get_position_fn : proc(T) -> [2]i32,
  _get_size_fn : proc(T) -> [2]i32,
}

Entry :: struct ($T: typeid) {
  cells_indexes: struct {
    min: [2]i32,
    max: [2]i32,
  },
  item: T,
}


insert :: proc(grid: ^$T/Grid($E), item: E) {

  entry : Entry(E)
  entry.item = item

  position := grid._get_position_fn(item)
  size := grid._get_size_fn(item)

  min := get_cell_index(grid, position - (size / 2))
  max := get_cell_index(grid, position + (size / 2))

  entry.cells_indexes = { min=min, max=max }

  append(&grid._entries, entry)
  index := i32(len(grid._entries) - 1)

  for x in min.x..=max.x {
    for y in min.y..=max.y {
      hash := get_cell_hash(x, y)
      if hash not_in grid._cells {
        grid._cells[hash] = make([dynamic]i32)
      }
      append(&grid._cells[hash], index)
    }
  }
}

get_cell_index :: proc(grid: ^$T/Grid($E), position: [2]i32) -> [2]i32 {
  indexes := (position - grid.position) / grid.cell_size
  return indexes
}

get_cell_hash :: proc(x, y: i32) -> i32 {
  return x * 7 + y * 19
}

init :: proc(
  grid: ^$T/Grid($E),
  position  : [2]i32,
  grid_size : [2]i32,
  cell_size : [2]i32,
  get_position_fn : proc(E) -> [2]i32,
  get_size_fn     : proc(E) -> [2]i32,
) {
  grid.position  = position
  grid.grid_size = grid_size
  grid.cell_size = cell_size
  grid._cells    = make(type_of(grid._cells))
  grid._entries  = make(type_of(grid._entries))
  grid._get_position_fn = get_position_fn
  grid._get_size_fn     = get_size_fn
}

deinit :: proc(grid: $T/Grid($E)) {
  for k, v in grid._cells {
    delete(v)
  }
  delete(grid._cells)
  delete(grid._entries)
}

remove :: proc(grid: ^$T/Grid($E), item: E) -> (success: bool){

  entry_index := -1
  entry : Entry(E)
  for &e, i in grid._entries do if e.item == item {
    entry = e
    entry_index = i
  }

  if entry_index == -1 do return false

  using entry.cells_indexes
  for x in min.x..=max.x {
    for y in min.y..=max.y {
      hash := get_cell_hash(x, y)
      for e_i, i in grid._cells[hash] do if int(e_i) == entry_index {
        unordered_remove(&grid._cells[hash], i)
      }
    }
  }

  unordered_remove(&grid._entries, entry_index)
  return true
}

update :: proc(grid: ^$T/Grid($E), item: E) {
  remove(grid, item)
  insert(grid, item)
}

find :: proc {
  find_nearby,
  find_rect,
}

find_rect :: proc(grid: ^$T/Grid($E), min_pos, max_pos: [2]i32) -> []E {
  assert(min_pos.x <= max_pos.x && min_pos.y <= max_pos.y)

  min := get_cell_index(grid, min_pos)
  max := get_cell_index(grid, max_pos)

  result := make([dynamic]E)
  for x in min.x..=max.x {
    for y in min.y..=max.y {
      hash := get_cell_hash(x, y)
      cell, ok := grid._cells[hash]
      if ok do for i in grid._cells[hash] {
        append_elem(&result, grid._entries[i].item)
      }
    }
  }

  slice.sort(result[:])
  return slice.unique(result[:])
}


find_nearby :: proc(grid: ^$T/Grid($E), item: E, radius: [2]i32) -> []E {

  entry : Entry(E)

  found := false
  for e in grid._entries do if e.item == item {
    entry = e
    found = true
  }

  assert(found, "item not found")

  min := get_cell_index(grid, entry.cells_indexes.min - radius)
  max := get_cell_index(grid, entry.cells_indexes.max + radius)

  result := make([dynamic]E)
  for x in min.x..=max.x {
    for y in min.y..=max.y {
      hash := get_cell_hash(x, y)
      cell, ok := grid._cells[hash]
      if ok do for i in grid._cells[hash] {
        found_item := grid._entries[i].item
        if found_item != item do append_elem(&result, found_item)
      }
    }
  }

  slice.sort(result[:])
  return slice.unique(result[:])
}
