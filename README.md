<div align="center" width="100%">
<a href="https://github.com/GuilHartt/muninn">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/static/muninn-logo-dark.png">
  <source media="(prefers-color-scheme: light)" srcset="docs/static/muninn-logo-light.png">
  <img alt="Muninn ECS Logo" src="docs/static/muninn-logo-light.png" width="400">
</picture>
</a>

[![License](https://img.shields.io/badge/license-zlib-blue)](LICENSE)
[![Language](https://img.shields.io/badge/language-Odin-orange)](https://odin-lang.org/)
[![GitHub](https://img.shields.io/badge/github-repo-blue?logo=github)](https://github.com/GuilHartt/muninn)
[![Sponsor](https://img.shields.io/badge/Sponsor-Pink?logo=github-sponsors)](https://github.com/sponsors/GuilHartt)

**muninn** is a lightweight, high-performance, archetype-based Entity Component System (ECS) written in **Odin**.

*“Muninn” — Norse for “memory”, the raven that flies over Midgard to bring information to Odin.*

&mdash;&mdash;

[Installation](#installation) &nbsp; &bull; &nbsp; [Usage](#usage) &nbsp; &bull; &nbsp; [Roadmap](#roadmap) &nbsp; &bull; &nbsp; [Documentation](#documentation)
</div>

<br>

A cache-optimized ECS implementing archetype-based **SoA** storage. By packing entities with identical component signatures into contiguous memory blocks, **muninn** maximizes data locality and enables high-throughput linear iteration, minimizing CPU cache misses.

> [!IMPORTANT]
>`muninn` is developed as the core ECS for **Sweet Engine**. The API is experimental and subject to change as the engine's requirements evolve.

## Installation

Clone the repository directly into your project's `shared` or `libs` directory:

```bash
git clone https://github.com/GuilHartt/muninn libs/muninn

```

## Usage

```odin
package main

import ecs "libs/muninn/ecs"

Position :: distinct [2]f32
Velocity :: distinct [2]f32

main :: proc() {
    world := ecs.create_world()

    e := ecs.create_entity(world)
    ecs.add(world, e, Position{0, 0})
    ecs.add(world, e, Velocity{1, 1})

    q := ecs.query(world, ecs.with(Position), ecs.with(Velocity))

    ecs.each(world, q, proc(e: ecs.Entity, pos: ^Position, vel: ^Velocity) {
        pos.x += vel.x
        pos.y += vel.y
    })

    ecs.destroy_world(world)
}

```

## Roadmap

The goal is to provide a robust foundation for data-oriented games in Odin.

* [x] **Archetype Storage**: Contiguous **SoA** memory layout for maximum cache locality and SIMD-friendliness.
* [x] **Entity Relationships**: First-class support for Pairs (e.g., `ChildOf, Parent`) and Wildcard matching.
* [x] **Queries**: Efficient filtering with `With`, `Without`, and cached archetype iteration.
* [x] **Iterators**: High-level syntax wrappers to reduce boilerplate in query loops.
* [ ] **Component Toggling**: Enable or disable components without triggering structural changes, preserving archetype stability and performance.
* [ ] **Observers**: Event-driven hooks for component lifecycle events (Add, Remove, Set).
* [ ] **Resources**: Singleton storage for world-scoped data (e.g., `Camera`, `PhysicsWorld`), avoiding global state.
* [ ] **Command Buffer**: Queue deferred operations to safely modify world structure during system execution.

## Documentation

Comprehensive documentation is currently being written and will be hosted on **GitHub Pages**.

## License

This project is licensed under the **zlib License**.

See the [LICENSE](LICENSE) file for the full legal text.

---

**Credits**: Created by [Guilherme Avelar (GuilHartt)](https://github.com/GuilHartt)