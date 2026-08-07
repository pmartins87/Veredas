extends Node

const EXPECTED := {
    "worlds":12,"locations":120,"families":96,"monsters":300,"bosses":60,
    "items":1116,"npcs":300,"marks":204,"debts":120,"characters":36,
    "abilities":72,"events":2544,"finals":36,"pools":144,
}

func validate() -> Array[String]:
    var errors: Array[String] = []
    var seen := {}
    for category in EXPECTED:
        var rows := ContentRegistry.all(category)
        if rows.size() != int(EXPECTED[category]):
            errors.append("%s count %d != %d" % [category, rows.size(), EXPECTED[category]])
        for row in rows:
            var record_id := str(row.get("id", ""))
            if record_id == "":
                errors.append("%s has empty id" % category)
            elif seen.has(record_id):
                errors.append("duplicate id %s" % record_id)
            else:
                seen[record_id] = true
    for monster in ContentRegistry.all("monsters"):
        _need(errors, monster, "world_id")
        _need(errors, monster, "location_id")
        _need(errors, monster, "family_id")
    for boss in ContentRegistry.all("bosses"):
        _need(errors, boss, "world_id")
        _need(errors, boss, "location_id")
        if boss.get("phases", []).size() < 3:
            errors.append("boss %s has fewer than 3 phases" % boss.get("id", ""))
    for event in ContentRegistry.all("events"):
        _need(errors, event, "world_id")
        if str(event.get("location_id", "")) != "":
            _need(errors, event, "location_id")
        if event.get("choices", []).is_empty():
            errors.append("event %s has no choices" % event.get("id", ""))
    return errors

func _need(errors: Array[String], record: Dictionary, key: String) -> void:
    var ref_id := str(record.get(key, ""))
    if ref_id == "" or ContentRegistry.get_record(ref_id).is_empty():
        errors.append("%s broken %s=%s" % [record.get("id", "?"), key, ref_id])
