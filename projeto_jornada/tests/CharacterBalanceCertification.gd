extends Node

const SEEDS_PER_SKILL := 12
const MAX_STEPS := 24
const VALID_TIERS := ["approachable", "intermediate", "expert"]
const VALID_MECHANICS := ["damage", "posture", "guard", "heal", "move", "status", "counter", "resource", "echo", "mark", "debt", "range"]

var failures: Array[String] = []
var simulator := JourneySimulationEngine.new()
var metrics: Dictionary = {}
var characters: Array = []

func _ready() -> void:
    await get_tree().process_frame
    characters = ContentRegistry.all("characters").duplicate()
    characters.sort_custom(func(a, b): return str((a as Dictionary).get("id", "")) < str((b as Dictionary).get("id", "")))
    _structure_gate()
    _mechanic_gate()
    _simulation_gate()
    _learning_curve_gate()
    _finish()

func _structure_gate() -> void:
    expect(characters.size() == 36, "10.2 requires exactly 36 playable characters")
    var worlds: Dictionary = {}
    var tier_counts := {"approachable":0, "intermediate":0, "expert":0}
    var signatures: Dictionary = {}
    for character_variant in characters:
        var character: Dictionary = character_variant as Dictionary
        var character_id := str(character.get("id", ""))
        var world_id := str(character.get("world_id", ""))
        var curve: Dictionary = character.get("learning_curve", {}) as Dictionary
        var tier := str(curve.get("tier", ""))
        var recommended := str(curve.get("recommended_policy", ""))
        expect(tier in VALID_TIERS, "%s has invalid learning tier %s" % [character_id, tier])
        expect(recommended in ["balanced", "aggressive", "cautious", "explorer"], "%s has invalid recommended policy" % character_id)
        expect(int(curve.get("complexity", 0)) >= 1 and int(curve.get("complexity", 0)) <= 5, "%s complexity is outside 1..5" % character_id)
        expect(float(curve.get("forgiveness", -1.0)) >= 0.0 and float(curve.get("forgiveness", 2.0)) <= 1.0, "%s forgiveness is invalid" % character_id)
        expect(float(curve.get("ceiling", -1.0)) >= 0.0 and float(curve.get("ceiling", 2.0)) <= 1.0, "%s ceiling is invalid" % character_id)
        expect(int(character.get("base_health", 0)) >= 14 and int(character.get("base_health", 0)) <= 20, "%s base health is outside balance envelope" % character_id)
        expect(int(character.get("base_vigor", 0)) >= 7 and int(character.get("base_vigor", 0)) <= 10, "%s base vigor is outside balance envelope" % character_id)
        expect(int(character.get("base_posture", 0)) >= 8 and int(character.get("base_posture", 0)) <= 13, "%s base posture is outside balance envelope" % character_id)
        expect(int(character.get("base_guard", -1)) >= 0 and int(character.get("base_guard", 0)) <= 3, "%s base guard is outside balance envelope" % character_id)
        expect(int(character.get("resource_start", -1)) >= 0 and int(character.get("resource_start", 99)) <= int(character.get("resource_max", 0)), "%s resource start is invalid" % character_id)
        expect((character.get("abilities", []) as Array).size() == 2, "%s must have exactly two signature abilities" % character_id)
        var signature := str(character.get("balance_signature", ""))
        expect(signature != "", "%s is missing balance signature" % character_id)
        signatures[signature] = true
        if tier_counts.has(tier):
            tier_counts[tier] = int(tier_counts[tier]) + 1
        var world_rows: Array = worlds.get(world_id, []) as Array
        world_rows.append(character)
        worlds[world_id] = world_rows

    expect(worlds.size() == 12, "10.2 characters do not span all 12 Domains")
    expect(signatures.size() == 36, "10.2 balance signatures are not unique")
    for tier in VALID_TIERS:
        expect(int(tier_counts.get(tier, 0)) == 12, "10.2 learning tier %s must occur once per Domain" % tier)
    for world_id_variant in worlds.keys():
        var world_id := str(world_id_variant)
        var rows: Array = worlds[world_id] as Array
        expect(rows.size() == 3, "%s does not contain three playable characters" % world_id)
        var tiers: Dictionary = {}
        for row_variant in rows:
            var row: Dictionary = row_variant as Dictionary
            tiers[str((row.get("learning_curve", {}) as Dictionary).get("tier", ""))] = true
        expect(tiers.size() == 3, "%s must contain approachable, intermediate and expert curves" % world_id)

