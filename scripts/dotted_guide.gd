extends Node2D
## The dotted guide line for the stroke the child is being asked to trace,
## with a marker showing where to start and which way to go.
##
## Godot's Line2D has no dash mode, so the dashes are drawn here: the stroke is
## resampled to a fixed arc-length spacing and a dot is drawn at each sample.
## The alternatives were a tiled line texture (an asset to author and a texture
## that stretches on corners) and a series of Line2D nodes (dozens of nodes per
## stroke). This redraws only when the stroke changes — never per frame.

const SD := preload("res://scripts/stroke_data.gd")

const DOT_SPACING := 34.0  ## Px along the path between dot centres.
const DOT_RADIUS := 7.0
const DOT_COLOR := Color(0.44, 0.5, 0.62, 0.85)

const START_RADIUS := 30.0
const START_RING_WIDTH := 7.0
const START_COLOR := Color(0.92, 0.45, 0.12, 0.95)
const ARROW_LENGTH := 64.0  ## How far along the stroke the arrow sits — clear of the ring.
const ARROW_SIZE := 22.0

var _points := PackedVector2Array()


## Show `points` (screen space) as the stroke to trace. An empty array clears.
func set_stroke(points: PackedVector2Array) -> void:
	_points = points
	queue_redraw()


func clear() -> void:
	set_stroke(PackedVector2Array())


func _draw() -> void:
	if _points.is_empty():
		return
	for dot in SD.resample_stroke(_points, DOT_SPACING):
		draw_circle(dot, DOT_RADIUS, DOT_COLOR, true, -1.0, true)
	var start := _points[0]
	draw_circle(start, DOT_RADIUS * 1.4, START_COLOR, true, -1.0, true)
	draw_circle(start, START_RADIUS, START_COLOR, false, START_RING_WIDTH, true)
	_draw_direction_arrow(start)


## A small arrowhead a little way along the stroke: the start marker says where
## to put the finger, this says which way to move it. Stroke *direction* is half
## of what the recorded data is for.
func _draw_direction_arrow(start: Vector2) -> void:
	var tip := SD.partial_stroke(_points, ARROW_LENGTH)
	if tip.size() < 2:
		return
	var heading := (tip[-1] - start)
	if heading.length() < 1.0:
		return
	heading = heading.normalized()
	var side := heading.orthogonal() * (ARROW_SIZE * 0.5)
	var base := tip[-1]
	draw_colored_polygon(PackedVector2Array([
		base + heading * ARROW_SIZE, base + side, base - side,
	]), START_COLOR)
