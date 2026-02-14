package ecs

import "core:slice"

create_entity :: proc(world: ^World) -> Entity {
    idx: u32
    gen: u16

    if len(world.free_indices) == 0 {
        idx = u32(len(world.entity_index))
        append(&world.entity_index, EntityRecord{})
    } else {
        idx = pop(&world.free_indices)
        gen = world.entity_index[idx].gen
    }

    return entity_id(idx, gen)
}

destroy_entity :: proc(world: ^World, entity: Entity) {
    if !is_alive(world, entity) do return

    idx := entity_id_idx(entity)
    record := &world.entity_index[idx]

    if record.archetype != nil {
        remove_entity_row(world, record.archetype, record.row)
    }

    record.gen += 1
    record.archetype = nil
    record.row = -1

    append(&world.free_indices, idx)
}

is_alive :: proc(world: ^World, entity: Entity) -> bool {
    if entity == 0 || id_is_pair(entity) do return false

    idx := entity_id_idx(entity)
    gen := entity_id_gen(entity)

    if int(idx) >= len(world.entity_index) {
        return false
    }

    return world.entity_index[idx].gen == gen
}

add :: proc {
    add_value,
    add_type,
    add_id,
    add_pair,
    add_pair_type_type,
    add_pair_id_id,
    add_pair_type_id,
    add_pair_id_type,
}

remove :: proc {
    remove_type,
    remove_id,
    remove_pair,
    remove_pair_type_type,
    remove_pair_id_id,
    remove_pair_type_id,
    remove_pair_id_type,
}

set :: proc {
    add_value,
    add_type,
    add_id,
    set_pair,
    set_pair_type_type,
    set_pair_id_id,
    set_pair_type_id,
    set_pair_id_type,
}

get :: proc {
    get_component,
    get_id,
}

has :: proc {
    has_type, 
    has_id,
    has_pair,
    has_pair_type_type,
    has_pair_id_id,
    has_pair_type_id,
    has_pair_id_type,
}

get_target :: proc {
    get_target_type,
    get_target_id,
}

get_components :: proc(world: ^World, entity: Entity) -> []Entity {
    if !is_alive(world, entity) do return nil

    record := &world.entity_index[entity_id_idx(entity)]
    if record.archetype == nil {
        return nil
    }

    return record.archetype.types
}

pair :: proc {
    pair_type_type,
    pair_id_id,
    pair_type_id,
    pair_id_type,
}

@private
pair_type_type :: #force_inline proc "contextless" ($Rel, $Tgt: typeid) -> Pair {
    rel: typeid = Rel
    tgt: typeid = Tgt
    return Pair{ relation = rel, target = tgt }
}

@private
pair_id_id :: #force_inline proc "contextless" (r, t: Entity)  -> Pair {
    return {r, t}
}

@private
pair_type_id :: #force_inline proc "contextless" ($Rel: typeid, t: Entity) -> Pair {
    rel: typeid = Rel
    return Pair{ relation = rel, target = t }
}

@private
pair_id_type :: #force_inline proc "contextless" (r: Entity, $Tgt: typeid) -> Pair {
    tgt: typeid = Tgt
    return Pair{ relation = r, target = tgt }
}

@(private="file")
add_value :: #force_inline proc(world: ^World, entity: Entity, value: $T) where T != Pair {
    val := value
    add_raw(world, entity, get_component_id(world, T), &val)
}

@(private="file")
add_type :: #force_inline proc(world: ^World, entity: Entity, $T: typeid) {
    add_raw(world, entity, get_component_id(world, T))
}

@(private="file")
add_id :: #force_inline proc(world: ^World, entity: Entity, id: Entity) {
    add_raw(world, entity, id)
}

@(private="file")
add_pair :: #force_inline proc(world: ^World, entity: Entity, pair: Pair) {
    add_raw(world, entity, pair_id(world, pair))
}

@(private="file")
add_pair_type_type :: #force_inline proc(world: ^World, entity: Entity, $Rel, $Tgt: typeid) {
    add_raw(world, entity, id_make_pair(
        get_component_id(world, Rel),
        get_component_id(world, Tgt),
    ))
}

