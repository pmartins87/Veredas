extends Node

const MONSTER_SEEDS := 2
const BOSS_SEEDS := 3
const MAX_ROUNDS := 80
const VALID_MECHANICS := [
    "distance_pressure", "status_combo", "posture_break", "defense_cycle",
    "multi_attack", "telegraphed_range", "resource_drain", "intent_trick",
]
const ELITE_AFFIXES := [
    "thorned", "plated", "siphoning", "venomous", "scorching", "dreadful",
    "rootbound", "shocking", "wetborn", "swift", "relentless", "resonant",
]

var failures: Array[String] = []
var policy := PlayerPolicyEngine.new()
var enemy_engine := EnemyBalanceEngine.new()
var characters_by_world: Dictionary = {}
var aggregate: Dictionary = {}

func _ready() -> void:
    await get_tree().process_frame
    _index_characters()
    _structure_gate()
    _intent_gate()
    _combat_matrix_gate()
    _balance_gate()
    _finish()

func _index_characters() -> void:
    for character_variant in ContentRegistry.all("characters"):
        var character: Dictionary = character_variant as Dictionary
        var world_id := str(character.get("world_id", ""))
        var rows: Array = characters_by_world.get(world_id, []) as Array
        rows.append(str(character.get("id", "")))
        characters_by_world[world_id] = rows
    for world_id_variant in characters_by_world.keys():
        var world_id := str(world_id_variant)
        var rows: Array = characters_by_world[world_id] as Array
        rows.sort()
        expect(rows.size() == 3, "%s must expose three local Andarilhos for 10.3" % world_id)