func _mechanic_gate() -> void:
    var mechanic_coverage: Dictionary = {}
    for ability_variant in ContentRegistry.all("abilities"):
        var ability: Dictionary = ability_variant as Dictionary
        var ability_id := str(ability.get("id", ""))
        var mechanic := str(ability.get("mechanic", ""))
        mechanic_coverage[mechanic] = true
        expect(mechanic in VALID_MECHANICS, "%s has unknown mechanic %s" % [ability_id, mechanic])
        expect(int(ability.get("cost", -1)) >= 0 and int(ability.get("cost", 99)) <= 3, "%s cost is outside 0..3" % ability_id)
        expect(int(ability.get("power", 0)) >= 1 and int(ability.get("power", 0)) <= 9, "%s power is outside 1..9" % ability_id)

        var actor := {"hp":10,"max_hp":20,"vigor":8,"max_vigor":9,"posture":10,"max_posture":10,"guard":0,"distance":0,"states":[]}
        var target := {"hp":30,"max_hp":30,"posture":20,"max_posture":20,"guard":0,"distance":1,"states":[]}
        var resource := str(ability.get("resource", ""))
        var pool := {resource:maxi(1, int(ability.get("cost", 0)) + 1)}
        var result := CharacterKitEngine.execute(ability, actor, target, pool)
        expect(bool(result.get("ok", false)), "%s could not execute with funded synthetic state" % ability_id)
        if bool(result.get("ok", false)):
            var changed: bool = result.get("actor", {}) != actor or result.get("target", {}) != target or result.get("resources", {}) != pool
            expect(changed, "%s mechanic %s is behaviorally inert" % [ability_id, mechanic])
    expect(mechanic_coverage.size() == VALID_MECHANICS.size(), "10.2 does not exercise all 12 signature mechanics")
    for mechanic in VALID_MECHANICS:
        expect(mechanic_coverage.has(mechanic), "10.2 missing signature mechanic %s" % mechanic)

