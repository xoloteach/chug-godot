extends Node

## AudioManager - Procedural Synthesizer & Sound Effect Generator
## Generates clean procedural punch impacts, blade slashes, parry rings, rage surges, and ambient void drones.

var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
const MAX_SFX_CHANNELS: int = 12

var sound_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Master"
	add_child(music_player)

	for i in range(MAX_SFX_CHANNELS):
		var p = AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)

	_generate_all_sfx()
	_load_external_audio()

func _load_external_audio() -> void:
	# Load external music if available
	var music_files = {
		"story": "res://assets/audio/music/ambient_story.ogg",
		"combat": "res://assets/audio/music/ambient_combat.ogg",
		"camp": "res://assets/audio/music/ambient_camp.ogg"
	}
	
	for m_key in music_files:
		var path = music_files[m_key]
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is AudioStream:
				sound_cache["ambient_" + m_key] = res
	
	# Load external sfx if available
	var sfx_files = {
		"ko": "res://assets/audio/sfx/ko.wav",
		"ui_confirm": "res://assets/audio/sfx/ui_confirm.wav",
		"whoosh": "res://assets/audio/sfx/whoosh.wav",
		"hit_light": "res://assets/audio/sfx/hit_light.wav"
	}
	
	for s_key in sfx_files:
		var s_path = sfx_files[s_key]
		if ResourceLoader.exists(s_path):
			var s_res = load(s_path)
			if s_res is AudioStream:
				sound_cache[s_key] = s_res

func _get_available_player() -> AudioStreamPlayer:
	for p in sfx_players:
		if not p.playing:
			return p
	return sfx_players[0]

func play_sfx(sound_name: String, pitch_rnd: float = 0.05) -> void:
	if not sound_cache.has(sound_name):
		return
	
	var player = _get_available_player()
	player.stream = sound_cache[sound_name]
	player.pitch_scale = 1.0 + randf_range(-pitch_rnd, pitch_rnd)
	player.volume_db = linear_to_db(SaveStore.data["settings"]["sfx_volume"])
	player.play()

func play_music(music_type: String) -> void:
	# Create a procedural looping ambient drone for battle/story/camp
	if sound_cache.has("ambient_" + music_type):
		music_player.stream = sound_cache["ambient_" + music_type]
		music_player.volume_db = linear_to_db(SaveStore.data["settings"]["music_volume"] * 0.7)
		if not music_player.playing:
			music_player.play()

func stop_music() -> void:
	music_player.stop()

func _generate_all_sfx() -> void:
	sound_cache["hit_light"] = _create_punch_sfx(180.0, 0.08, 0.6)
	sound_cache["hit_heavy"] = _create_punch_sfx(110.0, 0.16, 0.9)
	sound_cache["slash"] = _create_slash_sfx(0.12)
	sound_cache["parry"] = _create_parry_sfx()
	sound_cache["block"] = _create_block_sfx()
	sound_cache["whoosh"] = _create_whoosh_sfx()
	sound_cache["rage_surge"] = _create_rage_sfx()
	sound_cache["glitch"] = _create_glitch_sfx()
	sound_cache["ui_click"] = _create_click_sfx(600.0, 0.04)
	sound_cache["ui_confirm"] = _create_click_sfx(880.0, 0.08)
	sound_cache["ko"] = _create_ko_sfx()
	sound_cache["ambient_story"] = _create_ambient_loop(110.0, 3.0)
	sound_cache["ambient_combat"] = _create_ambient_loop(70.0, 2.0)
	sound_cache["ambient_camp"] = _create_ambient_loop(160.0, 4.0)

