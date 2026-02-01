package ecs

import "core:hash"
import "core:slice"
import "core:mem/virtual"

TermValue :: union { Entity, typeid }
TermType  :: enum u64 { With, Without }

QueryTermInput :: struct {
    relation: TermValue,
    target:   TermValue,
    mode:     TermType,
    is_pair:  bool,
}

QueryTerm :: struct {
    id:   Entity,
    mode: TermType,
}

Query :: struct {
    hash:       u64,
    terms:      [16]QueryTerm,
    archetypes: [dynamic]^Archetype,
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
        final_id: Entity

        r_id: Entity
        switch v in inp.relation {
        case Entity: r_id = v
        case typeid: r_id = get_component_id(world, v)
        }

        if inp.is_pair {
            t_id: Entity
            switch v in inp.target {
            case Entity: t_id = v
            case typeid: t_id = get_component_id(world, v)
            }
            final_id = id_make_pair(r_id, t_id)
        } else {
            final_id = r_id
        }

        terms[i] = QueryTerm{ id = final_id, mode = inp.mode }
    }

    terms_for_hash := terms[:count]
    hash := hash_query_terms(terms_for_hash)

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

@private
with_type :: #force_inline proc($T: typeid) -> QueryTermInput {
    val: typeid = T
    return QueryTermInput{ relation = val, mode = .With, is_pair = false }
}

@private
with_id :: #force_inline proc(id: Entity) -> QueryTermInput {
    return QueryTermInput{ relation = id, mode = .With, is_pair = false }
}

@private
with_pair_id_id :: #force_inline proc(rel, tgt: Entity) -> QueryTermInput {
    return QueryTermInput{ relation = rel, target = tgt, mode = .With, is_pair = true }
}

@private
with_pair_type_id :: #force_inline proc($Rel: typeid, tgt: Entity) -> QueryTermInput {
    r: typeid = Rel
    return QueryTermInput{ relation = r, target = tgt, mode = .With, is_pair = true }
}

@private
with_pair_id_type :: #force_inline proc(rel: Entity, $Tgt: typeid) -> QueryTermInput {
    t: typeid = Tgt
    return QueryTermInput{ relation = rel, target = t, mode = .With, is_pair = true }
}

@private
with_pair_type_type :: #force_inline proc($Rel: typeid, $Tgt: typeid) -> QueryTermInput {
    r: typeid = Rel
    t: typeid = Tgt
    return QueryTermInput{ relation = r, target = t, mode = .With, is_pair = true }
}

@private
without_type :: #force_inline proc($T: typeid) -> QueryTermInput {
    val: typeid = T
    return QueryTermInput{ relation = val, mode = .Without, is_pair = false }
}

@private
without_id :: #force_inline proc(id: Entity) -> QueryTermInput {
    return QueryTermInput{ relation = id, mode = .Without, is_pair = false }
}

@private
without_pair_id_id :: #force_inline proc(rel, tgt: Entity) -> QueryTermInput {
    return QueryTermInput{ relation = rel, target = tgt, mode = .Without, is_pair = true }
}

@private
without_pair_type_id :: #force_inline proc($Rel: typeid, tgt: Entity) -> QueryTermInput {
    r: typeid = Rel
    return QueryTermInput{ relation = r, target = tgt, mode = .Without, is_pair = true }
}

@private
without_pair_id_type :: #force_inline proc(rel: Entity, $Tgt: typeid) -> QueryTermInput {
    t: typeid = Tgt
    return QueryTermInput{ relation = rel, target = t, mode = .Without, is_pair = true }
}

@private
without_pair_type_type :: #force_inline proc($Rel: typeid, $Tgt: typeid) -> QueryTermInput {
    r: typeid = Rel
    t: typeid = Tgt
    return QueryTermInput{ relation = r, target = t, mode = .Without, is_pair = true }
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