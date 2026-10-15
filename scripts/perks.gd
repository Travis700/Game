class_name Perks
extends RefCounted
## Perks: one small edge each guard brings to work, picked on the menu. A new one unlocks with
## each rank, so there's always something to try next, and a team can cover for each other
## (one Lookout with the EMF, one Track star to run the key...).

## Each perk: its name, the rank that unlocks it, and what it does.
const PERKS := {
	"thermos": {"name": "Thermos", "rank": 1, "text": "Your nerve wears down 25% slower."},
	"track_star": {"name": "Track star", "rank": 2, "text": "50% more stamina: run further before you're winded."},
	"spare_batteries": {"name": "Spare batteries", "rank": 3, "text": "Your flashlight reaches 20% further, and never runs weak on Old batteries nights."},
	"handy": {"name": "Handy", "rank": 4, "text": "Anything you hold E on (breakers, punch stations...) takes half as long."},
	"low_profile": {"name": "Low profile", "rank": 5, "text": "Monsters notice you from 15% less far away."},
	"lookout": {"name": "Lookout", "rank": 6, "text": "You always carry an EMF reader."},
	"cool_head": {"name": "Cool head", "rank": 7, "text": "Hiding in a cupboard doesn't cost you any nerve."},
}


static func is_unlocked(perk: String, rank := -1) -> bool:
	if not PERKS.has(perk):
		return false
	return (Career.rank() if rank < 0 else rank) >= int(PERKS[perk]["rank"])


## The perk to bring: the one picked, if it's known and unlocked, otherwise the first.
static func valid(perk: String, rank := -1) -> String:
	return perk if is_unlocked(perk, rank) else "thermos"


static func describe(perk: String) -> String:
	return "%s: %s" % [PERKS[perk]["name"], PERKS[perk]["text"]] if PERKS.has(perk) else ""