# Procedural WAV generation helpers
func _create_wav(samples: PackedByteArray, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = samples
	return wav

func _create_punch_sfx(base_freq: float, duration: float, impact: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var buffer = PackedByteArray()
	buffer.resize(total_samples)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var progress = float(i) / float(total_samples)
		var env = pow(1.0 - progress, 2.5)
		var freq = base_freq * (1.0 - progress * 0.7)
		var noise = (randf() * 2.0 - 1.0) * env * (1.0 - progress) * impact
		var sine = sin(TAU * freq * t) * env
		var sample_val = clampf((sine * 0.6 + noise * 0.4), -1.0, 1.0)
		var byte_val = int(clampf((sample_val + 1.0) * 127.5, 0, 255))
		buffer[i] = byte_val
	
	return _create_wav(buffer, sample_rate)

func _create_slash_sfx(duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var buffer = PackedByteArray()
	buffer.resize(total_samples)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var progress = float(i) / float(total_samples)
		var env = sin(progress * PI)
		var noise = (randf() * 2.0 - 1.0) * env
		var sweep_freq = 1200.0 - (progress * 800.0)
		var tone = sin(TAU * sweep_freq * t) * env * 0.4
		var sample_val = clampf(noise * 0.7 + tone * 0.3, -1.0, 1.0)
		buffer[i] = int(clampf((sample_val + 1.0) * 127.5, 0, 255))
	
	return _create_wav(buffer, sample_rate)

func _create_parry_sfx() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.35
	var total_samples = int(sample_rate * duration)
	var buffer = PackedByteArray()
	buffer.resize(total_samples)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var progress = float(i) / float(total_samples)
		var env = exp(-progress * 12.0)
		var chime1 = sin(TAU * 1400.0 * t)
		var chime2 = sin(TAU * 2200.0 * t) * 0.7
		var chime3 = sin(TAU * 3400.0 * t) * 0.4
		var sample_val = clampf((chime1 + chime2 + chime3) * 0.4 * env, -1.0, 1.0)
		buffer[i] = int(clampf((sample_val + 1.0) * 127.5, 0, 255))
	
	return _create_wav(buffer, sample_rate)

func _create_block_sfx() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.12
	var total_samples = int(sample_rate * duration)
	var buffer = PackedByteArray()
	buffer.resize(total_samples)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var progress = float(i) / float(total_samples)
		var env = exp(-progress * 20.0)
		var thud = sin(TAU * 130.0 * t) * env
		var click = (randf() * 2.0 - 1.0) * env * 0.5
		var sample_val = clampf(thud * 0.7 + click * 0.3, -1.0, 1.0)
		buffer[i] = int(clampf((sample_val + 1.0) * 127.5, 0, 255))
	
	return _create_wav(buffer, sample_rate)

func _create_whoosh_sfx() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.15
	var total_samples = int(sample_rate * duration)
	var buffer = PackedByteArray()
	buffer.resize(total_samples)
	
	for i in range(total_samples):
		var progress = float(i) / float(total_samples)
		var env = sin(progress * PI)
		var noise = (randf() * 2.0 - 1.0) * env * 0.6
		buffer[i] = int(clampf((noise + 1.0) * 127.5, 0, 255))
	
	return _create_wav(buffer, sample_rate)

func _create_rage_sfx() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.6
	var total_samples = int(sample_rate * duration)
	var buffer = PackedByteArray()
	buffer.resize(total_samples)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var progress = float(i) / float(total_samples)
		var env = sin(progress * PI)
		var rise_freq = 60.0 + (progress * 300.0)
		var pulse = sin(TAU * rise_freq * t) * env
		var noise = (randf() * 2.0 - 1.0) * env * 0.4
		var sample_val = clampf(pulse * 0.7 + noise * 0.3, -1.0, 1.0)
		buffer[i] = int(clampf((sample_val + 1.0) * 127.5, 0, 255))
	
	return _create_wav(buffer, sample_rate)

func _create_glitch_sfx() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.2
	var total_samples = int(sample_rate * duration)
	var buffer = PackedByteArray()
	buffer.resize(total_samples)
	
	for i in range(total_samples):
		var progress = float(i) / float(total_samples)
		var env = 1.0 - progress
		var square = 1.0 if fmod(float(i), 30.0) < 15.0 else -1.0
		var noise = (randf() * 2.0 - 1.0)
		var sample_val = clampf((square * 0.5 + noise * 0.5) * env * 0.5, -1.0, 1.0)
		buffer[i] = int(clampf((sample_val + 1.0) * 127.5, 0, 255))
	
	return _create_wav(buffer, sample_rate)

func _create_click_sfx(freq: float, duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var buffer = PackedByteArray()
	buffer.resize(total_samples)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var progress = float(i) / float(total_samples)
		var env = exp(-progress * 25.0)
		var tone = sin(TAU * freq * t) * env * 0.5
		buffer[i] = int(clampf((tone + 1.0) * 127.5, 0, 255))
	
	return _create_wav(buffer, sample_rate)

func _create_ko_sfx() -> AudioStreamWAV:
	var sample_rate = 22050
	var duration = 0.8
	var total_samples = int(sample_rate * duration)
	var buffer = PackedByteArray()
	buffer.resize(total_samples)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var progress = float(i) / float(total_samples)
		var env = exp(-progress * 4.0)
		var gong = (sin(TAU * 90.0 * t) + sin(TAU * 135.0 * t) * 0.5) * env
		buffer[i] = int(clampf((gong + 1.0) * 127.5, 0, 255))
	
	return _create_wav(buffer, sample_rate)

func _create_ambient_loop(base_freq: float, duration: float) -> AudioStreamWAV:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var buffer = PackedByteArray()
	buffer.resize(total_samples)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var tone = (sin(TAU * base_freq * t) + sin(TAU * (base_freq * 1.5) * t) * 0.3) * 0.25
		buffer[i] = int(clampf((tone + 1.0) * 127.5, 0, 255))
	
	var wav = _create_wav(buffer, sample_rate)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total_samples
	return wav
