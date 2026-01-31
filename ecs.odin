package ecs

import "core:hash"
import "core:mem"
import "core:mem/virtual"
import "core:slice"

ID_PAIR_FLAG :: 0x8000_0000_0000_0000

EntityID :: distinct u64
Wildcard :: EntityID(0)

TermValue :: union {
    EntityID,
    typeid
}

TermType :: enum u64 {
    With,
    Without
}

QueryTermInput :: struct {
    relation: TermValue,
    target:   TermValue,
    mode:     TermType,
    is_pair:  bool,
}

QueryTerm :: struct {
    id:   EntityID,
    mode: TermType,
}

ArchetypeEdge :: struct {
    add, remove: ^Archetype
}

Archetype :: struct {
    hash:     u64,
    entities: [dynamic]EntityID,
    types:    []EntityID,
    columns:  [][]byte,
    len:      int,
    edges:    map[EntityID]ArchetypeEdge,
}

EntityRecord :: struct {
    archetype: ^Archetype,
    row:       int,
    gen:       u16,
}

TypeInfo :: struct {
    id:    EntityID,
    size:  int,
    align: int,
}

Query :: struct {
    hash:       u64,
    terms:      [16]QueryTerm,
    archetypes: [dynamic]^Archetype,
}

World :: struct {
    entity_index:    [dynamic]EntityRecord,
    free_indices:    [dynamic]u32,
    archetypes:      map[u64]^Archetype,
    queries:         map[u64]^Query,
    type_info:       map[EntityID]TypeInfo,
    component_id:    map[typeid]EntityID,
    component_index: map[EntityID][dynamic]^Archetype,
    arena:           virtual.Arena,
}

create_world :: proc(capacity := 1024, allocator := context.allocator) -> ^World {
    world := new(World, allocator)

    if err := virtual.arena_init_growing(&world.arena); err != nil {
        panic("ECS: Failed to initialize virtual arena")
    }

    reserve(&world.entity_index, capacity)
    reserve(&world.free_indices, capacity)

    append(&world.entity_index, EntityRecord{})

    return world
}

destroy_world :: proc(world: ^World) {
    if world == nil do return

    for _, arch in world.archetypes {
        delete(arch.entities)
        delete(arch.edges)

        for col in arch.columns {
            delete(col)
        }
        delete(arch.columns)
    }
    delete(world.archetypes)

    for _, list in world.component_index {
        delete(list)
    }
    delete(world.component_index)

    delete(world.queries)

    delete(world.entity_index)
    delete(world.free_indices)
    delete(world.type_info)
    delete(world.component_id)

    virtual.arena_destroy(&world.arena)

    free(world)
}

create_entity :: proc(world: ^World) -> EntityID {
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

is_alive :: proc(world: ^World, entity: EntityID) -> bool {
    if entity == 0 || id_is_pair(entity) do return false

    idx := entity_id_idx(entity)
    gen := entity_id_gen(entity)

    if int(idx) >= len(world.entity_index) {
        return false
    }

    return world.entity_index[idx].gen == gen
}

destroy_entity :: proc(world: ^World, entity: EntityID) {
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

add :: proc {
    add_comp_value,
    add_comp_type,
    add_comp_id,
    add_pair_id_id,
    add_pair_type_id,
    add_pair_type_type,
    add_pair_id_type,
}

remove :: proc {
    remove_comp_type,
    remove_comp_id,
    remove_pair_id_id,
    remove_pair_type_id,
    remove_pair_type_type,
    remove_pair_id_type,
}

set :: proc {
    add_comp_value,
    add_comp_type,
    set_pair_id_id,
    set_pair_type_id,
    set_pair_type_type,
    set_pair_id_type,
}

get :: proc {
    get_component,
    get_pair,
    get_id,
}

has :: proc {
    has_type,
    has_pair,
    has_id,
}

table :: proc(world: ^World, arch: ^Archetype, $T: typeid) -> []T {
    if arch.len == 0 do return nil

    idx, found := slice.binary_search(arch.types, get_component_id(world, T))
    if !found {
        return nil
    }

    raw_bytes := raw_data(arch.columns[idx])
    return ([^]T)(raw_bytes)[:arch.len]
}

with :: proc { 
    with_type, 
    with_id, 
    with_pair_id_id, 
    with_pair_type_id, 
    with_pair_id_type,
    with_pair_type_type,
}

without :: proc { 
    without_type, 
    without_id, 
    without_pair_id_id, 
    without_pair_type_id, 
    without_pair_id_type, 
    without_pair_type_type,
}

query :: proc(world: ^World, inputs: ..QueryTermInput) -> ^Query {
    terms: [16]QueryTerm
    count := min(len(inputs), 16)
    
    for i in 0..<count {
        inp := inputs[i]
        final_id: EntityID

        r_id: EntityID
        switch v in inp.relation {
        case EntityID: r_id = v
        case typeid:   r_id = get_component_id(world, v)
        }

        if inp.is_pair {
            t_id: EntityID
            switch v in inp.target {
            case EntityID: t_id = v
            case typeid:   t_id = get_component_id(world, v)
            }
            final_id = id_make_pair(r_id, t_id)
        } else {
            final_id = r_id
        }

        terms[i] = QueryTerm{ id = final_id, mode = inp.mode }
    }

    hash := hash_query_terms(terms[:count])

    q, found := world.queries[hash]
    if !found {
        allocator := virtual.arena_allocator(&world.arena)

        q = new(Query, allocator)
        q.hash = hash
        q.terms = terms
        q.archetypes = make([dynamic]^Archetype, allocator)

        for _, arch in world.archetypes {
            if match_query(q, arch) {
                append(&q.archetypes, arch)
            }
        }
        
        world.queries[hash] = q
    }

    return q
}

count_entites :: #force_inline proc "contextless" (query: ^Query) -> (count: int) {
    for arch in query.archetypes {
        count += arch.len
    }
    return
}

@private with_type :: #force_inline proc($T: typeid) -> QueryTermInput {
    val: typeid = T
    return QueryTermInput{ relation = val, mode = .With, is_pair = false }
}

