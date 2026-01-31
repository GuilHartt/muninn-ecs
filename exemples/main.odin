package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

// Import the ECS from the parent directory
import ecs "../" 

// --- Components ---
// We use distinct to ensure type safety (e.g., distinguishing Position from Velocity)
Position :: distinct [2]f32
Velocity :: distinct [2]f32
Color    :: distinct rl.Color
Radius   :: distinct f32

// Window Constants
SCREEN_WIDTH  :: 800
SCREEN_HEIGHT :: 600

main :: proc() {
    // 1. Initialize Raylib
    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Muninn ECS + Raylib Demo")
    rl.SetTargetFPS(60)
    defer rl.CloseWindow()

    // 2. Initialize ECS World
    world := ecs.create_world()
    defer ecs.destroy_world(world)

    fmt.println("Creating entities...")

    // 3. Create 2,000 entities with random components
    for i in 0..<2_000 {
        entity := ecs.create_entity(world)

        // Random position
        pos := Position{
            f32(rand.int31_max(SCREEN_WIDTH)), 
            f32(rand.int31_max(SCREEN_HEIGHT)),
        }

        // Random velocity
        vel := Velocity{
            rand.float32_range(-200, 200),
            rand.float32_range(-200, 200),
        }

        // Random color
        col := Color(rl.Color{
            u8(rand.int31_max(255)),
            u8(rand.int31_max(255)),
            u8(rand.int31_max(255)),
            255,
        })

        // Random size
        size := Radius(rand.float32_range(2.0, 6.0))

        // Add components to the entity
        ecs.add(world, entity, pos)
        ecs.add(world, entity, vel)
        ecs.add(world, entity, col)
        ecs.add(world, entity, size)
    }

    fmt.println("Simulation started.")

    // --- Main Loop ---
    for !rl.WindowShouldClose() {
        dt := rl.GetFrameTime()

        // Run Systems
        system_movement(world, dt)

        // Draw
        rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
        
        system_render(world)

        rl.DrawFPS(10, 10)
        rl.EndDrawing()
    }
}

// --- Systems ---

// Movement System: Updates Position based on Velocity and handles boundary collision
system_movement :: proc(world: ^ecs.World, dt: f32) {
    // Create (or retrieve cached) query for entities with Position AND Velocity
    q := ecs.query(world, ecs.with(Position), ecs.with(Velocity))

    // Iterate over matching archetypes
    for arch in q.archetypes {
        // Get strict component slices (SoA layout)
        // This is extremely CPU cache-friendly because data is contiguous
        positions  := ecs.table(world, arch, Position)
        velocities := ecs.table(world, arch, Velocity)

        // Iterate over entities within this archetype
        // #no_bounds_check is safe here because we iterate up to arch.len
        #no_bounds_check for i in 0..<arch.len {
            // Update position
            positions[i].x += velocities[i].x * dt
            positions[i].y += velocities[i].y * dt

            // Simple boundary collision
            if positions[i].x < 0 || positions[i].x > f32(SCREEN_WIDTH) {
                velocities[i].x *= -1
                // Clamp to prevent sticking to the wall
                positions[i].x = clamp(positions[i].x, 0, f32(SCREEN_WIDTH)) 
            }
            if positions[i].y < 0 || positions[i].y > f32(SCREEN_HEIGHT) {
                velocities[i].y *= -1
                positions[i].y = clamp(positions[i].y, 0, f32(SCREEN_HEIGHT))
            }
        }
    }
}

// Render System: Draws entities that have Position, Color, and Size
system_render :: proc(world: ^ecs.World) {
    // Note: We do not request Velocity here, as it is not needed for rendering
    q := ecs.query(world, ecs.with(Position), ecs.with(Color), ecs.with(Radius))

    for arch in q.archetypes {
        positions := ecs.table(world, arch, Position)
        colors    := ecs.table(world, arch, Color)
        radii     := ecs.table(world, arch, Radius)

        #no_bounds_check for i in 0..<arch.len {
            rl.DrawCircleV(
                rl.Vector2(positions[i]),
                f32(radii[i]), 
                rl.Color(colors[i]),
            )
        }
    }
}