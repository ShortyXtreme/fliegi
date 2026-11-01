class_name AmmoCart
extends GroundVehicle
## M3 Stub (Paket 0b, gehört Strang H / Paket 6): Munitionswagen (Lkw) mit 6 Kisten
## (Marker crate_slot_1..6). store ist der Vorrat (AmmoStore) für RearmJob.

const CRATE_SLOTS := 6
const ROUNDS_PER_CRATE := 500

var crates := CRATE_SLOTS
var store := AmmoBunker.new({AmmoBunker.AMMO_792: CRATE_SLOTS * ROUNDS_PER_CRATE})
