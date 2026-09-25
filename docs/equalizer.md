# Equalizer

A ten-band equalizer that equalizes the whole system, not just the shell's own audio, because the
audio path is a PipeWire filter chain rather than something the shell does to its playback.

[▶ Demo](https://cykler.dev/caelestia/demos/equalizer.mp4)

## Opt-in, and off by default

The equalizer is **off until you switch it on**, either with the *System-wide equalizer* switch under
*Settings → Audio* or by setting `services.equalizer` in `shell.json`. While it is off the shell does
not run `pw-cli` and never touches the default output, so a plain update cannot change anyone's audio.

With it off, the equalizer button does not appear in the media tab's drawer at all, so the feature is
only visible to people who asked for it.

## One-off setup

The filter chain has to be loaded by PipeWire at startup, so it cannot be set up from the shell alone:

```sh
mkdir -p ~/.config/pipewire/pipewire.conf.d
cp assets/pipewire/caelestia-eq.conf ~/.config/pipewire/pipewire.conf.d/
systemctl --user restart pipewire pipewire-pulse wireplumber
```

Until that is done - and while PipeWire has not finished loading the chain after a restart - the panel
says the sink is missing rather than pretending to work.

## How it behaves

- The chain is a virtual sink with ten peaking bands at 31, 62, 125, 250, 500 Hz, 1, 2, 4, 8 and
  16 kHz, up to 12 dB of gain either way.
- Moving a slider writes that band straight into the running node, so a tweak is audible immediately.
- Presets: flat, rock, pop, jazz, classical, electronic, hip hop, bass boost, vocal and loudness.
  Moving a band by hand switches the preset to *custom*.
- The curve and preset are remembered between sessions in
  `~/.local/state/caelestia/equalizer.json`.

Everything only passes through the filter chain while that sink is the default output, so switching
the equalizer on points the default output at it and switching it off puts the device that was there
before back. That is what makes it system-wide: streams that are already playing, browser audio
included, move across with it, and the chain's own output stays wired to the real device.

Routing goes through the same preference the audio settings page uses, so the two cannot fight over
the default sink, and it only runs when the switch changes - never on a timer - so a device you picked
in the audio settings stays picked.

## Notes

- The chain's own two nodes (`caelestia_eq.sink` and `caelestia_eq.out`) are plumbing rather than
  output devices, so neither is ever offered in the audio settings or left holding the default.
- If the equalizer is switched off and something else already holds the default output, it is left
  alone. It is only handed back when the chain is still holding it, and then to the device that was
  there before if it is still connected, otherwise to the first real output found.