func _structure_gate() -> void:
    var monsters := ContentRegistry.all("monsters")
    var bosses := ContentRegistry.all("bosses")
    expect(monsters.size() == 300, "10.3 requires 300 monsters")
    expect(bosses.size() == 60, "10.3 requires 60 bosses/subbosses")

    var normal_count := 0
    var elite_count := 0
    var affix_counts: Dictionary = {}
    var monster_world_counts: Dictionary = {}
    var elite_world_counts: Dictionary = {}
    var tier_threat := {}
    for monster_variant in monsters:
        var monster: Dictionary = monster_variant as Dictionary
        var monster_id := str(monster.get("id", ""))
        var world_id := str(monster.get("world_id", ""))
        var rank := str(monster.get("rank", ""))
        var mechanic := str(monster.get("mechanic", ""))
        var tier := int(monster.get("encounter_tier", 0))
        expect(rank in ["normal", "elite"], "%s has invalid rank %s" % [monster_id, rank])
        expect(mechanic in VALID_MECHANICS, "%s has invalid mechanic %s" % [monster_id, mechanic])
        expect(tier >= 1 and tier <= 5, "%s encounter tier outside 1..5" % monster_id)
        expect(int(monster.get("hp", 0)) >= 8 and int(monster.get("hp", 0)) <= 30, "%s HP outside monster envelope" % monster_id)
        expect(int(monster.get("posture", 0)) >= 5 and int(monster.get("posture", 0)) <= 20, "%s posture outside monster envelope" % monster_id)
        expect(float(monster.get("threat_rating", 0.0)) > 0.0, "%s missing threat rating" % monster_id)
        monster_world_counts[world_id] = int(monster_world_counts.get(world_id, 0)) + 1
        var threat_row: Dictionary = tier_threat.get(tier, {"sum":0.0,"count":0}) as Dictionary
        threat_row.sum = float(threat_row.sum) + float(monster.get("threat_rating", 0.0))
        threat_row.count = int(threat_row.count) + 1
        tier_threat[tier] = threat_row
        if rank == "elite":
            elite_count += 1
            elite_world_counts[world_id] = int(elite_world_counts.get(world_id, 0)) + 1
            var affix := str(monster.get("elite_affix", ""))
            expect(affix in ELITE_AFFIXES, "%s has invalid elite affix %s" % [monster_id, affix])
            expect(not (monster.get("elite_affix_data", {}) as Dictionary).is_empty(), "%s elite affix has no runtime data" % monster_id)
            affix_counts[affix] = int(affix_counts.get(affix, 0)) + 1
        else:
            normal_count += 1
            expect(str(monster.get("elite_affix", "")) == "", "%s normal monster carries elite affix" % monster_id)
    expect(normal_count == 240, "10.3 must contain exactly 240 normal monsters")
    expect(elite_count == 60, "10.3 must contain exactly 60 elite monsters")
    expect(affix_counts.size() == 12, "10.3 must exercise all 12 elite affixes")
    for affix in ELITE_AFFIXES:
        expect(int(affix_counts.get(affix, 0)) >= 4, "10.3 elite affix %s is underrepresented" % affix)
    for world_id_variant in monster_world_counts.keys():
        var world_id := str(world_id_variant)
        expect(int(monster_world_counts[world_id]) == 25, "%s does not have 25 monsters" % world_id)
        expect(int(elite_world_counts.get(world_id, 0)) == 5, "%s does not have five elites" % world_id)
    var previous_threat := -1.0
    for tier in range(1, 6):
        var row: Dictionary = tier_threat.get(tier, {}) as Dictionary
        var average := float(row.get("sum", 0.0)) / float(maxi(1, int(row.get("count", 0))))
        expect(average > previous_threat, "10.3 average threat must rise from encounter tier %d" % tier)
        previous_threat = average

    var boss_world_counts: Dictionary = {}
    var boss_rank_counts := {"subboss":0,"boss":0}
    var signatures: Dictionary = {}
    for boss_variant in bosses:
        var boss: Dictionary = boss_variant as Dictionary
        var boss_id := str(boss.get("id", ""))
        var world_id := str(boss.get("world_id", ""))
        var tier := int(boss.get("boss_tier", 0))
        var rank := str(boss.get("rank", ""))
        expect(tier >= 1 and tier <= 5, "%s boss tier outside 1..5" % boss_id)
        expect(rank in ["subboss", "boss"], "%s has invalid boss rank" % boss_id)
        expect(int(boss.get("hp", 0)) >= 30 and int(boss.get("hp", 0)) <= 38, "%s boss HP outside anti-sponge envelope" % boss_id)
        expect(int(boss.get("posture", 0)) >= 15 and int(boss.get("posture", 0)) <= 19, "%s boss posture outside anti-sponge envelope" % boss_id)
        expect(str(boss.get("mechanic", "")) in VALID_MECHANICS, "%s has invalid base boss mechanic" % boss_id)
        var phases: Array = boss.get("phases", []) as Array
        expect(phases.size() == 3, "%s must contain exactly three combat phases" % boss_id)
        var phase_mechanics: Dictionary = {}
        var thresholds: Array[float] = []
        for phase_variant in phases:
            var phase: Dictionary = phase_variant as Dictionary
            phase_mechanics[str(phase.get("mechanic", ""))] = true
            thresholds.append(float(phase.get("threshold", 0.0)))
            expect(str(phase.get("mechanic", "")) in VALID_MECHANICS, "%s phase uses invalid mechanic" % boss_id)
        expect(phase_mechanics.size() >= 2, "%s phases do not change behavior" % boss_id)
        expect(thresholds == [1.0, 0.60, 0.25], "%s phase thresholds mismatch" % boss_id)
        var signature := str(boss.get("combat_signature", ""))
        expect(signature != "", "%s missing combat signature" % boss_id)
        signatures[signature] = true
        boss_world_counts[world_id] = int(boss_world_counts.get(world_id, 0)) + 1
        boss_rank_counts[rank] = int(boss_rank_counts.get(rank, 0)) + 1
    expect(signatures.size() >= 48, "10.3 boss mechanics are insufficiently diverse")
    expect(int(boss_rank_counts.subboss) == 36 and int(boss_rank_counts.boss) == 24, "10.3 boss/subboss rank split must be 36/24")
    for world_id_variant in boss_world_counts.keys():
        expect(int(boss_world_counts[world_id_variant]) == 5, "%s does not have five bosses/subbosses" % str(world_id_variant))

