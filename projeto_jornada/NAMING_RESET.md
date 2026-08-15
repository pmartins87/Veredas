# Naming Reset — Product Blocker

Status: **ACTIVE**  
Date: **2026-08-14**

## Decision

The current public-facing naming system is rejected.

This includes, without limitation:

- the former product title **Veredas da Trama**;
- the Domain name **Mata do Fio Verde**;
- hub/meta names such as **Nó de Vigília**, **Mesa dos Fios** and **Arquivo de Ecos**;
- place names such as **Catedral de Samaúma** when they are merely atmospheric compounds rather than names grounded in setting history;
- characters, factions, monsters, bosses, items and systems whose names were created primarily to sound poetic, mystical or dark-fantasy;
- any generated naming pattern that combines evocative nouns without a clear in-world reason.

Existing IDs may remain temporarily in code to avoid needless technical churn while the game is under reconstruction. **An internal ID is not an approved product name.** The repository name and Android application ID are likewise legacy technical identifiers until the final identity is selected.

## Root cause

The project used naming as decoration instead of worldbuilding. Too many names were created by combining symbolic vocabulary — paths, threads, echoes, roots, vigil, weave, green, memory, etc. — before the world had enough concrete history, geography, societies and ordinary language to justify those terms.

The result is pseudo-poetic fantasy language: individually evocative words with weak shared meaning, low memorability and little sense that real people in a real place would use those names.

## New rule: world first, names second

No bulk renaming begins until a compact world bible answers, in concrete terms:

1. Where does the story physically take place?
2. What happened before the player arrives?
3. Who lives there and how do those people speak?
4. Which cultures, institutions, religions, trades and conflicts shape everyday vocabulary?
5. Which names are inherited from people, geography, historical events, occupations or local language?
6. Which supernatural concepts genuinely need special terminology, and which should use ordinary words?

## Naming standards

A production name must satisfy all relevant criteria below.

- **Grounded:** there is a specific in-world reason for the name.
- **Memorable:** it can be recalled after one encounter.
- **Speakable:** a Brazilian Portuguese speaker can comfortably say it aloud; English localization must also remain workable when needed.
- **Distinct:** nearby places and characters do not all share the same poetic construction.
- **Economical:** ordinary things use ordinary names. Not every menu, currency, room, tree or mechanic receives lore terminology.
- **Tonally coherent:** fantasy identity comes from the world and art, not from stacking mystical nouns.
- **Non-derivative:** names must not imitate Path of Adventure, Sorcery! or another reference title.
- **Context-tested:** a name must work in an actual sentence spoken by a character, on a map, in a menu and in marketing where applicable.

## Automatic rejection patterns

Treat the following as warning signs requiring explicit justification:

- `Noun of Noun` / `Substantivo de Substantivo` used only to sound grand;
- abstract mystical vocabulary attached to routine UI functions;
- repeated use of thread/weave/path/echo/root/vigil/memory vocabulary across unrelated systems;
- color + symbolic noun as a substitute for geography or culture;
- invented proper nouns that have no etymology, speaker community or historical source;
- names whose meaning cannot be explained without vague phrases such as “it represents the connection between...”.

## Product title process

The game currently has **no approved title**.

The next title will only be selected after the core premise and world identity are rewritten. Candidate generation comes after that work, followed by memorability/context review and only then trademark/domain/store reconnaissance.

Until then, internal builds must be treated as **Sem título — build interna**.

## Relationship to EXP-001

This naming reset is part of the broader product-experience stop-ship triggered by the first physical Android playtest. Resolving technical runtime issues or completing a narrative smoke test does not resolve this naming blocker.

The blocker is resolved only when:

- the world bible is coherent enough to generate grounded names;
- the first representative vertical slice uses the replacement naming system in context;
- the product owner approves the title and the key names after seeing them in actual gameplay;
- legacy pseudo-poetic user-facing names are removed from the representative build;
- title clearance work in roadmap step 12.1 restarts for the selected replacement title.
