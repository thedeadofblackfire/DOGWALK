extends Node

## Gathered items
enum interactable_ids {
	CHOCOMEL=0,
	PINDA=1,
	SNOWMAN=2, 
	GATE=3, 
	WILLOW=4, 
	ITEM_GENERIC=10,
	BRANCH=11,
	TENNIS_BALL=12, 
	SHOVEL=13, 
	TRAFFIC_CONE=14, 
	EAR_MUFFS=15
}

## Shorter list of only item IDs
var item_ids : Array = [
	interactable_ids.ITEM_GENERIC,
	interactable_ids.BRANCH,
	interactable_ids.TENNIS_BALL,
	interactable_ids.SHOVEL,
	interactable_ids.TRAFFIC_CONE,
	interactable_ids.EAR_MUFFS,
]

## States depending on terrain a character is on
enum terrain_states {
	NONE,
	ROAD,
	SNOW,
	ICE
}