@(private="file")
add_pair_id_id :: #force_inline proc(world: ^World, entity, rel, tgt: Entity) {
    add_raw(world, entity, id_make_pair(rel, tgt))
}

@(private="file")
add_pair_type_id :: #force_inline proc(world: ^World, entity: Entity, $Rel: typeid, tgt: Entity) {
    add_raw(world, entity, id_make_pair(get_component_id(world, Rel), tgt))
}

@(private="file")
add_pair_id_type :: #force_inline proc(world: ^World, entity, rel: Entity, $Tgt: typeid) {
    add_raw(world, entity, id_make_pair(rel, get_component_id(world, Tgt)))
}

@(private="file")
set_pair :: #force_inline proc(world: ^World, entity: Entity, pair: Pair) {
    set_pair_id_id(world, entity,
        resolve_id(world, pair.relation),
        resolve_id(world, pair.target)
    )
}

@(private="file")
set_pair_type_type :: #force_inline proc(world: ^World, entity: Entity, $Rel, $Tgt: typeid) {
    set_pair_id_id(world, entity, 
        get_component_id(world, Rel), 
        get_component_id(world, Tgt),
    )
}

@(private="file")
set_pair_id_id :: proc(world: ^World, entity, rel, tgt: Entity) {
    old_tgt, found := get_target_id(world, entity, rel)
    if found {
        if old_tgt == tgt do return
        remove_raw(world, entity, id_make_pair(rel, old_tgt))
    }

    add_raw(world, entity, id_make_pair(rel, tgt))
}

@(private="file")
set_pair_type_id :: #force_inline proc(world: ^World, entity: Entity, $Rel: typeid, tgt: Entity) {
    set_pair_id_id(world, entity, get_component_id(world, Rel), tgt)
}

@(private="file")
set_pair_id_type :: #force_inline proc(world: ^World, entity, rel: Entity, $Tgt: typeid) {
    set_pair_id_id(world, entity, rel, get_component_id(world, Tgt))
}

@(private="file")
remove_type :: #force_inline proc(world: ^World, entity: Entity, $T: typeid) {
    remove_raw(world, entity, get_component_id(world, T))
}

@(private="file")
remove_id :: #force_inline proc(world: ^World, entity: Entity, id: Entity) {
    remove_raw(world, entity, id)
}

@(private="file")
remove_pair :: #force_inline proc(world: ^World, entity: Entity, p: Pair) {
    remove_raw(world, entity, pair_id(world, p))
}

@(private="file")
remove_pair_type_type :: #force_inline proc(world: ^World, entity: Entity, $Rel, $Tgt: typeid) {
    remove_raw(world, entity, id_make_pair(
        get_component_id(world, Rel),
        get_component_id(world, Tgt),
    ))
}

@(private="file")
remove_pair_id_id :: #force_inline proc(world: ^World, entity, rel, tgt: Entity) {
    remove_raw(world, entity, id_make_pair(rel, tgt))
}

@(private="file")
remove_pair_type_id :: #force_inline proc(world: ^World, entity: Entity, $Rel: typeid, tgt: Entity) {
    remove_raw(world, entity, id_make_pair(get_component_id(world, Rel), tgt))
}

@(private="file")
remove_pair_id_type :: #force_inline proc(world: ^World, entity, rel: Entity, $Tgt: typeid) {
    remove_raw(world, entity, id_make_pair(rel, get_component_id(world, Tgt)))
}

@(private="file")
get_component :: #force_inline proc(world: ^World, entity: Entity, $T: typeid) -> ^T {
    ptr := get_raw(world, entity, get_component_id(world, T))
    return (^T)(ptr)
}

@(private="file")
get_id :: #force_inline proc(world: ^World, entity: Entity, id: Entity) -> rawptr {
    return get_raw(world, entity, id)
}

@(private="file", require_results)
has_type :: #force_inline proc(world: ^World, entity: Entity, $T: typeid) -> bool {
    return has_id(world, entity, get_component_id(world, T))
}

