class_name RoomCode
## Turns the host's IP address into a short room code like "KQ7M-X2D" and back, so players
## can share a code instead of an address. It works on the same network (LAN), or over the
## internet if the host forwards the game's port. Steam lobbies will replace this later.

## No 0/O or 1/I, so codes are easy to read out.
const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


## "192.168.1.20" -> "AGKQ-B2T" (or "" if it isn't an IPv4 address).
static func from_address(address: String) -> String:
	var parts := address.split(".")
	if parts.size() != 4:
		return ""
	var value := 0
	for part in parts:
		if not part.is_valid_int() or part.to_int() < 0 or part.to_int() > 255:
			return ""
		value = (value << 8) | part.to_int()
	var code := ""
	for i in 7:
		code = ALPHABET[value & 31] + code
		value >>= 5
	return code.left(4) + "-" + code.right(3)


## "AGKQ-B2T" -> "192.168.1.20", or "" if it isn't a valid code.
static func to_address(code: String) -> String:
	var clean := code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	if clean.length() != 7:
		return ""
	var value := 0
	for letter in clean:
		var digit := ALPHABET.find(letter)
		if digit < 0:
			return ""
		value = (value << 5) | digit
	if value >> 32 != 0:
		return ""
	return "%d.%d.%d.%d" % [(value >> 24) & 255, (value >> 16) & 255, (value >> 8) & 255, value & 255]


## Whatever the player typed: a room code, or an address as it is.
static func resolve(typed: String) -> String:
	var address := to_address(typed)
	return address if address != "" else typed.strip_edges()


## This computer's address on the local network, e.g. "192.168.1.20" ("127.0.0.1" if none).
static func local_address() -> String:
	var fallback := ""
	for address in IP.get_local_addresses():
		if address.count(".") != 3 or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			return address
		if fallback == "":
			fallback = address
	return fallback if fallback != "" else "127.0.0.1"
