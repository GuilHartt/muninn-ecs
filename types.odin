package ecs

ID_PAIR_FLAG :: 0x8000_0000_0000_0000

Entity   :: distinct u64
Wildcard :: Entity(0)

TypeInfo :: struct {
    id:    Entity,
    size:  int,
    align: int,
}

EntityRecord :: struct {
    archetype: ^Archetype,
    row:       int,
    gen:       u16,
}