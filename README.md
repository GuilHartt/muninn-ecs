# muninn-ecs

**muninn-ecs** is a lightweight, high-performance, archetype-based Entity Component System (ECS) written in strictly typed **Odin**.

Named after *Muninn* (Old Norse for "memory"), one of the two ravens that accompany the Norse God **Odin**, this library focuses on efficient memory layout and cache-friendly iteration, ensuring your game data is always where it needs to be.

## Features

* 🦅 **Pure Odin**: Built using only `core` libraries (`virtual`, `mem`, `slice`, `hash`).
* 🚀 **Archetype-based**: Entities with the same components are grouped together in contiguous memory for maximum cache efficiency.
* 🧠 **Smart Memory**: Uses `core:mem/virtual` arenas for stable and fast allocation.
* 🔗 **Entity Relationships (Pairs)**: First-class support for relationship pairs (e.g., `Likes, Apple` or `ChildOf, Parent`), similar to Flecs.
* 🔍 **Flexible Queries**: Support for `With`, `Without`, and Wildcard matching in pairs.

## Installation

`muninn-ecs` is designed to be vendored directly into your project.

1.  Clone this repository into your project's `shared` or `libs` folder.
2.  Import it in your Odin files:

```odin
import ecs "libs/muninn-ecs"

```

## Quick Start

### 1. Define Components

Components are just plain Odin structs or distinct types.

```odin
Position :: distinct [2]f32
Velocity :: distinct [2]f32
Player   :: struct {} // Tag component
Enemy    :: struct {}
Dead     :: struct {}

```

### 2. Create the World

Initialize the ECS world context.

```odin
import "core:fmt"
import ecs "libs/muninn-ecs"

main :: proc() {
    // Create world with default capacity (1024)
    world := ecs.create_world()
    defer ecs.destroy_world(world)
}

```

### 3. Create Entities

Add components or tags to entities.

```odin
// Create an entity with ID and Components
entity := ecs.create_entity(world)

ecs.add(world, entity, Position{0, 0})
ecs.add(world, entity, Velocity{10, 5})
ecs.add(world, entity, Player)

// You can also remove components
// ecs.remove(world, entity, Player)

```

### 4. Systems & Queries

Iterate over entities efficiently using archetypes.

```odin
update_movement :: proc(world: ^ecs.World, dt: f32) {
    // Create a query
    // Example: Select all entities with Position AND Velocity
    movement_query := ecs.query(world, ecs.with(Position), ecs.with(Velocity))

    // Iterate over matching archetypes
    for arch in movement_query.archetypes {
        // Get strict slices of component data (SoA layout)
        pos := ecs.table(world, arch, Position)
        vel := ecs.table(world, arch, Velocity)

        // Iterate efficiently
        #no_bounds_check for i in 0..<arch.len {
            pos[i].x += vel[i].x * dt
            pos[i].y += vel[i].y * dt
        }
    }
}

```

### Filtering with "Without"

You can exclude entities that have specific components using `ecs.without`.

```odin
update_living_enemies :: proc(world: ^ecs.World) {
    // Select Enemies that do NOT have the Dead tag
    living_enemies := ecs.query(world, 
        ecs.with(Enemy), 
        ecs.without(Dead),
    )

    for arch in living_enemies.archetypes {
        // ... update logic
    }
}

```

## Advanced Usage

### Entity Relationships

`muninn-ecs` supports adding pairs of components/IDs to express relationships between entities or data.

```odin
Likes :: struct {} // Relation tag
Apple :: struct {}
Pear  :: struct {}

bob := ecs.create_entity(world)

// Add a pair (Relation, Target)
ecs.add(world, bob, Likes, Apple)

```

### Querying Relationships

You can query relationships just like regular components. You can also use `ecs.Wildcard` to match specific patterns.

```odin
// 1. Exact Match: Find entities that specifically Like Apples
query_likes_apples := ecs.query(world, ecs.with(Likes, Apple))

// 2. Wildcard Match: Find entities that Like ANYTHING
// This matches (Likes, Apple), (Likes, Pear), etc.
query_likes_anything := ecs.query(world, ecs.with(Likes, ecs.Wildcard))

// 3. Combined: Find Players who Like Apples
query_players_liking_apples := ecs.query(world, 
    ecs.with(Player), 
    ecs.with(Likes, Apple),
)

```

## License

This project is licensed under the **zlib License** - see the [LICENSE](LICENSE) file for details.

---

**Credits**: Created by [Guilherme Avelar (GuilHartt)](https://github.com/GuilHartt)