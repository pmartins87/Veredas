extends Node

const SEEDS := 64
const CASES := [
    {"character_id":"character.cidade_mil_portas.03","policy_id":"explorer","build_id":"offense"},
    {"character_id":"character.tear_desfeito.02","policy_id":"cautious","build_id":"offense"},
    {"character_id":"character.salinas_ossamar.03","policy_id":"cautious","build_id":"utility"},
    {"character_id":"character.noite_iscara.03","policy_id":"aggressive","build_id":"defense"},
    {"character_id":"character.varzea_espelhos.03","policy_id":"cautious","build_id":"offense"},
]

var simulator := DifficultySimulationEngine.new()

func _ready() -> void:
    await get_tree().process_frame
    for case in CASES:
        _audit_case(case)
    print("RUPTURE_SYNTHETIC_BUILD_AUDIT PASS")
    get_tree().quit(0)

func _audit_case(case: Dictionary) -> void:
    var wins := 0
    var build_items: Array = []
    for i in range(SEEDS):
        var seed_value := 3100000 + i * 173
        var result := simulator.simulate({
            "character_id":str(case.character_id),
            "policy_id":str(case.policy_id),
            "build_id":str(case.build_id),
            "seed":seed_value,
            "max_steps":80,
        }, "ruptura")
        if not bool(result.get("ok", false)):
            print("RUPTURE_SYNTHETIC_BUILD_AUDIT FAIL: invalid %s" % str(case))
            get_tree().quit(1)
            return
        if i == 0:
            build_items = (result.get("build_items", []) as Array).duplicate()
        if str(result.get("result", "")) == "victory":
            wins += 1
    var total_buy := 0
    var total_sell := 0
    var rarity_counts := {}
    var combined := {}
    for item_variant in build_items:
        var item_id := str(item_variant)
        var item := ContentRegistry.get_record(item_id)
        total_buy += ItemEconomyEngine.buy_price(item_id)
        total_sell += ItemEconomyEngine.sell_price(item_id)
        var rarity := str(item.get("rarity", "common"))
        rarity_counts[rarity] = int(rarity_counts.get(rarity,0)) + 1
        var bonuses := AffixEngine.combined_effects(item)
        for key in bonuses.keys():
            combined[str(key)] = float(combined.get(str(key),0.0)) + float(bonuses[key])
        print("10.8 synthetic item %s/%s/%s: %s rarity=%s buy=%d bonuses=%s" % [str(case.character_id),str(case.policy_id),str(case.build_id),item_id,rarity,ItemEconomyEngine.buy_price(item_id),str(bonuses)])
    print("10.8 synthetic case %s/%s/%s: wins=%d/%d rate=%.3f items=%d buy_value=%d sell_value=%d starting_fragments=12 rarities=%s bonuses=%s" % [str(case.character_id),str(case.policy_id),str(case.build_id),wins,SEEDS,float(wins)/float(SEEDS),build_items.size(),total_buy,total_sell,str(rarity_counts),str(combined)])
