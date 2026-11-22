extends Node

@onready var MUSIC_PLAYER: AudioStreamPlayer = $MusicPlayer;
@onready var AMB_PLAYER:AudioStreamPlayer = $AmbiencePlayer;

func play_sound(sound: AudioStream, volume: float = 0.3):
	if !sound: return;

	var stream = AudioStreamPlayer.new();

	stream.bus = "Sfx";
	stream.stream = sound;
	stream.connect("finished", stream.queue_free);
	stream.pitch_scale = randf_range(0.8,1.1);

	stream.volume_db = volume;

	stream.tree_entered.connect(stream.play);
	#original - just in case something goes wrong can reference
	#get_tree().current_scene.add_child(stream);

	add_child(stream);

func play_music(music: AudioStream):
	if MUSIC_PLAYER.stream == music:
		#if same music is already playing...
		return;

	MUSIC_PLAYER.stream = null;
	MUSIC_PLAYER.stream = music;

	MUSIC_PLAYER.play();

func is_music_playing()->bool:
	return MUSIC_PLAYER.playing

func play_ambience(amb: AudioStream):
	if(AMB_PLAYER.stream == amb):
		return;

	AMB_PLAYER.stream = null;
	AMB_PLAYER.stream = amb;

	AMB_PLAYER.play();

func is_amb_playing()->bool:
	return AMB_PLAYER.playing;


# ---------------------------------------------------------------- additions (fades, loops, ducking)
# Everything above is unchanged. These are used by the TetherRig, the cord, DialogueMusic steps
# and LevelAudio-style setups. Volumes are in dB like play_sound.

var _tweens := {}   # player -> its running fade tween

## Like play_sound, but at a fixed pitch (no random variation). For stingers like the sever "TACK".
func play_sound_exact(sound: AudioStream, volume: float = 0.3, pitch: float = 1.0) -> void:
	if !sound: return
	var p := AudioStreamPlayer.new()
	p.bus = "Sfx"
	p.stream = sound
	p.volume_db = volume
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	p.tree_entered.connect(p.play)
	add_child(p)

## A looping SFX player you control yourself (volume, pitch, play/stop). It's created as a child
## of `owner_node`, so it's cleaned up with that node. WAVs without a loop point get looped here;
## for OGG/MP3 tick "Loop" in the Import dock.
func make_loop(sound: AudioStream, owner_node: Node, volume: float = -60.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Sfx"
	p.volume_db = volume
	p.stream = _looped(sound)
	owner_node.add_child(p)
	return p

## Music with a fade: fades the current track out and the new one in over `fade` seconds.
## Same track already playing = nothing happens. Pass null to fade the music out and stop.
func play_music_fade(music: AudioStream, fade: float = 1.5, volume: float = 0.0) -> void:
	_crossfade(MUSIC_PLAYER, music, fade, volume)

## Ambience with a fade (same rules as play_music_fade). Pass null to fade it out and stop.
func play_ambience_fade(amb: AudioStream, fade: float = 1.5, volume: float = 0.0) -> void:
	_crossfade(AMB_PLAYER, amb, fade, volume)

func stop_music(fade: float = 0.0) -> void:
	_crossfade(MUSIC_PLAYER, null, fade, 0.0)

func stop_ambience(fade: float = 0.0) -> void:
	_crossfade(AMB_PLAYER, null, fade, 0.0)

## Change the music / ambience volume without stopping it (e.g. duck it under a moment, then
## bring it back). `volume` in dB (0 = normal, -80 = silent).
func set_music_volume(volume: float, fade: float = 0.5) -> void:
	_fade(MUSIC_PLAYER, volume, fade, false)

func set_ambience_volume(volume: float, fade: float = 0.5) -> void:
	_fade(AMB_PLAYER, volume, fade, false)

func _crossfade(p: AudioStreamPlayer, s: AudioStream, fade: float, volume: float) -> void:
	if s != null and p.stream == s and p.playing:
		_fade(p, volume, fade, false)
		return
	if p.playing and fade > 0.0:
		var t := _fade(p, -80.0, fade * (0.5 if s else 1.0), s == null)
		if s:
			await t.finished
	elif s == null:
		p.stop()
		p.stream = null
	if s == null:
		return
	p.stream = s
	p.volume_db = -80.0 if fade > 0.0 else volume
	p.play()
	if fade > 0.0:
		_fade(p, volume, fade * 0.5, false)

func _fade(p: AudioStreamPlayer, to: float, time: float, stop_after: bool) -> Tween:
	if _tweens.has(p) and _tweens[p].is_valid():
		_tweens[p].kill()
	var t := create_tween()
	_tweens[p] = t
	t.tween_property(p, "volume_db", to, maxf(time, 0.01))
	if stop_after:
		t.tween_callback(func():
			p.stop()
			p.stream = null)
	return t

func _looped(s: AudioStream) -> AudioStream:
	var w := s as AudioStreamWAV
	if w and w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		w = w.duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		return w
	return s

## Web builds (no threads) play audio as "samples": each track is fully decoded the first time
## it plays, which freezes the game for a moment if that happens mid-scene. Call this while the
## screen is still black (scene start) so the decode happens then. Does nothing outside the web.
func prepare(sound: AudioStream) -> void:
	if sound == null or not OS.has_feature("web"):
		return
	if sound.can_be_sampled() and not AudioServer.is_stream_registered_as_sample(sound):
		AudioServer.register_stream_as_sample(sound)
