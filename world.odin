package ecs

import "core:mem/virtual"

World :: struct {
    entity_index:    [dynamic]EntityRecord,
    free_indices:    [dynamic]u32,

    archetypes:      map[u64]^Archetype,
    queries:         map[u64]^Query,

    type_info:       map[Entity]TypeInfo,
    component_id:    map[typeid]Entity,

    component_index: map[Entity][dynamic]^Archetype,

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

@private
get_type_info :: #force_inline proc "contextless" (world: ^World, id: Entity) -> TypeInfo {
    if id_is_pair(id) {
        return TypeInfo{id = id, size = 0, align = 1}
    }
    if info, ok := world.type_info[id]; ok {
        return info
    }
    return TypeInfo{id = id, size = 0, align = 1}
}

@private
get_component_id :: proc(world: ^World, type: typeid) -> Entity {
    if id, ok := world.component_id[type]; ok {
        return id
    }

    id := create_entity(world)
    ti := type_info_of(type)

    world.component_id[type] = id
    world.type_info[id] = TypeInfo{id = id, size = ti.size, align = ti.align}

    return id
}