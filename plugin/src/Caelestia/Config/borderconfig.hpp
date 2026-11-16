#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::shell::config {

class BorderConfig : public settings::ObjectNode {
    CONFIG_NODE(BorderConfig, settings::ObjectNode)

    CONFIG_PROPERTY(int, thickness, 10)
    // NOTE(fork): the frame's own corners, which want to be the window radius plus the border
    // between them to stay parallel to a rounded window. 30 is WindowSettings' 20 plus this 10;
    // Nexus keeps the two in step when the radius is changed there
    CONFIG_PROPERTY(int, rounding, 30)
    CONFIG_PROPERTY(int, smoothing, 20)

    Q_PROPERTY(int minThickness READ minThickness CONSTANT)
    Q_PROPERTY(int clampedThickness READ clampedThickness NOTIFY thicknessChanged)

public:
    [[nodiscard]] static int minThickness();
    [[nodiscard]] int clampedThickness() const;
};

} // namespace caelestia::shell::config
