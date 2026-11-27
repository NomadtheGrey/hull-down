# Code Manifesto — Hull Down (the GDScript edition)

Adam's call, 2026-11-18: every project gets its own self-policing
code law, adapted — not photocopied — from the last one. BioForge's
tenets became Mass Rattle's; these are Hull Down's, written for
GDScript and Godot, and every tenet below was earned by a real
incident in this repo (named, so the next reader trusts the rule).

## Universal Laws — every language, every platform

Pinned by Adam, 2026-11-18. These five laws stand above the
tenets below and above every manifesto in the family: they hold
in GDScript, TypeScript, or anything else, on any platform. The
tenets under them are each repo's own scar tissue; these are the
constitution the scar tissue hangs on.

1. **No else.** Guard clauses, early returns, flat flow. Every
   condition states the case it handles, never "the other one."
2. **KISS.** The simplest thing that works. Cleverness is a cost,
   not a flex; a reader should never need to be smart to follow
   the code, only attentive.
3. **Separation of concerns.** Each module owns one concern.
   Coordinators wire — refs, listeners, sync calls, composition —
   and do not compute; logic lives in the module that owns it.
4. **DRY.** One canonical home for every rule, number, and shape.
   A second copy is not a convenience; it is a bug waiting for
   a date.
5. **Comments carry the why.** Intent, provenance, status —
   never a restatement of what the code plainly says.

In this repo: law 1 is Tenet 13 below (GDScript dress), law 5 is Tenet 11.

## The tenets

1. **Annotate at the Variant border.** A value that comes out of a
   Dictionary or an untyped Array is a Variant, and `:=` on it is a
   parse error waiting for its moment. The line that pulls a value
   out of state names its type: `var t: float = ob["size"].y`.
   (Build 1 shipped two inference parse errors to the headless check;
   build 3's test wrote a third.)

2. **`:=` is for the provable.** Literals, constructors, and calls
   whose return type is declared. Everything else gets its type
   written out. Inference is a convenience, never a detective.

3. **A state dictionary's shape is written where it is born.** Keys
   and value types go in the comment at the declaration (obstacles,
   enemies, shells). Keys are API: renaming one is a repo-wide grep
   in the same landing, never a local edit.

4. **Never open an empty surface.** An ImmediateMesh surface begun
   and ended with zero vertices is an engine error, every frame.
   Dynamic surfaces are guarded by a has-content check; a rebuild
   with nothing to draw sets a surfaceless mesh. (Build 3: the wave
   intro spammed errors until the guard landed.)

5. **The boot is the second compiler.** The parser clearing a file
   proves almost nothing. Every landing gets a headless boot
   (~300 frames, zero errors) and a throwaway SceneTree test that
   drives the real paths — input through the input pipeline, not
   function calls alone. (Build 1's "Space doesn't fire" was
   invisible to everything except a driven test.) Test scripts are
   deleted before the push; their results are recorded in DESIGN.md.

6. **Read the error's filename before fixing anything.** A parse
   error in the test script is not a bug in the game. (Build 3.)

7. **Scene files are code.** Hand edits to a .tscn respect its
   header: check the actual ext_resource ids before referencing
   them, and keep load_steps honest. (Build 5: ids assumed from
   memory — 2_radar for a file whose real id was 3_rad — and the
   scene refused to parse.) After scene surgery: boot first, ask
   questions later.

8. **Nodes are typed at the @onready line.** No untyped node
   variables. A renamed scene node should fail loudly at its
   declaration, not mysteriously at its third use.

9. **Deterministic where promised.** World generation draws from
   its own seeded RNG (one seed per chunk, derived from the chunk's
   coordinates — the same chunk must regenerate identically
   forever). The shared RNG is for combat noise only, and never
   leaks into the world.

10. **State is renderer-agnostic; renderers only read.** main.gd
    owns every fact about the world; vector_renderer.gd and its
    future 3D sibling draw those facts and keep none of their own.
    This is what lets a new visual mode — or a multiplayer host —
    arrive as a skin, never a fork.

11. **Comments carry the why.** (Adam's law, carried over from Mass
    Rattle's tenet 11 unchanged.) A comment earns its place three
    ways: provenance (the ruling, the date, the reason), status
    (DRAFT awaiting its pin, or an invariant a future editor would
    "fix" into a bug), or the obtuse (dense code, explained).
    Comments restating the code are deleted on sight; commented-out
    code is never committed.

12. **Numbers are DRAFT until pinned.** Every tuning constant is
    draft until Adam's pin pass. A tuned constant without its
    status is unfinished; a silent tuning change inside an
    unrelated landing is a violation.

13. **No else.** (Adam's nitpick, pinned 2026-11-18.) An `else`
    block is never written — and neither is `elif`. Invert the
    condition and return early; set the plain case first and let
    the special case override it; give each branch its own guard.
    The happy path stays at the left margin, and every condition
    states the case it handles instead of "the other one." The
    whole codebase was refactored to comply the day this tenet
    landed, regression-tested 13/13 — the law is not aspirational.
    (Open question, Adam's to rule: the value-ternary `a if cond
    else b` is an expression, not a branch, and currently survives
    in a handful of one-liners. If he rules it out too, they go.)

## The library shelf (lib/)

Scaffolding lives in `lib/`, one class per file, each with a
class_name and a driven test in the landing that introduces it.
What is on the shelf:

- **Option** — a nullable with manners: `some` / `none` /
  `from_nullable` at a Variant border, `value_or` (the
  null-coalescing GDScript doesn't have), `map`, and an `unwrap`
  that asserts loudly. Absence is handled in the open or not at all.
- **Result** — value-or-error for fallible work (files, parsing,
  the network when it comes): `ok` / `err`, `value_or`, `error`,
  `unwrap`. No nulls, no sentinels, no silent failures.

What no library can fix, recorded so nobody tries: there is no
compile-time exhaustiveness (a `match` can forget a case and the
compiler won't say), no user-defined generic classes (the typed
`Array[T]` and `Dictionary[K, V]` are the generics we have), and no
nullable annotation for value types (which don't need one — they
can't be null). The shelf answers with discipline, per tenets 1-3.

Practical note: a new class_name registers with the engine's class
cache on an import pass — run one (`--headless --import`) before
testing code that references a brand-new library class, or the
compiler will swear the class doesn't exist. (Learned the day the
shelf was built.)

## Scope and verification

These thirteen tenets govern all GDScript and scene work in this
repo. A landing is done when its headless boot is clean, its driven
tests pass, and no tenet was bent to get there. When a new incident
teaches a new lesson — or Adam names a new nitpick — the manifesto
gains a tenet, with its origin recorded the way these were.
