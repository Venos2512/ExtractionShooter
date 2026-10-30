class_name Cards
extends RefCounted
## Build cards. Each has a stack limit so the offer stays useful late in a run.
## Legendary cards change how you play rather than adding a percentage.

enum Rarity {COMMON, RARE, LEGENDARY}

const ALL := [
	{"id": "rate", "title": "Bắn nhanh", "desc": "Tốc độ bắn +20%", "rarity": Rarity.COMMON, "max": 6},
	{"id": "damage", "title": "Đạn nặng", "desc": "Sát thương +25%", "rarity": Rarity.COMMON, "max": 6},
	{"id": "crit", "title": "Ngắm hiểm", "desc": "Chí mạng +15%", "rarity": Rarity.COMMON, "max": 4},
	{"id": "hp", "title": "Giáp vá", "desc": "Máu tối đa +30, hồi 30 máu", "rarity": Rarity.COMMON, "max": 5},
	{"id": "dash", "title": "Giày nhẹ", "desc": "Hồi lướt nhanh hơn 30%", "rarity": Rarity.COMMON, "max": 3},
	{"id": "magnet", "title": "Nam châm", "desc": "Bán kính hút đồ +60%", "rarity": Rarity.COMMON, "max": 3},
	{"id": "pierce", "title": "Đạn xuyên", "desc": "Đạn xuyên thêm 1 zombie", "rarity": Rarity.RARE, "max": 3},
	{"id": "grenade", "title": "Lựu đạn", "desc": "Tự ném lựu đạn, thêm 1 quả mỗi thẻ", "rarity": Rarity.RARE, "max": 3},
	{"id": "radius", "title": "Thuốc nổ", "desc": "Bán kính nổ +30%", "rarity": Rarity.RARE, "max": 3},
	{"id": "drone", "title": "Drone", "desc": "Thêm 1 drone tự bắn", "rarity": Rarity.RARE, "max": 3},
	{"id": "laser", "title": "Laser xoay", "desc": "Tia laser xoay quanh bạn", "rarity": Rarity.LEGENDARY, "max": 3},
	{"id": "bounce", "title": "Đạn nảy", "desc": "Đạn nảy sang zombie gần nhất", "rarity": Rarity.LEGENDARY, "max": 2},
	{"id": "chain", "title": "Nổ dây chuyền", "desc": "Zombie chết có 20% phát nổ", "rarity": Rarity.LEGENDARY, "max": 2},
]
const WEIGHTS := {Rarity.COMMON: 10.0, Rarity.RARE: 4.0, Rarity.LEGENDARY: 1.5}
const COLORS := {
	Rarity.COMMON: Color(0.30, 0.45, 0.62),
	Rarity.RARE: Color(0.50, 0.32, 0.72),
	Rarity.LEGENDARY: Color(0.86, 0.56, 0.16),
}


static func offer(taken: Dictionary, count: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for c in ALL:
		if int(taken.get(c.id, 0)) < int(c.max):
			pool.append(c)
	var picked: Array = []
	while picked.size() < count and not pool.is_empty():
		var total := 0.0
		for c in pool:
			total += float(WEIGHTS[c.rarity])
		var roll := rng.randf() * total
		for c in pool:
			roll -= float(WEIGHTS[c.rarity])
			if roll <= 0.0:
				picked.append(c)
				pool.erase(c)
				break
	return picked


static func apply(card: Dictionary, p: Player) -> void:
	match String(card.id):
		"rate":
			p.fire_rate *= 1.2
		"damage":
			p.damage *= 1.25
		"crit":
			p.crit += 0.15
		"hp":
			p.max_hp += 30.0
			p.hp = minf(p.hp + 30.0, p.max_hp)
		"dash":
			p.dash_cooldown *= 0.7
		"magnet":
			p.pickup_radius *= 1.6
		"pierce":
			p.pierce += 1
		"grenade":
			p.grenades += 1
		"radius":
			p.blast_radius *= 1.3
		"drone":
			p.drones += 1
		"laser":
			p.lasers += 1
		"bounce":
			p.bounces += 1
		"chain":
			p.chain_chance += 0.2
