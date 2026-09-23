#include "visualiserbars.hpp"

#include <qbrush.h>
#include <qpainter.h>
#include <qpainterpath.h>
#include <qpen.h>
#include <qrect.h>

#include <algorithm>
#include <cmath>

namespace caelestia::components {

VisualiserBars::VisualiserBars(QQuickItem* parent)
    : QQuickPaintedItem(parent) {
    setAntialiasing(true);
}

void VisualiserBars::advance(qreal dt) {
    if (m_displayValues.isEmpty() || m_settled)
        return;

    // dt is in seconds (from FrameAnimation.frameTime), convert to ms
    const qreal dtMs = dt * 1000.0;
    const qreal tau = m_animationDuration / 3.0;
    const qreal alpha = 1.0 - std::exp(-dtMs / tau);

    bool allSettled = true;

    for (qsizetype i = 0; i < m_displayValues.size(); ++i) {
        const double diff = m_targetValues[i] - m_displayValues[i];

        if (std::abs(diff) > 0.001) {
            m_displayValues[i] += diff * alpha;
            allSettled = false;
        } else {
            m_displayValues[i] = m_targetValues[i];
        }
    }

    update();

    if (allSettled && !m_settled) {
        m_settled = true;
        emit settledChanged();
    }
}

void VisualiserBars::paint(QPainter* painter) {
    if (m_displayValues.isEmpty())
        return;

    painter->setRenderHint(QPainter::Antialiasing, true);
    painter->setPen(Qt::NoPen);

    const qreal w = width();
    const qreal h = height();
    const qreal maxBarHeight = h * 0.4;
    const qreal baseline = m_mirrored ? h / 2.0 : h;

    // Spans the tallest a bar can reach on either side of the baseline. Mirrored, that reaches
    // the same distance below the middle line as above it (maxBarHeight is under half the height,
    // so the reflected spectrum still fits).
    QLinearGradient gradient(0, baseline - maxBarHeight, 0, m_mirrored ? baseline + maxBarHeight : baseline);
    gradient.setColorAt(0, m_primaryColor);
    if (m_mirrored) {
        // Graded towards the middle line, so a reflection of the top half and the bottom half
        // come out identical: primary at each tip, secondary along the middle line
        gradient.setColorAt(0.5, m_secondaryColor);
        gradient.setColorAt(1, m_primaryColor);
    } else {
        gradient.setColorAt(1, m_secondaryColor);
    }
    painter->setBrush(gradient);

    if (m_singleRow) {
        drawGroup(painter, 0, w, false);
    } else {
        // Either side of a centre gap, mirrored against each other
        drawGroup(painter, 0, w * 0.4, true);
        drawGroup(painter, w * 0.6, w * 0.4, false);
    }
}

void VisualiserBars::drawGroup(QPainter* painter, qreal xOffset, qreal groupWidth, bool reverse) {
    const qreal h = height();
    const auto count = m_displayValues.size();

    if (count == 0)
        return;

    const qreal slotWidth = groupWidth / static_cast<qreal>(count);
    const qreal barWidth = slotWidth - m_spacing;

    if (barWidth <= 0)
        return;

    const qreal maxBarHeight = h * 0.4;

    // The line the bars grow from: the bottom edge normally, or the middle of the item when the
    // spectrum is mirrored, which puts a bar half above and half below it
    const qreal baseline = m_mirrored ? h / 2.0 : h;

    for (qsizetype i = 0; i < count; ++i) {
        const qsizetype valueIndex = reverse ? (count - i - 1) : i;
        const qreal value = std::clamp(m_displayValues[valueIndex], 0.0, 1.0);
        const qreal barHeight = value * maxBarHeight;

        if (barHeight <= 0)
            continue;

        const qreal x = static_cast<qreal>(i) * slotWidth + xOffset;
        const qreal r = std::min({ m_rounding, barWidth / 2.0, barHeight });

        QPainterPath path;

        if (m_mirrored) {
            // A pill straddling the baseline: the same bar reflected above and below it, rounded
            // at both tips rather than sitting square on the bottom edge
            path.addRoundedRect(QRectF(x, baseline - barHeight, barWidth, barHeight * 2.0), r, r);
            painter->drawPath(path);
            continue;
        }

        const qreal y = baseline - barHeight;

        path.moveTo(x, baseline);
        path.lineTo(x, y + r);

        if (r > 0) {
            path.arcTo(x, y, r * 2, r * 2, 180, -90);
            path.lineTo(x + barWidth - r, y);
            path.arcTo(x + barWidth - r * 2, y, r * 2, r * 2, 90, -90);
        } else {
            path.lineTo(x, y);
            path.lineTo(x + barWidth, y);
        }

        path.lineTo(x + barWidth, baseline);
        path.closeSubpath();

        painter->drawPath(path);
    }
}

QVector<double> VisualiserBars::values() const {
    return m_targetValues;
}

void VisualiserBars::setValues(const QVector<double>& values) {
    m_targetValues = values;

    if (m_displayValues.size() != values.size()) {
        m_displayValues.resize(values.size(), 0.0);
    }

    if (m_settled) {
        m_settled = false;
        emit settledChanged();
    }

    emit valuesChanged();
}

bool VisualiserBars::settled() const {
    return m_settled;
}

bool VisualiserBars::mirrored() const {
    return m_mirrored;
}

void VisualiserBars::setMirrored(bool mirrored) {
    if (m_mirrored == mirrored)
        return;
    m_mirrored = mirrored;
    emit mirroredChanged();
    update();
}

bool VisualiserBars::singleRow() const {
    return m_singleRow;
}

void VisualiserBars::setSingleRow(bool singleRow) {
    if (m_singleRow == singleRow)
        return;
    m_singleRow = singleRow;
    emit singleRowChanged();
    update();
}

QColor VisualiserBars::primaryColor() const {
    return m_primaryColor;
}

void VisualiserBars::setPrimaryColor(const QColor& color) {
    if (m_primaryColor == color)
        return;
    m_primaryColor = color;
    emit primaryColorChanged();
    update();
}

QColor VisualiserBars::secondaryColor() const {
    return m_secondaryColor;
}

void VisualiserBars::setSecondaryColor(const QColor& color) {
    if (m_secondaryColor == color)
        return;
    m_secondaryColor = color;
    emit secondaryColorChanged();
    update();
}

qreal VisualiserBars::rounding() const {
    return m_rounding;
}

void VisualiserBars::setRounding(qreal rounding) {
    if (qFuzzyCompare(m_rounding, rounding))
        return;
    m_rounding = rounding;
    emit roundingChanged();
    update();
}

qreal VisualiserBars::spacing() const {
    return m_spacing;
}

void VisualiserBars::setSpacing(qreal spacing) {
    if (qFuzzyCompare(m_spacing, spacing))
        return;
    m_spacing = spacing;
    emit spacingChanged();
    update();
}

int VisualiserBars::animationDuration() const {
    return m_animationDuration;
}

void VisualiserBars::setAnimationDuration(int duration) {
    if (m_animationDuration == duration)
        return;
    m_animationDuration = duration;
    emit animationDurationChanged();
}

} // namespace caelestia::components