func _simulation_gate() -> void:
    var started_at := Time.get_ticks_msec()
    var global_runs := 0
    for character_index in range(characters.size()):
        var character: Dictionary = characters[character_index] as Dictionary
        var character_id := str(character.get("id", ""))
        var curve: Dictionary = character.get("learning_curve", {}) as Dictionary
        var recommended := str(curve.get("recommended_policy", "balanced"))
        var skill_policies := {
            "novice":"random",
            "competent":"balanced",
            "learned":recommended,
        }
        var character_metrics: Dictionary = {}
        for skill in ["novice", "competent", "learned"]:
            var policy_id := str(skill_policies[skill])
            var aggregate := {
                "runs":0,"valid":0,"victories":0,"boss_reached":0,"boss_wins":0,
                "combat_timeouts":0,"events":0,"combats":0,"combat_wins":0,"score_total":0.0,
            }
            for sample_index in range(SEEDS_PER_SKILL):
                # Same environment seed for each skill level of the same character.
                var seed_value := 720000 + character_index * 1009 + sample_index * 97
                var result := simulator.simulate({
                    "character_id":character_id,
                    "policy_id":policy_id,
                    "build_id":"baseline",
                    "economy_enabled":false,
                    "seed":seed_value,
                    "max_steps":MAX_STEPS,
                })
                global_runs += 1
                aggregate.runs = int(aggregate.runs) + 1
                if not bool(result.get("ok", false)):
                    continue
                aggregate.valid = int(aggregate.valid) + 1
                aggregate.events = int(aggregate.events) + int(result.get("events", 0))
                aggregate.combats = int(aggregate.combats) + int(result.get("combats", 0))
                aggregate.combat_wins = int(aggregate.combat_wins) + int(result.get("combat_wins", 0))
                if str(result.get("result", "")) == "victory":
                    aggregate.victories = int(aggregate.victories) + 1
                if bool(result.get("boss_reached", false)):
                    aggregate.boss_reached = int(aggregate.boss_reached) + 1
                if bool(result.get("boss_win", false)):
                    aggregate.boss_wins = int(aggregate.boss_wins) + 1
                if str(result.get("result", "")) == "combat_timeout":
                    aggregate.combat_timeouts = int(aggregate.combat_timeouts) + 1
                aggregate.score_total = float(aggregate.score_total) + _journey_score(result, character)
            aggregate["score"] = float(aggregate.score_total) / float(maxi(1, int(aggregate.valid)))
            character_metrics[skill] = aggregate
            expect(int(aggregate.valid) == SEEDS_PER_SKILL, "%s %s simulations were not all valid" % [character_id, skill])
            expect(int(aggregate.events) >= SEEDS_PER_SKILL, "%s %s did not exercise narrative events" % [character_id, skill])
            expect(int(aggregate.combats) > 0, "%s %s never entered combat" % [character_id, skill])
            expect(int(aggregate.combat_timeouts) <= 1, "%s %s is dominated by combat timeouts" % [character_id, skill])
        metrics[character_id] = character_metrics
        var novice: Dictionary = character_metrics["novice"] as Dictionary
        var competent: Dictionary = character_metrics["competent"] as Dictionary
        var learned: Dictionary = character_metrics["learned"] as Dictionary
        expect(int(learned.boss_reached) > 0, "%s learned policy never reached its boss" % character_id)
        var novice_score := float(novice.get("score", 0.0))
        var learned_score := float(learned.get("score", 0.0))
        expect(learned_score + 0.30 >= novice_score, "%s learned policy is materially worse than novice play" % character_id)
        print("10.2 character %s | %s | %s | tier=%s policy=%s | novice=%.3f competent=%.3f learned=%.3f | learned[v=%d boss=%d bw=%d combat=%d/%d]" % [
            str(character.get("name", character_id)), character_id, str(character.get("world_id", "")),
            str(curve.get("tier", "")), recommended,
            novice_score, float(competent.get("score", 0.0)), learned_score,
            int(learned.get("victories", 0)), int(learned.get("boss_reached", 0)), int(learned.get("boss_wins", 0)),
            int(learned.get("combat_wins", 0)), int(learned.get("combats", 0)),
        ])

    var elapsed_ms := Time.get_ticks_msec() - started_at
    print("10.2 simulation matrix: characters=%d runs=%d seeds_per_skill=%d elapsed_ms=%d" % [characters.size(), global_runs, SEEDS_PER_SKILL, elapsed_ms])

