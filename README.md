<div align="center" width="100%">
<a href="https://github.com/GuilHartt/muninn-ecs">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/static/muninn-logo-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="docs/static/muninn-logo-light.png">
  <img alt="Muninn ECS Logo" src="docs/static/muninn-logo-light.png" width="400">
</picture>
</a>

[![License](https://img.shields.io/badge/license-zlib-blue)](LICENSE)
[![Language](https://img.shields.io/badge/language-Odin-orange)](https://odin-lang.org/)
[![GitHub](https://img.shields.io/badge/github-repo-blue?logo=github)](https://github.com/GuilHartt/muninn-ecs)

**muninn-ecs** is a lightweight, high-performance, archetype-based Entity Component System (ECS) written in **Odin**.

*“Muninn” — Norse for “memory”, the raven that flies over Midgard to bring information to Odin.*

&mdash;&mdash;

[Installation](#installation) &nbsp; &bull; &nbsp; [Usage](#usage) &nbsp; &bull; &nbsp; [Roadmap](#roadmap) &nbsp; &bull; &nbsp; [Documentation](#documentation)
</div>

<br>

A cache-optimized ECS implementing archetype-based **SoA** storage. By packing entities with identical component signatures into contiguous memory blocks, **muninn-ecs** maximizes data locality and enables high-throughput linear iteration, minimizing CPU cache misses.

> [!IMPORTANT]
>`muninn-ecs` is developed as the core ECS for **Sweet Engine**. The API is experimental and subject to change as the engine's requirements evolve.

## Installation

Clone the repository directly into your project's `shared` or `libs` directory:

```bash
git clone https://github.com/GuilHartt/muninn-ecs libs/muninn-ecs

```

## Usage

```odin
package main

import ecs "libs/muninn-ecs"

// Define Components
// distinct prevents accidental mixing of types (e.g. pos += vel requires cast)
Position :: distinct [2]f32
Velocity :: distinct [2]f32

main :: proc() {
    // 1. Initialize World
    world := ecs.create_world(); defer ecs.destroy_world(world)

    // 2. Create Entity
    entity := ecs.create_entity(world)
    ecs.add(world, entity, Position{0, 0})
    ecs.add(world, entity, Velocity{5, 5})

    // 3. Query and Update
    // Selects entities that have both Position and Velocity
    q := ecs.query(world, ecs.with(Position), ecs.with(Velocity))

    for arch in q.archetypes {
        // Direct access to component memory slices (SoA)
        pos := ecs.get_view(world, arch, Position)
        vel := ecs.get_view(world, arch, Velocity)

        #no_bounds_check for i in 0..<arch.len {
            // Since types are distinct, we cast Velocity to Position for vector addition
            pos[i] += Position(vel[i])
        }
    }
}

```

## Roadmap

The goal is to provide a robust foundation for data-oriented games in Odin.

* [x] **Archetype Storage**: Contiguous **SoA** memory layout for maximum cache locality and SIMD-friendliness.
* [x] **Entity Relationships**: First-class support for Pairs (e.g., `ChildOf, Parent`) and Wildcard matching.
* [x] **Queries**: Efficient filtering with `With`, `Without`, and cached archetype iteration.
* [ ] **Component Toggling**: Enable or disable components without triggering structural changes, preserving archetype stability and performance.
* [ ] **Observers**: Event-driven hooks for component lifecycle events (Add, Remove, Set).
* [ ] **Resources**: Singleton storage for world-scoped data (e.g., `Camera`, `PhysicsWorld`), avoiding global state.
* [ ] **Command Buffer**: Queue deferred operations to safely modify world structure during system execution.
* [ ] **Iterators**: High-level syntax wrappers to reduce boilerplate in query loops.

## Documentation

Comprehensive documentation is currently being written and will be hosted on **GitHub Pages**.

## License

This project is licensed under the **zlib License**.

See the [LICENSE](LICENSE) file for the full legal text.

---

**Credits**: Created by [Guilherme Avelar (GuilHartt)](https://github.com/GuilHartt)