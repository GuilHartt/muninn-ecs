package ecs

import "core:slice"
import "core:hash"
import "core:mem"
import "core:mem/virtual"

ArchetypeEdge :: struct {
    add, remove: ^Archetype
}

Archetype :: struct {
    hash:     u64,
    entities: [dynamic]Entity,
    types:    []Entity,
    columns:  [][]byte,
    len:      int,
    edges:    map[Entity]ArchetypeEdge,
}

get_view :: proc {
    get_view_type,
    get_view_id,
    get_view_pair,
}

get_archetypes :: proc {
    get_archetypes_type,
    get_archetypes_id,
    get_archetypes_pair,
    get_archetypes_pair_type_type,
    get_archetypes_pair_id_id,
    get_archetypes_pair_type_id,
    get_archetypes_pair_id_type,
}

@(private="file")
get_view_id :: proc(world: ^World, arch: ^Archetype, id: Entity, $T: typeid) -> []T {
    if arch.len == 0 do return nil

    idx, found := slice.binary_search(arch.types, id)
    if !found {
        return nil
    }

    raw_bytes := raw_data(arch.columns[idx])
    return ([^]T)(raw_bytes)[:arch.len]
}

@(private="file")
get_view_type :: #force_inline proc(world: ^World, arch: ^Archetype, $T: typeid) -> []T {
    return get_view_id(world, arch, get_component_id(world, T), T)
}

@(private="file")
get_view_pair :: #force_inline proc(world: ^World, arch: ^Archetype, pair: Pair, $T: typeid) -> []T {
    return get_view_id(world, arch, pair_id(world, pair), T)
}


@(private="file", require_results)
get_archetypes_type :: #force_inline proc(world: ^World, $T: typeid) -> []^Archetype {
    return get_archetypes_id(world, get_component_id(world, T))
}

@(private="file", require_results)
get_archetypes_id :: proc(world: ^World, id: Entity) -> []^Archetype {
    if list, ok := world.component_index[id]; ok {
        return list[:]
    }
    return nil
}

@(private="file", require_results)
get_archetypes_pair :: #force_inline proc(world: ^World, p: Pair) -> []^Archetype {
    return get_archetypes_id(world, pair_id(world, p))
}

@(private="file", require_results)
get_archetypes_pair_id_id :: #force_inline proc(world: ^World, rel, tgt: Entity) -> []^Archetype {
    return get_archetypes_id(world, id_make_pair(rel, tgt))
}

@(private="file", require_results)
get_archetypes_pair_type_type :: #force_inline proc(world: ^World, $Rel, $Tgt: typeid) -> []^Archetype {
    return get_archetypes_id(world, id_make_pair(
        get_component_id(world, Rel),
        get_component_id(world, Tgt),
    ))
}

@(private="file", require_results)
get_archetypes_pair_type_id :: #force_inline proc(world: ^World, $Rel: typeid, tgt: Entity) -> []^Archetype {
    return get_archetypes_id(world, id_make_pair(get_component_id(world, Rel), tgt))
}

@(private="file", require_results)
get_archetypes_pair_id_type :: #force_inline proc(world: ^World, rel: Entity, $Tgt: typeid) -> []^Archetype {
    return get_archetypes_id(world, id_make_pair(rel, get_component_id(world, Tgt)))
}

@private
add_raw :: proc(world: ^World, entity: Entity, id: Entity, data: rawptr = nil) {
    if !is_alive(world, entity) do return

    record := &world.entity_index[entity_id_idx(entity)]
    old_arch := record.archetype

    if old_arch != nil {
        if idx, found := slice.binary_search(old_arch.types, id); found {
            if data != nil {
                info := get_type_info(world, id)
                if info.size > 0 {
                    dst := rawptr(uintptr(raw_data(old_arch.columns[idx])) + uintptr(record.row * info.size))
                    mem.copy(dst, data, info.size)
                }
            }
            return
        }
    }

    new_arch := get_target_archetype(world, old_arch, id, true)
    new_row := move_entity(world, entity, new_arch)

    if data != nil {
        if idx, found := slice.binary_search(new_arch.types, id); found {
            info := get_type_info(world, id)
            if info.size > 0 {
                dst := rawptr(uintptr(raw_data(new_arch.columns[idx])) + uintptr(new_row * info.size))
                mem.copy(dst, data, info.size)
            }
        }
    }
}

@private
remove_raw :: proc(world: ^World, entity: Entity, id: Entity) {
    if !is_alive(world, entity) do return

    record := &world.entity_index[entity_id_idx(entity)]
    current_arch := record.archetype

    if current_arch == nil do return

    if _, found := slice.binary_search(current_arch.types, id); !found {
        return
    }

    new_arch := get_target_archetype(world, current_arch, id, false)
    if current_arch != new_arch {
        move_entity(world, entity, new_arch)
    }
}

@private
get_raw :: proc(world: ^World, entity: Entity, id: Entity) -> rawptr {
    if !is_alive(world, entity) do return nil

    record := &world.entity_index[entity_id_idx(entity)]
    arch := record.archetype
    if arch == nil do return nil

    idx, found := slice.binary_search(arch.types, id)
    if !found do return nil

    info := get_type_info(world, id)
    if info.size == 0 do return nil

    col_data := raw_data(arch.columns[idx])
    ptr := rawptr(uintptr(col_data) + uintptr(record.row * info.size))

    return ptr
}