func _learning_curve_gate() -> void:
    var tier_aggregate := {
        "approachable":{"count":0,"novice":0.0,"competent":0.0,"learned":0.0},
        "intermediate":{"count":0,"novice":0.0,"competent":0.0,"learned":0.0},
        "expert":{"count":0,"novice":0.0,"competent":0.0,"learned":0.0},
    }
    var domain_scores: Dictionary = {}
    var learned_not_worse := 0
    var global_novice := 0.0
    var global_learned := 0.0

    for character_variant in characters:
        var character: Dictionary = character_variant as Dictionary
        var character_id := str(character.get("id", ""))
        var world_id := str(character.get("world_id", ""))
        var tier := str((character.get("learning_curve", {}) as Dictionary).get("tier", ""))
        var row: Dictionary = metrics.get(character_id, {}) as Dictionary
        var novice := float((row.get("novice", {}) as Dictionary).get("score", 0.0))
        var competent := float((row.get("competent", {}) as Dictionary).get("score", 0.0))
        var learned := float((row.get("learned", {}) as Dictionary).get("score", 0.0))
        global_novice += novice
        global_learned += learned
        if learned + 0.05 >= novice:
            learned_not_worse += 1
        var tier_row: Dictionary = tier_aggregate[tier] as Dictionary
        tier_row.count = int(tier_row.count) + 1
        tier_row.novice = float(tier_row.novice) + novice
        tier_row.competent = float(tier_row.competent) + competent
        tier_row.learned = float(tier_row.learned) + learned
        tier_aggregate[tier] = tier_row
        var scores: Array = domain_scores.get(world_id, []) as Array
        scores.append(competent)
        domain_scores[world_id] = scores

    for tier in VALID_TIERS:
        var row: Dictionary = tier_aggregate[tier] as Dictionary
        var count := maxi(1, int(row.count))
        row.novice = float(row.novice) / float(count)
        row.competent = float(row.competent) / float(count)
        row.learned = float(row.learned) / float(count)
        row["gain"] = float(row.learned) - float(row.novice)
        tier_aggregate[tier] = row
        print("10.2 tier %s: novice=%.3f competent=%.3f learned=%.3f gain=%+.3f" % [tier, float(row.novice), float(row.competent), float(row.learned), float(row.gain)])

    var approachable: Dictionary = tier_aggregate["approachable"] as Dictionary
    var intermediate: Dictionary = tier_aggregate["intermediate"] as Dictionary
    var expert: Dictionary = tier_aggregate["expert"] as Dictionary
    expect(float(approachable.novice) + 0.15 >= float(expert.novice), "10.2 approachable floor is materially below expert floor")
    var learned_values := [float(approachable.learned), float(intermediate.learned), float(expert.learned)]
    var learned_min := minf(learned_values[0], minf(learned_values[1], learned_values[2]))
    var learned_max := maxf(learned_values[0], maxf(learned_values[1], learned_values[2]))
    expect(learned_max - learned_min <= 0.40, "10.2 learning tiers have excessive learned-power separation")
    expect(float(expert.gain) + 0.20 >= float(approachable.gain), "10.2 expert curve does not provide a meaningful mastery ceiling")
    expect(learned_not_worse >= 24, "10.2 recommended play fails to match novice play for too many characters")
    expect(global_learned / 36.0 + 0.05 >= global_novice / 36.0, "10.2 learned play is globally worse than novice play")

    for world_id_variant in domain_scores.keys():
        var world_id := str(world_id_variant)
        var scores: Array = domain_scores[world_id] as Array
        if scores.size() != 3:
            continue
        var low := minf(float(scores[0]), minf(float(scores[1]), float(scores[2])))
        var high := maxf(float(scores[0]), maxf(float(scores[1]), float(scores[2])))
        expect(high - low <= 0.65, "%s has excessive controlled balanced-score spread among its three Andarilhos" % world_id)

func _journey_score(result: Dictionary, character: Dictionary) -> float:
    var score := 0.0
    if str(result.get("result", "")) == "victory":
        score += 1.0
    if bool(result.get("boss_reached", false)):
        score += 0.35
    if bool(result.get("boss_win", false)):
        score += 0.25
    var combats := maxi(1, int(result.get("combats", 0)))
    score += 0.15 * float(result.get("combat_wins", 0)) / float(combats)
    var max_health := maxi(1, int(character.get("base_health", 16)))
    score += 0.10 * clampf(float(result.get("final_health", 0)) / float(max_health), 0.0, 1.0)
    if str(result.get("result", "")) == "combat_timeout":
        score -= 0.25
    return score

func _finish() -> void:
    if failures.is_empty():
        print("CHARACTER_BALANCE_CERTIFICATION PASS: 10.2")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("CHARACTER_BALANCE_CERTIFICATION: %s" % failure)
        print("CHARACTER_BALANCE_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
