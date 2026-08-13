extends RefCounted
class_name PurchaseReference

const PREFIX := "sha256:"
const SHA256_HEX_LENGTH := 64
const HEX_CHARS := "0123456789abcdef"


static func from_sensitive(value: String) -> String:
    var normalized := value.strip_edges()
    if normalized.is_empty():
        return ""
    var context := HashingContext.new()
    if context.start(HashingContext.HASH_SHA256) != OK:
        return ""
    if context.update(normalized.to_utf8_buffer()) != OK:
        return ""
    var digest := context.finish()
    if digest.size() != 32:
        return ""
    return PREFIX + digest.hex_encode()


static func normalize_persisted(value: String) -> String:
    var normalized := value.strip_edges()
    if normalized.is_empty():
        return ""
    if is_reference(normalized):
        return normalized.to_lower()
    return from_sensitive(normalized)


static func is_reference(value: String) -> bool:
    var normalized := value.strip_edges().to_lower()
    if not normalized.begins_with(PREFIX):
        return false
    var hex_value := normalized.substr(PREFIX.length())
    if hex_value.length() != SHA256_HEX_LENGTH:
        return false
    for index in range(hex_value.length()):
        if HEX_CHARS.find(hex_value.substr(index, 1)) < 0:
            return false
    return true