func _intent_gate() -> void:
    for mechanic in VALID_MECHANICS:
        var ids: Dictionary = {}
        var synthetic := {"mechanic":mechanic,"domain_status":"fear","elite_affix_data":{},"damage_bonus":0}
        for roll in [0.10, 0.50, 0.76, 0.93]:
            var intent := enemy_engine.roll_intent(synthetic, {}, float(roll))
            ids[str(intent.get("id", ""))] = true
            expect(str(intent.get("telegraph", "")) != "", "10.3 %s produced intent without telegraph" % mechanic)
        expect(ids.size() >= 3, "10.3 %s intent profile is not behaviorally diverse" % mechanic)

    var changed_affixes: Dictionary = {}
    for affix in ELITE_AFFIXES:
        for monster_variant in ContentRegistry.all("monsters"):
            var monster: Dictionary = monster_variant as Dictionary
            if str(monster.get("elite_affix", "")) != affix:
                continue
            var bare := monster.duplicate(true)
            bare.elite_affix_data = {}
            bare.starting_guard = 0
            bare.damage_bonus = 0
            var changed: bool = int(monster.get("starting_guard",0)) != 0 or int(monster.get("posture",0)) != int(bare.get("posture",0))
            for roll in [0.10, 0.50, 0.76, 0.93]:
                var with_affix := enemy_engine.roll_intent(monster, {}, float(roll))
                var without_affix := enemy_engine.roll_intent(bare, {}, float(roll))
                if with_affix != without_affix:
                    changed = true
                    break
            if changed:
                changed_affixes[affix] = true
            break
    # plated changes starting guard/posture at combat start; the other 11 alter intents.
    expect(changed_affixes.size() == 12, "10.3 one or more elite affixes are behaviorally inert")

    for boss_variant in ContentRegistry.all("bosses"):
        var boss: Dictionary = boss_variant as Dictionary
        var phases: Array = boss.get("phases", []) as Array
        if phases.size() != 3:
            continue
        var phase_results: Dictionary = {}
        for phase_variant in phases:
            var phase: Dictionary = phase_variant as Dictionary
            var intent := enemy_engine.roll_intent(boss, phase, 0.50)
            var key := "%s:%d:%d:%s" % [str(intent.get("id","")), int(intent.get("damage",0)), int(intent.get("guard",0)), str(intent.get("status",""))]
            phase_results[key] = true
        expect(phase_results.size() >= 2, "%s phases do not alter the same controlled intent sample" % str(boss.get("id", "")))

func _combat_matrix_gate() -> void:
    aggregate = {
        "normal":_new_bucket(),
        "elite":_new_bucket(),
        "boss_tiers":{},
        "worlds":{},
    }
    var started_at := Time.get_ticks_msec()
    var total_combats := 0
    for monster_variant in ContentRegistry.all("monsters"):
        var monster: Dictionary = monster_variant as Dictionary
        var world_id := str(monster.get("world_id", ""))
        var rank := str(monster.get("rank", "normal"))
        for character_id_variant in characters_by_world.get(world_id, []) as Array:
            var character_id := str(character_id_variant)
            for sample in range(MONSTER_SEEDS):
                var seed_value := 830000 + int(monster.get("id", "").hash()) % 100000 + sample * 131 + int(character_id.hash()) % 997
                var result := _fight(str(monster.get("id", "")), character_id, absi(seed_value))
                _accumulate(aggregate[rank] as Dictionary, result)
                var world_bucket: Dictionary = aggregate.worlds.get(world_id, _new_bucket()) as Dictionary
                _accumulate(world_bucket, result)
                aggregate.worlds[world_id] = world_bucket
                total_combats += 1

    for boss_variant in ContentRegistry.all("bosses"):
        var boss: Dictionary = boss_variant as Dictionary
        var world_id := str(boss.get("world_id", ""))
        var tier := int(boss.get("boss_tier", 1))
        var tier_bucket: Dictionary = (aggregate.boss_tiers as Dictionary).get(tier, _new_bucket()) as Dictionary
        for character_id_variant in characters_by_world.get(world_id, []) as Array:
            var character_id := str(character_id_variant)
            for sample in range(BOSS_SEEDS):
                var seed_value := 930000 + int(boss.get("id", "").hash()) % 100000 + sample * 173 + int(character_id.hash()) % 991
                var result := _fight(str(boss.get("id", "")), character_id, absi(seed_value))
                _accumulate(tier_bucket, result)
                total_combats += 1
        (aggregate.boss_tiers as Dictionary)[tier] = tier_bucket

    print("10.3 combat matrix: combats=%d elapsed_ms=%d" % [total_combats, Time.get_ticks_msec() - started_at])
    _print_bucket("normal", aggregate.normal as Dictionary)
    _print_bucket("elite", aggregate.elite as Dictionary)
    for tier in range(1, 6):
        _print_bucket("boss_tier_%d" % tier, (aggregate.boss_tiers as Dictionary).get(tier, {}) as Dictionary)

