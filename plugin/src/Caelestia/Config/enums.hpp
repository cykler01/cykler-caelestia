#pragma once

#include <qobject.h>
#include <qqmlintegration.h>

namespace caelestia::config {

#define ENUM(Name, ...)                                                                                                \
    namespace Name {                                                                                                   \
                                                                                                                       \
    Q_NAMESPACE                                                                                                        \
    QML_NAMED_ELEMENT(Name)                                                                                            \
                                                                                                                       \
    enum Enum : quint8 {                                                                                               \
        __VA_ARGS__                                                                                                    \
    };                                                                                                                 \
    Q_ENUM_NS(Enum)                                                                                                    \
                                                                                                                       \
    };

ENUM(BarPosition, Left, Right, Top, Bottom)
// Which screen edge a horizontal panel (launcher, dashboard) hangs from, and where along that edge it sits
ENUM(PanelEdge, Top, Bottom)
ENUM(PanelAlign, Start, Center, End)
// Which side edge a panel that opens from the left or right (OSD, session menu, sidebar) comes from
ENUM(PanelSide, Left, Right)
// What resting the pointer in a screen corner opens. A corner can only ever open one thing, so this is
// per corner rather than a set of flags
ENUM(HotCornerAction, None, Overview, Sidebar)
ENUM(BarWorkspaceDisplay, Shapes, Text, Icons)
ENUM(BarWorkspaceCapitalisation, Preserve, Upper, Lower)
ENUM(LyricsBackend, Auto, Local, LRCLIB, NetEase)
ENUM(GpuType, Auto, Nvidia, Generic, None)
ENUM(NotifsFullscreen, On, Off)
ENUM(TemperatureUnit, Auto, Celsius, Fahrenheit, Kelvin)
ENUM(DataUnit, Binary, Decimal)
ENUM(ClockFormat, Auto, TwelveHour, TwentyFourHour)
ENUM(PerfGraphColours, Scheme, Vibrant, Monochrome, Custom)
ENUM(WallpaperTransition,
    // clang-format off
    ChromaticBloom,
    ColourDistance,
    Crossfade,
    Crosshatch,
    Crosswarp,
    Directional,
    DirectionalWipe,
    FadeColour,
    Glitch,
    GlitchDisplace,
    HeatMelt,
    InkSplash,
    InkwellDrop,
    Iris,
    Morph,
    ParametricGlitch,
    Perlin,
    Pixelate,
    PixelfadeWave,
    PlasmaFlow,
    PolkaDotsCurtain,
    PuzzleRight,
    RandomSquares,
    Smoke,
    SoftWarpFade,
    VoronoiShatter,
    ZoomBlurPull,
    // clang-format on
)

#undef ENUM

} // namespace caelestia::config
