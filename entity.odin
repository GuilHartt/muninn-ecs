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
    add_comp_value,
    add_comp_type,
    add_comp_id,
    add_pair_id_id,
    add_pair_type_id,
    add_pair_id_type,
    add_pair_type_type,
}

remove :: proc {
    remove_comp_type,
    remove_comp_id,
    remove_pair_id_id,
    remove_pair_type_id,
    remove_pair_id_type,
    remove_pair_type_type,
}

set :: proc {
    add_comp_value,
    add_comp_type,
    set_pair_id_id,
    set_pair_type_id,
    set_pair_id_type,
    set_pair_type_type,
}

get :: proc {
    get_component,
    get_id,
}

has :: proc {
    has_type,
    has_id,
    has_pair_id_id,
    has_pair_type_id,
    has_pair_id_type,
    has_pair_type_type,
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

@private
add_comp_value :: proc(world: ^World, entity: Entity, value: $T) {
    val := value
    add_raw(world, entity, get_component_id(world, T), &val)
}

@private
add_comp_type :: proc(world: ^World, entity: Entity, $T: typeid) {
    id := get_component_id(world, T)
    add_raw(world, entity, id, nil)
}

@private
add_comp_id :: proc(world: ^World, entity: Entity, id: Entity) {
    add_raw(world, entity, id, nil)
}

@private
add_pair_id_id :: #force_inline proc(world: ^World, entity: Entity, rel, tgt: Entity) {
    add_raw(world, entity, id_make_pair(rel, tgt), nil)
}

@private
add_pair_type_id :: #force_inline proc(world: ^World, entity: Entity, $Rel: typeid, tgt: Entity) {
    add_raw(world, entity, id_make_pair(get_component_id(world, Rel), tgt), nil)
}

@private
add_pair_id_type :: #force_inline proc(world: ^World, entity: Entity, rel: Entity, $Tgt: typeid) {
    add_raw(world, entity, id_make_pair(rel, get_component_id(world, Tgt)), nil)
}

@private
add_pair_type_type :: #force_inline proc(world: ^World, entity: Entity, $Rel: typeid, $Tgt: typeid) {
    r := get_component_id(world, Rel)
    t := get_component_id(world, Tgt)
    add_raw(world, entity, id_make_pair(r, t), nil)
}

@private
set_pair_id_id :: proc(world: ^World, entity: Entity, rel, tgt: Entity) {
    old_tgt, found := get_target_id(world, entity, rel)
    
    if found {
        if old_tgt == tgt do return
        remove_pair_id_id(world, entity, rel, old_tgt)
    }

    add_pair_id_id(world, entity, rel, tgt)
}

@private
set_pair_type_id :: proc(world: ^World, entity: Entity, $Rel: typeid, tgt: Entity) {
    rel := get_component_id(world, Rel)
    set_pair_id_id(world, entity, rel, tgt)
}

@private
set_pair_id_type :: proc(world: ^World, entity: Entity, rel: Entity, $Tgt: typeid) {
    tgt := get_component_id(world, Tgt)
    set_pair_id_id(world, entity, rel, tgt)
}

@private
set_pair_type_type :: proc(world: ^World, entity: Entity, $Rel: typeid, $Tgt: typeid) {
    rel := get_component_id(world, Rel)
    tgt := get_component_id(world, Tgt)
    set_pair_id_id(world, entity, rel, tgt)
}

@private
remove_comp_type :: proc(world: ^World, entity: Entity, $T: typeid) {
    id := get_component_id(world, T)
    remove_raw(world, entity, id)
}

@private
remove_comp_id :: proc(world: ^World, entity: Entity, id: Entity) {
    remove_raw(world, entity, id)
}

@private
remove_pair_id_id :: #force_inline proc(world: ^World, entity: Entity, rel, tgt: Entity) {
    remove_raw(world, entity, id_make_pair(rel, tgt))
}

@private
remove_pair_type_id :: #force_inline proc(world: ^World, entity: Entity, $Rel: typeid, tgt: Entity) {
    remove_raw(world, entity, id_make_pair(get_component_id(world, Rel), tgt))
}

@private
remove_pair_id_type :: #force_inline proc(world: ^World, entity: Entity, rel: Entity, $Tgt: typeid) {
    remove_raw(world, entity, id_make_pair(rel, get_component_id(world, Tgt)))
}

@private
remove_pair_type_type :: #force_inline proc(world: ^World, entity: Entity, $Rel: typeid, $Tgt: typeid) {
    r := get_component_id(world, Rel)
    t := get_component_id(world, Tgt)
    remove_raw(world, entity, id_make_pair(r, t))
}

@private
get_component :: proc(world: ^World, entity: Entity, $T: typeid) -> ^T {
    ptr := get_raw(world, entity, get_component_id(world, T))
    return (^T)(ptr)
}

@private
get_id :: proc(world: ^World, entity: Entity, id: Entity) -> rawptr {
    return get_raw(world, entity, id)
}

@private
has_type :: proc(world: ^World, entity: Entity, $T: typeid) -> bool {
    return has_id(world, entity, get_component_id(world, T))
}

@private
has_id :: proc(world: ^World, entity: Entity, id: Entity) -> bool {
    if !is_alive(world, entity) do return false

    record := &world.entity_index[entity_id_idx(entity)]
    arch := record.archetype
    if arch == nil do return false

    _, found := slice.binary_search(arch.types, id)
    return found
}

@private
has_pair_id_id :: #force_inline proc(world: ^World, entity: Entity, rel, tgt: Entity) -> bool {
    return has_id(world, entity, id_make_pair(rel, tgt))
}

@private
has_pair_type_id :: #force_inline proc(world: ^World, entity: Entity, $Rel: typeid, tgt: Entity) -> bool {
    return has_id(world, entity, id_make_pair(get_component_id(world, Rel), tgt))
}

@private
has_pair_id_type :: #force_inline proc(world: ^World, entity: Entity, rel: Entity, $Tgt: typeid) -> bool {
    return has_id(world, entity, id_make_pair(rel, get_component_id(world, Tgt)))
}

@private
has_pair_type_type :: #force_inline proc(world: ^World, entity: Entity, $Rel: typeid, $Tgt: typeid) -> bool {
    return has_id(world, entity, id_make_pair(get_component_id(world, Rel), get_component_id(world, Tgt)))
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
get_target_type :: proc(world: ^World, entity: Entity, $Rel: typeid) -> (Entity, bool) {
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