func _fight(enemy_id: String, character_id: String, seed_value: int) -> Dictionary:
    GameState.new_run(character_id, maxi(1, seed_value))
    var flags: Dictionary = GameState.run.get("flags", {}) as Dictionary
    flags["simulation.no_persist"] = true
    GameState.run.flags = flags
    RNGService.start(maxi(1, seed_value))
    CombatEngine.start(enemy_id, character_id)
    var rounds := 0
    while bool(CombatEngine.combat.get("active", false)) and rounds < MAX_ROUNDS:
        rounds += 1
        var before_turn := int(CombatEngine.combat.get("turn", 0))
        var before_enemy_hp := int((CombatEngine.combat.get("enemy", {}) as Dictionary).get("hp", 0))
        var before_player_hp := int((CombatEngine.combat.get("player", {}) as Dictionary).get("hp", 0))
        var decision := policy.choose_combat_decision("balanced", CombatEngine.combat)
        if str(decision.get("kind", "action")) == "ability":
            CombatEngine.use_character_ability(str(decision.get("id", "")))
        else:
            CombatEngine.player_action(str(decision.get("id", "strike")))
        if bool(CombatEngine.combat.get("active", false)):
            var after_turn := int(CombatEngine.combat.get("turn", 0))
            var after_enemy_hp := int((CombatEngine.combat.get("enemy", {}) as Dictionary).get("hp", 0))
            var after_player_hp := int((CombatEngine.combat.get("player", {}) as Dictionary).get("hp", 0))
            if before_turn == after_turn and before_enemy_hp == after_enemy_hp and before_player_hp == after_player_hp:
                CombatEngine.player_action("advance" if int((CombatEngine.combat.get("player", {}) as Dictionary).get("distance",1)) > 0 else "strike")
    var timed_out := bool(CombatEngine.combat.get("active", false))
    if timed_out:
        CombatEngine.combat.active = false
        CombatEngine.combat.result = "timeout"
    return {
        "result":str(CombatEngine.combat.get("result", "timeout")),
        "rounds":rounds,
        "final_player_hp":int((CombatEngine.combat.get("player", {}) as Dictionary).get("hp",0)),
        "final_enemy_hp":int((CombatEngine.combat.get("enemy", {}) as Dictionary).get("hp",0)),
        "timeout":timed_out,
    }

func _new_bucket() -> Dictionary:
    return {"runs":0,"wins":0,"losses":0,"timeouts":0,"rounds":0,"survivor_hp":0}

func _accumulate(bucket: Dictionary, result: Dictionary) -> void:
    bucket.runs = int(bucket.runs) + 1
    bucket.rounds = int(bucket.rounds) + int(result.get("rounds", 0))
    bucket.survivor_hp = int(bucket.survivor_hp) + int(result.get("final_player_hp", 0))
    match str(result.get("result", "")):
        "victory": bucket.wins = int(bucket.wins) + 1
        "defeat": bucket.losses = int(bucket.losses) + 1
        _: bucket.timeouts = int(bucket.timeouts) + 1