@(private="file", require_results)
has_id :: proc(world: ^World, entity: Entity, id: Entity) -> bool {
    if !is_alive(world, entity) do return false

    record := &world.entity_index[entity_id_idx(entity)]
    arch := record.archetype
    if arch == nil do return false

    _, found := slice.binary_search(arch.types, id)
    return found
}

@(private="file", require_results)
has_pair :: #force_inline proc(world: ^World, entity: Entity, p: Pair) -> bool {
    return has_id(world, entity, pair_id(world, p))
}

@(private="file", require_results)
has_pair_type_type :: #force_inline proc(world: ^World, entity: Entity, $Rel, $Tgt: typeid) -> bool {
    return has_id(world, entity, id_make_pair(
        get_component_id(world, Rel),
        get_component_id(world, Tgt),
    ))
}

@(private="file", require_results)
has_pair_id_id :: #force_inline proc(world: ^World, entity, rel, tgt: Entity) -> bool {
    return has_id(world, entity, id_make_pair(rel, tgt))
}

@(private="file", require_results)
has_pair_type_id :: #force_inline proc(world: ^World, entity: Entity, $Rel: typeid, tgt: Entity) -> bool {
    return has_id(world, entity, id_make_pair(get_component_id(world, Rel), tgt))
}

@(private="file", require_results)
has_pair_id_type :: #force_inline proc(world: ^World, entity, rel: Entity, $Tgt: typeid) -> bool {
    return has_id(world, entity, id_make_pair(rel, get_component_id(world, Tgt)))
}

@private
entity_id :: #force_inline proc "contextless" (index: u32, gen: u16) -> Entity {
    return Entity((u64(gen) << 32) | u64(index))
}

@private
entity_id_idx :: #force_inline proc "contextless" (entity: Entity) -> u32 {
    return u32(entity)
}

@private
entity_id_gen :: #force_inline proc "contextless" (entity: Entity) -> u16 {
    return u16(entity >> 32)
}

@(private, require_results)
id_is_pair :: #force_inline proc "contextless" (id: Entity) -> bool {
    return (u64(id) & ID_PAIR_FLAG) != 0
}

@private
resolve_id :: #force_inline proc(world: ^World, component: Component) -> Entity {
    switch v in component {
    case Entity: return v
    case typeid: return get_component_id(world, v)
    }
    return 0
}

@private
pair_id :: #force_inline proc(world: ^World, pair: Pair) -> Entity {
    assert(pair.relation != nil, "ECS: Pair relation cannot be nil")
    assert(pair.target != nil,   "ECS: Pair target cannot be nil")

    rel := resolve_id(world, pair.relation)
    tgt := resolve_id(world, pair.target)
    
    return id_make_pair(rel, tgt)
}

@(private, require_results)
id_make_pair :: #force_inline proc "contextless" (relation, target: Entity) -> Entity {
    return Entity(ID_PAIR_FLAG | (u64(relation) << 32) | u64(target))
}

@(private, require_results)
id_pair_first :: #force_inline proc "contextless" (id: Entity) -> Entity {
    return Entity((u64(id) & ~u64(ID_PAIR_FLAG)) >> 32)
}

@(private, require_results)
id_pair_second :: #force_inline proc "contextless" (id: Entity) -> Entity {
    return Entity(u64(id) & 0xFFFFFFFF)
}

@private
get_target_type :: #force_inline proc(world: ^World, entity: Entity, $Rel: typeid) -> (Entity, bool) {
    return get_target_id(world, entity, get_component_id(world, Rel))
}

@private
get_target_id :: proc(world: ^World, entity: Entity, relation: Entity) -> (Entity, bool) {
    if !is_alive(world, entity) do return 0, false

    record := &world.entity_index[entity_id_idx(entity)]
    arch := record.archetype
    if arch == nil do return 0, false

    for type in arch.types {
        if id_is_pair(type) {
            rel := id_pair_first(type)
            if rel == relation {
                return id_pair_second(type), true
            }
        }
    }

    return 0, false
}