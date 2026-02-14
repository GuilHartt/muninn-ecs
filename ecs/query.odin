package ecs

import "core:hash"
import "core:slice"
import "core:mem/virtual"

TermType  :: enum u64 { With, Without }

TermData :: union { Component, Pair }

QueryTermInput :: struct {
    data: TermData,
    mode: TermType,
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
    with_pair,
    with_pair_type_type,
    with_pair_id_id,
    with_pair_type_id,
    with_pair_id_type,
}

without :: proc { 
    without_type, 
    without_id,
    without_pair,
    without_pair_type_type,
    without_pair_id_id,
    without_pair_type_id,
    without_pair_id_type,
}

query :: proc(world: ^World, inputs: ..QueryTermInput) -> ^Query {
    terms: [16]QueryTerm
    count := min(len(inputs), 16)
    
    for i in 0..<count {
        inp := inputs[i]
        final_id: Entity

        switch v in inp.data {
        case Component: final_id = resolve_id(world, v)
        case Pair:      final_id = pair_id(world, v)
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

@(private="file", require_results)
with_type :: #force_inline proc "contextless" ($T: typeid) -> QueryTermInput {
    val: typeid = T
    return { Component(val), .With }
}

@(private="file", require_results)
with_id :: #force_inline proc "contextless" (id: Entity) -> QueryTermInput {
    return { Component(id), .With }
}

@(private="file", require_results)
with_pair :: #force_inline proc "contextless" (pair: Pair) -> QueryTermInput {
    return { pair, .With }
}

@(private="file", require_results)
with_pair_type_type :: #force_inline proc "contextless" ($Rel, $Tgt: typeid) -> QueryTermInput {
    return { pair_type_type(Rel, Tgt), .With }
}

@(private="file", require_results)
with_pair_id_id :: #force_inline proc "contextless" (rel, tgt: Entity) -> QueryTermInput {
    return { pair_id_id(rel, tgt), .With }
}

@(private="file", require_results)
with_pair_type_id :: #force_inline proc "contextless" ($Rel: typeid, tgt: Entity) -> QueryTermInput {
    return { pair_type_id(Rel, tgt), .With }
}

@(private="file", require_results)
with_pair_id_type :: #force_inline proc "contextless" (rel: Entity, $Tgt: typeid) -> QueryTermInput {
    return { pair_id_type(rel, Tgt), .With }
}

@(private="file", require_results)
without_type :: #force_inline proc "contextless" ($T: typeid) -> QueryTermInput {
    val: typeid = T
    return { Component(val), .Without }
}

@(private="file", require_results)
without_id :: #force_inline proc "contextless" (id: Entity) -> QueryTermInput {
    return { Component(id), .Without }
}

@(private="file", require_results)
without_pair :: #force_inline proc "contextless" (pair: Pair) -> QueryTermInput {
    return { pair, .Without }
}

@(private="file", require_results)
without_pair_type_type :: #force_inline proc "contextless" ($Rel, $Tgt: typeid) -> QueryTermInput {
    return { pair_type_type(Rel, Tgt), .Without }
}

@(private="file", require_results)
without_pair_id_id :: #force_inline proc "contextless" (rel, tgt: Entity) -> QueryTermInput {
    return { pair_id_id(rel, tgt), .Without }
}

@(private="file", require_results)
without_pair_type_id :: #force_inline proc "contextless" ($Rel: typeid, tgt: Entity) -> QueryTermInput {
    return { pair_type_id(Rel, tgt), .Without }
}

@(private="file", require_results)
without_pair_id_type :: #force_inline proc "contextless" (rel: Entity, $Tgt: typeid) -> QueryTermInput {
    return { pair_id_type(rel, Tgt), .Without }
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

@(private="file")
hash_query_terms :: proc(terms: []QueryTerm) -> u64 {
    slice.sort_by(terms, proc(i, j: QueryTerm) -> bool {
        return i.id < j.id
    })
    return hash.fnv64a(slice.to_bytes(terms))
}