@private
get_or_create_archetype :: proc(world: ^World, components: []Entity) -> ^Archetype {
    slice.sort(components)

    hash := hash_type_ids(components)
    if arch, ok := world.archetypes[hash]; ok {
        return arch
    }

    allocator := virtual.arena_allocator(&world.arena)

    arch := new(Archetype, allocator)
    arch.hash = hash
    arch.types = slice.clone(components, allocator)
    arch.columns = make([][]byte, len(arch.types))

    INITIAL_CAPACITY :: 4
    for id, i in arch.types {
        info := get_type_info(world, id)
        if info.size > 0 {
            arch.columns[i] = make([]byte, info.size * INITIAL_CAPACITY)
        }
    }

    for id in arch.types {
        if _, ok := world.component_index[id]; !ok {
            world.component_index[id] = make([dynamic]^Archetype)
        }
        append(&world.component_index[id], arch)
    }

    world.archetypes[hash] = arch

    for _, q in world.queries {
        if match_query(q, arch) {
            append(&q.archetypes, arch)
        }
    }

    return arch
}

@private
get_target_archetype :: proc(world: ^World, current: ^Archetype, id: Entity, is_add: bool) -> ^Archetype {
    if current != nil {
        if edge, ok := current.edges[id]; ok {
            target := is_add ? edge.add : edge.remove
            if target != nil do return target
        }
    }

    new_types: [dynamic]Entity
    if current != nil {
        new_types = slice.to_dynamic(current.types, context.temp_allocator)
    } else {
        new_types = make([dynamic]Entity, context.temp_allocator)
    }
    defer delete(new_types)

    idx := 0
    found := false
    if len(new_types) > 0 {
        idx, found = slice.binary_search(new_types[:], id)
    }

    if is_add {
        if found do return current
        inject_at(&new_types, idx, id)
    } else {
        if !found do return current
        ordered_remove(&new_types, idx)
    }

    if len(new_types) == 0 do return nil

    target := get_or_create_archetype(world, new_types[:])

    if current != nil {
        edge := current.edges[id]
        if is_add {
            edge.add = target
        } else {
            edge.remove = target
        }
        current.edges[id] = edge
    }

    return target
}

@private
remove_entity_row :: proc(world: ^World, arch: ^Archetype, row: int) {
    last_row := arch.len - 1

    if row != last_row {
        last_entity := arch.entities[last_row]
        arch.entities[row] = last_entity

        world.entity_index[entity_id_idx(last_entity)].row = row

        for data, i in arch.columns {
            info := get_type_info(world, arch.types[i])

            if info.size > 0 {
                dst_ptr := rawptr(uintptr(raw_data(data)) + uintptr(row * info.size))
                src_ptr := rawptr(uintptr(raw_data(data)) + uintptr(last_row * info.size))

                mem.copy(dst_ptr, src_ptr, info.size)
            }
        }
    }

    pop(&arch.entities)
    arch.len -= 1
}

@private
move_entity :: proc(world: ^World, entity: Entity, new_arch: ^Archetype) -> int {
    record := &world.entity_index[entity_id_idx(entity)]
    old_arch := record.archetype
    old_row := record.row

    if new_arch == nil {
        if old_arch != nil {
            remove_entity_row(world, old_arch, old_row)
        }
        record.archetype = nil
        record.row = -1
        return -1
    }

    new_row := append_entity_to_archetype(world, new_arch, entity)

    if old_arch != nil {
        i_new, i_old := 0, 0
        len_new, len_old := len(new_arch.types), len(old_arch.types)

        for i_new < len_new && i_old < len_old {
            type_new := new_arch.types[i_new]
            type_old := old_arch.types[i_old]

            info := get_type_info(world, type_new)
            if info.size == 0 {
                if type_new == type_old {
                    i_new += 1
                    i_old += 1
                } else if type_new < type_old do i_new += 1
                else do i_old += 1
                continue
            }

            dst_ptr := rawptr(uintptr(raw_data(new_arch.columns[i_new])) + uintptr(new_row * info.size))

            if type_new == type_old {
                src_ptr := rawptr(uintptr(raw_data(old_arch.columns[i_old])) + uintptr(old_row * info.size))
                mem.copy(dst_ptr, src_ptr, info.size)
                i_new += 1
                i_old += 1
            } else if type_new < type_old {
                mem.set(dst_ptr, 0, info.size)
                i_new += 1
            } else {
                i_old += 1
            }
        }

        for i_new < len_new {
            type_new := new_arch.types[i_new]
            info := get_type_info(world, type_new)

            if info.size > 0 {
                dst_ptr := rawptr(uintptr(raw_data(new_arch.columns[i_new])) + uintptr(new_row * info.size))
                mem.set(dst_ptr, 0, info.size)
            }
            i_new += 1
        }

        remove_entity_row(world, old_arch, old_row)

    } else {
        for id, i in new_arch.types {
            info := get_type_info(world, id)
            if info.size > 0 {
                dst_ptr := rawptr(uintptr(raw_data(new_arch.columns[i])) + uintptr(new_row * info.size))
                mem.set(dst_ptr, 0, info.size)
            }
        }
    }

    record.archetype = new_arch
    record.row = new_row

    return record.row
}

@private
append_entity_to_archetype :: proc(world: ^World, arch: ^Archetype, entity: Entity) -> int {
    row := arch.len

    for id, i in arch.types {
        info := get_type_info(world, id)
        if info.size == 0 do continue

        col := arch.columns[i]
        needed_size := (row + 1) * info.size

        if needed_size > len(col) {
            old_cap := len(col)
            new_cap := max(old_cap * 2, needed_size)

            new_data, err := make([]byte, new_cap)
            assert(err == .None, "ECS: Out of memory resizing column")

            if old_cap > 0 {
                mem.copy(raw_data(new_data), raw_data(col), old_cap)
                delete(col)
            }

            arch.columns[i] = new_data
        }
    }

    append(&arch.entities, entity)
    arch.len += 1
    return row
}

@(private="file")
hash_type_ids :: #force_inline proc "contextless" (types: []Entity) -> u64 {
    return hash.fnv64a(slice.to_bytes(types))
}