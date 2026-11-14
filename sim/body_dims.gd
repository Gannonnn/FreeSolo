class_name BodyDims
extends RefCounted
## Segment lengths in meters, derived once from height and ape index. They never change during a run.

var height: float
var upper_arm: float
## Elbow to grip point.
var forearm: float
var thigh: float
## Knee to foot contact. Also decides which knee-bars fit.
var shin: float
## Hip joint to shoulder joint.
var torso: float
var shoulder_width: float
var hip_width: float


static func from_character(def: CharacterDef) -> BodyDims:
	return BodyDims.from_measurements(def.height, def.ape_index)


static func from_measurements(height_m: float, ape_index: float) -> BodyDims:
	var b := BodyDims.new()
	b.height = height_m
	b.shoulder_width = height_m * Tuning.SHOULDER_WIDTH
	b.hip_width = height_m * Tuning.HIP_WIDTH
	b.torso = height_m * Tuning.TORSO
	var arm := (height_m * ape_index - b.shoulder_width) * 0.5 * Tuning.ARM_GRIP_POINT
	b.upper_arm = arm * Tuning.UPPER_ARM_SHARE
	b.forearm = arm - b.upper_arm
	b.thigh = height_m * Tuning.THIGH
	b.shin = height_m * Tuning.SHIN
	return b


func arm_length() -> float:
	return upper_arm + forearm


func leg_length() -> float:
	return thigh + shin
