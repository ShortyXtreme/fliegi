class_name FuelTruck
extends GroundVehicle
## M3 Stub (Paket 0b, gehört Strang H / Paket 6): Tankwagen, 2.000 l, Schlauch 12 m
## (Kurve aus Segmenten, Marker hose_reel). tank ist eine FuelSource (RefuelJob.source).

const TANK_CAPACITY := 2000.0
const HOSE_LENGTH := 12.0

var tank := FuelSource.new({FuelSystem.GRADE_AVIATION: TANK_CAPACITY},
	{FuelSystem.GRADE_AVIATION: TANK_CAPACITY, FuelSystem.GRADE_ERSATZ: TANK_CAPACITY})
