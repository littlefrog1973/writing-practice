extends CPUParticles2D
## The celebration confetti on the score card.
##
## CPUParticles2D rather than GPUParticles2D: the target machine is a Surface Go
## running the Compatibility renderer on an iGPU, where a particle shader is the
## thing most likely to cost the smooth frame rate GATE 5 was about. Sixty CPU
## particles cost nothing measurable.
##
## One node, configured in the scene, `restart()`ed per celebration — never a
## node created per character, which is the rule stroke_animator.gd set.
##
## The only thing done in code is the particle texture: an untextured
## CPUParticles2D draws single points, so each particle gets a small rounded
## square drawn into an Image here. That keeps it an asset-free celebration —
## nothing to licence, nothing to import.

const TEXTURE_SIZE := 14
const CORNER := 3.0  ## Corner radius, in pixels of the generated texture.


func _ready() -> void:
	texture = _make_texture()
	emitting = false


## Throw the confetti. Called on every score, whatever it was: one star is a
## reason to celebrate having finished the character, not a reason to sit still.
func celebrate() -> void:
	restart()
	emitting = true


## A white rounded square, tinted per particle by the colour ramp. Drawn by hand
## rather than shipped as a .png so the repo stays code and stroke data only.
func _make_texture() -> ImageTexture:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0))
	var last := float(TEXTURE_SIZE - 1)
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			# Distance outside the rounded rectangle's straight edges; inside
			# the corners it is the distance from the corner's centre.
			var dx := maxf(maxf(CORNER - float(x), float(x) - (last - CORNER)), 0.0)
			var dy := maxf(maxf(CORNER - float(y), float(y) - (last - CORNER)), 0.0)
			var alpha := clampf(CORNER + 0.5 - Vector2(dx, dy).length(), 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)
