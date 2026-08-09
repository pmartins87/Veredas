extends Node

const REGRET_SEEDS := 24
const STALEMATE_SEEDS := 12
const BASE_SEED := 108900
const MAX_STEPS := 80
const CONTROLLED := ["balanced", "aggressive", "cautious", "explorer"]
const BUILDS := ["baseline", "offense", "defense", "utility"]
const REGRET_NAMES := [
    "Tecelão Fraturado",
    "Ferreiro de Guerra",
    "Lanceiro Solar",
    "Engenheira de Pontes",
    "Repetente",
    "Penitente Cinzento",
    "Necrógrafa",
    "Portador da Brasa",
    "Caminhante de Sombra",
    "Barqueiro do Reflexo",
    "Desertor da Forja",
    "Corsária de Coral",
]

var simulator := DifficultySimulationEngine.new()

func _ready() -> void:
    await get_tree().process_frame
    _print_forja_loadouts()
    _verify_regrets()
    _locate_cautious_stalemates()
    _stress_forja_ruptura()
    print("MASS_OUTLIER_DIAGNOSTIC PASS: 10.8 targeted")
    DifficultyEngine.clear_simulation_override()
    get_tree().quit(0)

func _print_forja_loadouts() -> void:
    var engine := JourneySimulationEngine.new()
    for build_id in ["offense", "defense", "utility"]:
        engine._prepare_isolated_profile("world.forja_rubra", "character.forja_rubra.01")
        if not RunFlowEngine.start_journey("character.forja_rubra.01", 108811, "andarilho"):
            print("10.8 Forja loadout %s START_FAILED" % build_id)
            continue
        var selected: Array[String] = engine._apply_build("world.forja_rubra", build_id)
        print("10.8 Forja loadout %s total=%s" % [build_id, str(InventoryEngine.equipment_bonuses())])
        for item_id in selected:
            var item := ContentRegistry.get_record(item_id)
            print("10.8 Forja item %s slot=%s rarity=%s item=%s bonuses=%s affixes=%s" % [build_id, InventoryEngine.slot_for(item), str(item.get("rarity","")), str(item.get("name","")), str(AffixEngine.combined_effects(item)), str(AffixEngine.affixes_for(item))])

func _verify_regrets() -> void:
    var by_name: Dictionary = {}
    for row_variant in ContentRegistry.all("characters"):
        var row: Dictionary = row_variant as Dictionary
        by_name[str(row.get("name", ""))] = row

    print("10.8 targeted regret validation: seeds=%d" % REGRET_SEEDS)
    for name in REGRET_NAMES:
        var character: Dictionary = by_name.get(name, {}) as Dictionary
        if character.is_empty():
            print("10.8 targeted regret MISSING %s" % name)
            continue
        var character_id := str(character.get("id", ""))
        var curve: Dictionary = character.get("learning_curve", {}) as Dictionary
        var recommended := str(curve.get("recommended_policy", "balanced"))
        var scores: Dictionary = {}
        var victories: Dictionary = {}
        var stalemates: Dictionary = {}
        for policy_id in CONTROLLED:
            var score_total := 0.0
            var wins := 0
            var combat_timeouts := 0
            for sample_index in range(REGRET_SEEDS):
                var seed_value := BASE_SEED + absi(name.hash() % 100000) + sample_index * 97
                var result := simulator.simulate({
                    "character_id":character_id,
                    "policy_id":policy_id,
                    "build_id":"baseline",
                    "seed":seed_value,
                    "max_steps":MAX_STEPS,
                }, "andarilho")
                score_total += _score(result)
                if str(result.get("result", "")) == "victory": wins += 1
                combat_timeouts += int(result.get("combat_timeouts", 0))
            scores[policy_id] = score_total / float(REGRET_SEEDS)
            victories[policy_id] = float(wins) / float(REGRET_SEEDS)
            stalemates[policy_id] = combat_timeouts
        var best_policy := CONTROLLED[0]
        for policy_id in CONTROLLED:
            if float(scores[policy_id]) > float(scores[best_policy]): best_policy = policy_id
        print("10.8 targeted regret %s: rec=%s score=%.3f win=%.3f best=%s score=%.3f win=%.3f delta=%.3f all[B=%.3f A=%.3f C=%.3f E=%.3f] stalemates[B/A/C/E]=%d/%d/%d/%d" % [
            name,
            recommended,
            float(scores[recommended]),
            float(victories[recommended]),
            best_policy,
            float(scores[best_policy]),
            float(victories[best_policy]),
            float(scores[best_policy]) - float(scores[recommended]),
            float(scores.balanced),float(scores.aggressive),float(scores.cautious),float(scores.explorer),
            int(stalemates.balanced),int(stalemates.aggressive),int(stalemates.cautious),int(stalemates.explorer),
        ])