@private with_id :: #force_inline proc(id: EntityID) -> QueryTermInput {
    return QueryTermInput{ relation = id, mode = .With, is_pair = false }
}

@private with_pair_id_id :: #force_inline proc(relation, target: EntityID) -> QueryTermInput {
    return QueryTermInput{ relation = relation, target = target, mode = .With, is_pair = true }
}

@private with_pair_type_id :: #force_inline proc($Rel: typeid, target: EntityID) -> QueryTermInput {
    r: typeid = Rel
    return QueryTermInput{ relation = r, target = target, mode = .With, is_pair = true }
}

@private with_pair_id_type :: #force_inline proc(relation: EntityID, $Tgt: typeid) -> QueryTermInput {
    t: typeid = Tgt
    return QueryTermInput{ relation = relation, target = t, mode = .With, is_pair = true }
}

@private with_pair_type_type :: #force_inline proc($Rel: typeid, $Tgt: typeid) -> QueryTermInput {
    r: typeid = Rel
    t: typeid = Tgt
    return QueryTermInput{ relation = r, target = t, mode = .With, is_pair = true }
}

@private without_type :: #force_inline proc($T: typeid) -> QueryTermInput {
    val: typeid = T
    return QueryTermInput{ relation = val, mode = .Without, is_pair = false }
}

@private without_id :: #force_inline proc(id: EntityID) -> QueryTermInput {
    return QueryTermInput{ relation = id, mode = .Without, is_pair = false }
}

@private without_pair_id_id :: #force_inline proc(relation, target: EntityID) -> QueryTermInput {
    return QueryTermInput{ relation = relation, target = target, mode = .Without, is_pair = true }
}

@private without_pair_type_id :: #force_inline proc($Rel: typeid, target: EntityID) -> QueryTermInput {
    r: typeid = Rel
    return QueryTermInput{ relation = r, target = target, mode = .Without, is_pair = true }
}

@private without_pair_id_type :: #force_inline proc(relation: EntityID, $Tgt: typeid) -> QueryTermInput {
    t: typeid = Tgt
    return QueryTermInput{ relation = relation, target = t, mode = .Without, is_pair = true }
}

@private without_pair_type_type :: #force_inline proc($Rel: typeid, $Tgt: typeid) -> QueryTermInput {
    r: typeid = Rel
    t: typeid = Tgt
    return QueryTermInput{ relation = r, target = t, mode = .Without, is_pair = true }
}

@private add_comp_value :: proc(world: ^World, entity: EntityID, value: $T) {
    val := value
    add_raw(world, entity, get_component_id(world, T), &val)
}

@private add_comp_type :: proc(world: ^World, entity: EntityID, $T: typeid) {
    id := get_component_id(world, T)
    add_raw(world, entity, id, nil)
}

@private add_comp_id :: proc(world: ^World, entity: EntityID, id: EntityID) {
    add_raw(world, entity, id, nil)
}

@private add_pair_id_id :: proc(world: ^World, entity: EntityID, relation, target: EntityID) {
    id := id_make_pair(relation, target)
    add_raw(world, entity, id, nil)
}