func _rate(bucket: Dictionary, key: String) -> float:
    return float(bucket.get(key, 0)) / float(maxi(1, int(bucket.get("runs", 0))))

func _average_rounds(bucket: Dictionary) -> float:
    return float(bucket.get("rounds", 0)) / float(maxi(1, int(bucket.get("runs", 0))))

func _print_bucket(label: String, bucket: Dictionary) -> void:
    print("10.3 %s: runs=%d win=%.3f timeout=%.3f avg_rounds=%.2f" % [
        label, int(bucket.get("runs",0)), _rate(bucket,"wins"), _rate(bucket,"timeouts"), _average_rounds(bucket),
    ])

func _balance_gate() -> void:
    var normal: Dictionary = aggregate.get("normal", {}) as Dictionary
    var elite: Dictionary = aggregate.get("elite", {}) as Dictionary
    var normal_win := _rate(normal, "wins")
    var elite_win := _rate(elite, "wins")
    expect(_rate(normal, "timeouts") <= 0.01, "10.3 normal monsters produce combat timeouts")
    expect(_rate(elite, "timeouts") <= 0.01, "10.3 elites produce combat timeouts")
    expect(normal_win >= 0.45, "10.3 normal monsters are globally too punishing for baseline characters")
    expect(elite_win >= 0.20, "10.3 elites are globally too punishing for baseline characters")
    expect(elite_win <= normal_win + 0.05, "10.3 elites are easier than normal monsters")
    expect(_average_rounds(normal) <= 14.0, "10.3 normal monster TTK is too long")
    expect(_average_rounds(elite) <= 18.0, "10.3 elite monster TTK is too long")
    expect(_average_rounds(elite) + 0.5 >= _average_rounds(normal), "10.3 elites do not create a meaningful encounter premium")

    var previous_win := 1.0
    var first_rounds := 0.0
    var last_rounds := 0.0
    for tier in range(1, 6):
        var bucket: Dictionary = (aggregate.get("boss_tiers", {}) as Dictionary).get(tier, {}) as Dictionary
        var win_rate := _rate(bucket, "wins")
        var timeout_rate := _rate(bucket, "timeouts")
        var avg_rounds := _average_rounds(bucket)
        expect(timeout_rate <= 0.02, "10.3 boss tier %d produces combat timeouts" % tier)
        expect(win_rate >= 0.05, "10.3 boss tier %d is effectively unwinnable" % tier)
        expect(win_rate <= 0.90, "10.3 boss tier %d is trivial" % tier)
        expect(avg_rounds <= 22.0, "10.3 boss tier %d is an HP sponge" % tier)
        expect(win_rate <= previous_win + 0.20, "10.3 boss difficulty reverses too sharply at tier %d" % tier)
        previous_win = win_rate
        if tier == 1:
            first_rounds = avg_rounds
        if tier == 5:
            last_rounds = avg_rounds
    expect(last_rounds + 0.5 >= first_rounds, "10.3 apex bosses are faster to resolve than tier-1 subbosses")

    for world_id_variant in (aggregate.get("worlds", {}) as Dictionary).keys():
        var world_id := str(world_id_variant)
        var bucket: Dictionary = (aggregate.worlds as Dictionary)[world_id] as Dictionary
        expect(_rate(bucket, "timeouts") <= 0.02, "%s monster ecology produces excessive combat timeouts" % world_id)

func _finish() -> void:
    if failures.is_empty():
        print("ENEMY_BALANCE_CERTIFICATION PASS: 10.3")
        get_tree().quit(0)
    else:
        for failure in failures:
            push_error("ENEMY_BALANCE_CERTIFICATION: %s" % failure)
        print("ENEMY_BALANCE_CERTIFICATION FAIL: %d" % failures.size())
        get_tree().quit(1)

func expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
