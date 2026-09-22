# Caelestia EQ — a system-wide equalizer.
#
# One-time install:
#   mkdir -p ~/.config/pipewire/pipewire.conf.d
#   cp assets/pipewire/caelestia-eq.conf ~/.config/pipewire/pipewire.conf.d/
#   systemctl --user restart pipewire pipewire-pulse wireplumber
#
# This creates a virtual sink, "Caelestia EQ", that audio plays into: ten peaking biquads filter
# it and the result is passed on to the real output device. The playback side is passive, so it
# follows whatever output device is current. The sink is not made the default here: the shell
# points the default sink at it while the equalizer is switched on, and puts the previous device
# back when it is switched off, so the filter only sits in the path when you want it.
#
# The dashboard's equalizer panel drives the bands of the running node with
#   pw-cli set-param <node-id> Props '{ params = [ "b0:Gain" 6.0 ... ] }'
# so the node names here have to stay in sync with services/Equalizer.qml (see sinkName there).
#
# After editing this file the audio daemon has to be restarted for it to take effect:
#   systemctl --user restart pipewire pipewire-pulse wireplumber
context.modules = [
    { name = libpipewire-module-filter-chain
        args = {
            node.description = "Caelestia EQ"
            media.name = "Caelestia EQ"
            filter.graph = {
                nodes = [
                    { type = builtin label = bq_peaking name = b0 control = { "Freq" = 31 "Q" = 1.4 "Gain" = 0.0 } }
                    { type = builtin label = bq_peaking name = b1 control = { "Freq" = 62 "Q" = 1.4 "Gain" = 0.0 } }
                    { type = builtin label = bq_peaking name = b2 control = { "Freq" = 125 "Q" = 1.4 "Gain" = 0.0 } }
                    { type = builtin label = bq_peaking name = b3 control = { "Freq" = 250 "Q" = 1.4 "Gain" = 0.0 } }
                    { type = builtin label = bq_peaking name = b4 control = { "Freq" = 500 "Q" = 1.4 "Gain" = 0.0 } }
                    { type = builtin label = bq_peaking name = b5 control = { "Freq" = 1000 "Q" = 1.4 "Gain" = 0.0 } }
                    { type = builtin label = bq_peaking name = b6 control = { "Freq" = 2000 "Q" = 1.4 "Gain" = 0.0 } }
                    { type = builtin label = bq_peaking name = b7 control = { "Freq" = 4000 "Q" = 1.4 "Gain" = 0.0 } }
                    { type = builtin label = bq_peaking name = b8 control = { "Freq" = 8000 "Q" = 1.4 "Gain" = 0.0 } }
                    { type = builtin label = bq_peaking name = b9 control = { "Freq" = 16000 "Q" = 1.4 "Gain" = 0.0 } }
                ]
                # Every band has to be chained explicitly. Without these links the ten filters are
                # all dangling, so nothing reaches the last node's output and the sink plays
                # silence. (This is also how the equalizer example PipeWire ships, sink-eq6.conf,
                # is written.) The graph's input and output are found from the only two ports left
                # unconnected here, b0:In and b9:Out.
                links = [
                    { output = "b0:Out" input = "b1:In" }
                    { output = "b1:Out" input = "b2:In" }
                    { output = "b2:Out" input = "b3:In" }
                    { output = "b3:Out" input = "b4:In" }
                    { output = "b4:Out" input = "b5:In" }
                    { output = "b5:Out" input = "b6:In" }
                    { output = "b6:Out" input = "b7:In" }
                    { output = "b7:Out" input = "b8:In" }
                    { output = "b8:Out" input = "b9:In" }
                ]
            }
            # Stereo in and out, which is what makes the filter chain duplicate the ten bands per
            # channel. Without these the graph is a single mono chain and everything is downmixed.
            capture.props = {
                node.name = "caelestia_eq.sink"
                node.description = "Caelestia EQ"
                media.class = Audio/Sink
                audio.channels = 2
                audio.position = [ FL FR ]
            }
            playback.props = {
                node.name = "caelestia_eq.out"
                node.passive = true
                audio.channels = 2
                audio.position = [ FL FR ]
            }
        }
    }
]