func _locate_cautious_stalemates() -> void:
    var contexts: Dictionary = {}
    var total_runs := 0
    var total_stalemates := 0
    for character_index in range(ContentRegistry.all("characters").size()):
        var character: Dictionary = ContentRegistry.all("characters")[character_index] as Dictionary
        var character_id := str(character.get("id", ""))
        var name := str(character.get("name", character_id))
        for difficulty_id in DifficultyEngine.ids():
            for build_id in BUILDS:
                var count := 0
                var steps_total := 0
                for sample_index in range(STALEMATE_SEEDS):
                    var seed_value := BASE_SEED + 500000 + character_index * 1009 + sample_index * 97
                    var result := simulator.simulate({
                        "character_id":character_id,
                        "policy_id":"cautious",
                        "build_id":build_id,
                        "seed":seed_value,
                        "max_steps":MAX_STEPS,
                    }, difficulty_id)
                    total_runs += 1
                    var n := int(result.get("combat_timeouts", 0))
                    if n > 0:
                        count += n
                        total_stalemates += n
                        steps_total += int(result.get("steps", 0))
                if count > 0:
                    var key := "%s|%s|%s" % [name,difficulty_id,build_id]
                    contexts[key] = {"count":count,"steps":steps_total}
    var rows: Array = []
    for key_variant in contexts.keys():
        var key := str(key_variant)
        var row: Dictionary = contexts[key] as Dictionary
        rows.append({"key":key,"count":int(row.count),"steps":int(row.steps)})
    rows.sort_custom(func(a,b): return int((a as Dictionary).count) > int((b as Dictionary).count))
    print("10.8 cautious stalemate localization: runs=%d stalemates=%d contexts=%d" % [total_runs,total_stalemates,rows.size()])
    for row_variant in rows:
        var row: Dictionary = row_variant as Dictionary
        print("10.8 cautious stalemate %s: count=%d avg_steps=%.2f" % [str(row.key),int(row.count),float(row.steps)/float(maxi(1,int(row.count)))])

func _stress_forja_ruptura() -> void:
    var forja: Array = []
    for row_variant in ContentRegistry.all("characters"):
        var row: Dictionary = row_variant as Dictionary
        if str(row.get("world_id", "")) == "world.forja_rubra": forja.append(row)
    print("10.8 Forja Ruptura stress: characters=%d seeds=32" % forja.size())
    for character_variant in forja:
        var character: Dictionary = character_variant as Dictionary
        for policy_id in CONTROLLED:
            for build_id in ["offense","defense","utility"]:
                var wins := 0
                var score_total := 0.0
                for sample_index in range(32):
                    var seed_value := BASE_SEED + 800000 + absi(str(character.get("id","")).hash() % 100000) + sample_index * 131
                    var result := simulator.simulate({
                        "character_id":str(character.get("id", "")),
                        "policy_id":policy_id,
                        "build_id":build_id,
                        "seed":seed_value,
                        "max_steps":MAX_STEPS,
                    }, "ruptura")
                    if str(result.get("result", "")) == "victory": wins += 1
                    score_total += _score(result)
                print("10.8 Forja stress %s/%s/%s: victory=%.3f score=%.3f" % [str(character.get("name","")),policy_id,build_id,float(wins)/32.0,score_total/32.0])

func _score(result: Dictionary) -> float:
    var score := 0.0
    if str(result.get("result", "")) == "victory": score += 1.0
    if bool(result.get("boss_reached", false)): score += 0.35
    if bool(result.get("boss_win", false)): score += 0.25
    var combats := maxi(1, int(result.get("combats", 0)))
    score += 0.15 * float(result.get("combat_wins", 0)) / float(combats)
    score += 0.10 * clampf(float(result.get("final_health", 0)) / 16.0, 0.0, 1.0)
    if str(result.get("result", "")) == "timeout": score -= 0.25
    return score