@private add_pair_type_id :: proc(world: ^World, entity: EntityID, $Rel: typeid, target: EntityID) {
    r := get_component_id(world, Rel)
    add_raw(world, entity, id_make_pair(r, target), nil)
}

@private add_pair_type_type :: proc(world: ^World, entity: EntityID, $Rel: typeid, $Tgt: typeid) {
    r := get_component_id(world, Rel)
    t := get_component_id(world, Tgt)
    add_raw(world, entity, id_make_pair(r, t), nil)
}

@private add_pair_id_type :: proc(world: ^World, entity: EntityID, relation: EntityID, $Tgt: typeid) {
    t := get_component_id(world, Tgt)
    add_raw(world, entity, id_make_pair(relation, t), nil)
}

@private add_raw :: proc(world: ^World, entity: EntityID, id: EntityID, data: rawptr) {
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

@private remove_comp_type :: proc(world: ^World, entity: EntityID, $T: typeid) {
    id := get_component_id(world, T)
    remove_raw(world, entity, id)
}

@private remove_comp_id :: proc(world: ^World, entity: EntityID, id: EntityID) {
    remove_raw(world, entity, id)
}

@private remove_pair_id_id :: proc(world: ^World, entity: EntityID, relation, target: EntityID) {
    id := id_make_pair(relation, target)
    remove_raw(world, entity, id)
}

@private remove_pair_type_id :: proc(world: ^World, entity: EntityID, $Rel: typeid, target: EntityID) {
    r := get_component_id(world, Rel)
    remove_raw(world, entity, id_make_pair(r, target))
}

@private remove_pair_type_type :: proc(world: ^World, entity: EntityID, $Rel: typeid, $Tgt: typeid) {
    r := get_component_id(world, Rel)
    t := get_component_id(world, Tgt)
    remove_raw(world, entity, id_make_pair(r, t))
}

@private remove_pair_id_type :: proc(world: ^World, entity: EntityID, relation: EntityID, $Tgt: typeid) {
    t := get_component_id(world, Tgt)
    remove_raw(world, entity, id_make_pair(relation, t))
}

@private remove_raw :: proc(world: ^World, entity: EntityID, id: EntityID) {
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

@private set_pair_id_id :: proc(world: ^World, entity: EntityID, relation, target: EntityID) {
    if !is_alive(world, entity) do return

    idx := entity_id_idx(entity)
    record := &world.entity_index[idx]
    arch := record.archetype

    if arch != nil {
        for type in arch.types {
            if id_is_pair(type) {
                rel := id_pair_first(type)
                if rel == relation {
                    tgt := id_pair_second(type)
                    if tgt == target do return 

                    remove_raw(world, entity, type)
                    break
                }
            }
        }
    }

    add_raw(world, entity, id_make_pair(relation, target), nil)
}

@private set_pair_type_id :: proc(world: ^World, entity: EntityID, $Rel: typeid, target: EntityID) {
    r := get_component_id(world, Rel)
    set_pair_id_id(world, entity, r, target)
}

@private set_pair_type_type :: proc(world: ^World, entity: EntityID, $Rel: typeid, $Tgt: typeid) {
    r := get_component_id(world, Rel)
    t := get_component_id(world, Tgt)
    set_pair_id_id(world, entity, r, t)
}

@private set_pair_id_type :: proc(world: ^World, entity: EntityID, relation: EntityID, $Tgt: typeid) {
    t := get_component_id(world, Tgt)
    set_pair_id_id(world, entity, relation, t)
}

@private get_component :: proc(world: ^World, entity: EntityID, $T: typeid) -> ^T {
    id := get_component_id(world, T)
    ptr := get_raw(world, entity, id)
    return (^T)(ptr)
}

@private get_pair :: proc(world: ^World, entity: EntityID, relation, target: EntityID) -> rawptr {
    id := id_make_pair(relation, target)
    return get_raw(world, entity, id)
}

@private get_id :: proc(world: ^World, entity: EntityID, id: EntityID) -> rawptr {
    return get_raw(world, entity, id)
}

@private get_raw :: proc(world: ^World, entity: EntityID, id: EntityID) -> rawptr {
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

@private has_type :: proc(world: ^World, entity: EntityID, $T: typeid) -> bool {
    id := get_component_id(world, T)
    return has_id(world, entity, id)
}

@private has_pair :: proc(world: ^World, entity: EntityID, relation, target: EntityID) -> bool {
    id := id_make_pair(relation, target)
    return has_id(world, entity, id)
}

@private has_id :: proc(world: ^World, entity: EntityID, id: EntityID) -> bool {
    if !is_alive(world, entity) do return false

    record := &world.entity_index[entity_id_idx(entity)]
    arch := record.archetype
    if arch == nil do return false

    _, found := slice.binary_search(arch.types, id)
    return found
}

@private
get_or_create_archetype :: proc(world: ^World, components: []EntityID) -> ^Archetype {
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
get_target_archetype :: proc(world: ^World, current: ^Archetype, id: EntityID, is_add: bool) -> ^Archetype {
    if current != nil {
        if edge, ok := current.edges[id]; ok {
            target := is_add ? edge.add : edge.remove
            if target != nil do return target
        }
    }

    allocator := virtual.arena_allocator(&world.arena)

    new_types: [dynamic]EntityID
    if current != nil {
        new_types = slice.to_dynamic(current.types, allocator)
    } else {
        new_types = make([dynamic]EntityID, allocator)
    }

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

@(private)
move_entity :: proc(world: ^World, entity: EntityID, new_arch: ^Archetype) -> int {
    record := &world.entity_index[entity_id_idx(entity)]
    old_arch := record.archetype
    old_row := record.row

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

@(private)
append_entity_to_archetype :: proc(world: ^World, arch: ^Archetype, entity: EntityID) -> int {
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

@(private)
get_type_info :: #force_inline proc "contextless" (world: ^World, id: EntityID) -> TypeInfo {
    if id_is_pair(id) {
        return TypeInfo{id = id, size = 0, align = 1}
    }
    if info, ok := world.type_info[id]; ok {
        return info
    }
    return TypeInfo{id = id, size = 0, align = 1}
}

@(private)
get_component_id :: proc(world: ^World, type: typeid) -> EntityID {
    if id, ok := world.component_id[type]; ok {
        return id
    }

    id := create_entity(world)
    ti := type_info_of(type)

    world.component_id[type] = id
    world.type_info[id] = TypeInfo{id = id, size = ti.size, align = ti.align}

    return id
}

@private
match_query :: proc(query: ^Query, arch: ^Archetype) -> bool {
    for term in query.terms {
        if term.id == 0 do break

        found := false
        if id_is_pair(term.id) {
            rel := id_pair_first(term.id)
            tgt := id_pair_second(term.id)

            if rel == Wildcard || tgt == Wildcard {
                for type in arch.types {
                    if !id_is_pair(type) do continue
                    
                    r := id_pair_first(type)
                    t := id_pair_second(type)

                    match_rel := (rel == Wildcard) || (rel == r)
                    match_tgt := (tgt == Wildcard) || (tgt == t)

                    if match_rel && match_tgt {
                        found = true
                        break
                    }
                }
            } else {
                _, found = slice.binary_search(arch.types, term.id)
            }
        } else {
            _, found = slice.binary_search(arch.types, term.id)
        }

        if term.mode == .With {
            if !found do return false
        } else {
            if found do return false
        }
    }
    return true
}

@private
hash_query_terms :: proc(terms: []QueryTerm) -> u64 {
    slice.sort_by(terms, proc(i, j: QueryTerm) -> bool {
        return i.id < j.id
    })
    return hash.fnv64a(slice.to_bytes(terms))
}

@private
hash_type_ids :: #force_inline proc "contextless" (types: []EntityID) -> u64 {
    return hash.fnv64a(slice.to_bytes(types))
}

@private
entity_id :: #force_inline proc "contextless" (index: u32, gen: u16) -> EntityID {
    return EntityID((u64(gen) << 32) | u64(index))
}

@private
entity_id_idx :: #force_inline proc "contextless" (entity: EntityID) -> u32 {
    return u32(entity)
}

@private
entity_id_gen :: #force_inline proc "contextless" (entity: EntityID) -> u16 {
    return u16(entity >> 32)
}

@(private, require_results)
id_is_pair :: #force_inline proc "contextless" (id: EntityID) -> bool {
    return (u64(id) & ID_PAIR_FLAG) != 0
}

@(private, require_results)
id_make_pair :: #force_inline proc "contextless" (relation, target: EntityID) -> EntityID {
    return EntityID(ID_PAIR_FLAG | (u64(relation) << 32) | u64(target))
}

@(private, require_results)
id_pair_first :: #force_inline proc "contextless" (id: EntityID) -> EntityID {
    return EntityID((u64(id) & ~u64(ID_PAIR_FLAG)) >> 32)
}

@(private, require_results)
id_pair_second :: #force_inline proc "contextless" (id: EntityID) -> EntityID {
    return EntityID(u64(id) & 0xFFFFFFFF)
}