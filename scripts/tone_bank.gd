class_name ToneBank
extends RefCounted
## The score screen's sounds, synthesized in code — Step 6.
##
## There is no assets/audio/ directory and there deliberately is not one. Every
## other asset in this project came with a licence file next to it (the two OFL
## fonts), and free sound effects are the easiest place to pick up an asset
## whose provenance nobody can reconstruct a year later. A few dozen lines of
## additive synthesis have no licence question at all, add no binary to a repo
## whose point is hand-authored data, and cost about a millisecond each.
##
## Static and pure: it returns AudioStreamWAV resources and never touches a
## node, so tests/test_scorer.gd can check them headless.
##
## The voice is a simple bell — a few harmonic partials, each decaying faster
## than the one below it, with a short attack so the speaker never clicks.
## Built once when the tracing scene loads, never per celebration.

const MIX_RATE := 22050  ## Plenty for a bell; a quarter of the RAM of 44.1 kHz.
const PEAK := 0.82  ## Headroom, so two overlapping notes cannot clip.

## Partials of the bell: multiple of the fundamental, its share of the volume,
## and how fast it dies away (bigger = shorter). Upper partials fading first is
## what makes a struck-metal sound rather than an organ.
const PARTIALS: Array[float] = [1.0, 2.0, 3.01]
const PARTIAL_GAINS: Array[float] = [1.0, 0.4, 0.16]
const PARTIAL_DECAYS: Array[float] = [3.6, 5.4, 8.0]

const ATTACK := 0.006  ## Seconds of fade-in — without it the note starts on a click.

## One note per star, rising: C6, E6, G6. Played as each star lands, so three
## stars ring out as a major chord.
const STAR_FREQS: Array[float] = [1046.5, 1318.5, 1568.0]
const STAR_SECONDS := 0.8

## The flourish after the last star, per star count (index = stars - 1).
## One star gets a warm two-note lift, not a sad trombone: the child is being
## invited to try again, and the sound has to sound like an invitation.
const FANFARE_SECONDS := 1.8


## The note that rings as star `index` (0-based) lands on the card.
static func star_tone(index: int) -> AudioStreamWAV:
	var freq: float = STAR_FREQS[clampi(index, 0, STAR_FREQS.size() - 1)]
	var buffer := _silence(STAR_SECONDS)
	_bell(buffer, 0.0, freq, 1.0, 1.0)
	return _to_stream(buffer)


## The flourish played once the stars have all landed. `stars` is 1–3.
static func fanfare(stars: int) -> AudioStreamWAV:
	var buffer := _silence(FANFARE_SECONDS)
	match clampi(stars, 1, 3):
		3:
			# A rising arpeggio finishing an octave up: unmistakably "well done".
			_bell(buffer, 0.00, 1046.5, 0.7, 1.6)
			_bell(buffer, 0.11, 1318.5, 0.7, 1.6)
			_bell(buffer, 0.22, 1568.0, 0.7, 1.6)
			_bell(buffer, 0.34, 2093.0, 1.0, 0.5)
		2:
			_bell(buffer, 0.00, 1046.5, 0.8, 1.2)
			_bell(buffer, 0.14, 1568.0, 1.0, 0.6)
		_:
			_bell(buffer, 0.00, 698.5, 0.8, 1.1)
			_bell(buffer, 0.16, 880.0, 1.0, 0.7)
	return _to_stream(buffer)


# --- synthesis ---------------------------------------------------------------

static func _silence(seconds: float) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(int(seconds * MIX_RATE))  ## Packed arrays resize zero-filled.
	return buffer


## Mix a bell note into `buffer`, starting `at` seconds in. `decay_scale` above
## 1 lengthens the ring, below 1 shortens it.
static func _bell(buffer: PackedFloat32Array, at: float, freq: float,
		gain: float, decay_scale: float) -> void:
	var first := int(at * MIX_RATE)
	var attack_samples := maxi(int(ATTACK * MIX_RATE), 1)
	for i in range(first, buffer.size()):
		var t := float(i - first) / float(MIX_RATE)
		var value := 0.0
		for p in PARTIALS.size():
			var envelope: float = PARTIAL_GAINS[p] * exp(-PARTIAL_DECAYS[p] * t / decay_scale)
			value += envelope * sin(TAU * freq * PARTIALS[p] * t)
		var ramp := minf(float(i - first) / float(attack_samples), 1.0)
		buffer[i] += value * gain * ramp


## Normalize to PEAK and encode as 16-bit mono PCM.
static func _to_stream(buffer: PackedFloat32Array) -> AudioStreamWAV:
	var loudest := 0.0
	for value in buffer:
		loudest = maxf(loudest, absf(value))
	var scale := (PEAK / loudest) if loudest > 0.0 else 0.0
	var data := PackedByteArray()
	data.resize(buffer.size() * 2)
	for i in buffer.size():
		data.encode_s16(i * 2, int(clampf(buffer[i] * scale, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
