extends Node

signal page_changed
signal choice_committed
signal mark_added(mark_id: String)
signal damage_applied(target: String, amount: int)
signal intent_revealed(intent: Dictionary)
signal boss_phase_changed(phase_index: int)
signal location_changed(location_id: String)

func page() -> void:
    page_changed.emit()

func choice() -> void:
    choice_committed.emit()

func mark(mark_id: String) -> void:
    mark_added.emit(mark_id)

func damage(target: String, amount: int) -> void:
    if amount > 0:
        damage_applied.emit(target, amount)

func intent(intent_data: Dictionary) -> void:
    intent_revealed.emit(intent_data)

func boss_phase(index: int) -> void:
    boss_phase_changed.emit(index)

func location(location_id: String) -> void:
    location_changed.emit(location_id)
