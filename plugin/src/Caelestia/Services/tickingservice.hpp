#pragma once

#include <qtimer.h>

#include "service.hpp"

namespace caelestia::shell::services {

class TickingService : public Service {
    Q_OBJECT

    Q_PROPERTY(int updateInterval READ updateInterval NOTIFY updateIntervalChanged)
    // NOTE(fork): multiplies the polling period (1 = normal); the shell raises it on battery
    Q_PROPERTY(int slowdown READ slowdown WRITE setSlowdown NOTIFY slowdownChanged)

public:
    explicit TickingService(QObject* parent = nullptr);

    [[nodiscard]] int updateInterval() const;
    [[nodiscard]] int slowdown() const;
    void setSlowdown(int factor);

signals:
    void updateIntervalChanged();
    void slowdownChanged();

protected:
    virtual void tick() = 0;

private:
    void start() final;
    void stop() final;

    void applyInterval(int ms);

    QTimer* m_timer;
    int m_interval = 1000;
    int m_slowdown = 1;
    bool m_running = false;
};

} // namespace caelestia::shell::services
