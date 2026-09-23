#pragma once

#include <qcolor.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qquickpainteditem.h>
#include <qvector.h>

namespace caelestia::components {

class VisualiserBars : public QQuickPaintedItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVector<double> values READ values WRITE setValues NOTIFY valuesChanged)
    Q_PROPERTY(QColor primaryColor READ primaryColor WRITE setPrimaryColor NOTIFY primaryColorChanged)
    Q_PROPERTY(QColor secondaryColor READ secondaryColor WRITE setSecondaryColor NOTIFY secondaryColorChanged)
    Q_PROPERTY(qreal rounding READ rounding WRITE setRounding NOTIFY roundingChanged)
    Q_PROPERTY(qreal spacing READ spacing WRITE setSpacing NOTIFY spacingChanged)
    Q_PROPERTY(int animationDuration READ animationDuration WRITE setAnimationDuration NOTIFY animationDurationChanged)
    Q_PROPERTY(bool settled READ settled NOTIFY settledChanged)

    // NOTE(fork): off by default, since the background visualiser wants the spectrum rising from
    // the bottom edge of the screen. The notch's now-playing pill sets it: there the bars read
    // much better centred on the middle line and reflected above and below it, the way a Dynamic
    // Island visualiser looks.
    Q_PROPERTY(bool mirrored READ mirrored WRITE setMirrored NOTIFY mirroredChanged)

    // NOTE(fork): the default layout splits the values into two mirrored groups either side of a
    // centre gap, which the background visualiser wants but which reads as a small chart mirrored
    // beside itself in a box as small as the notch's pill. Set, the values are drawn once, as a
    // single spectrum across the whole width.
    Q_PROPERTY(bool singleRow READ singleRow WRITE setSingleRow NOTIFY singleRowChanged)

public:
    explicit VisualiserBars(QQuickItem* parent = nullptr);

    void paint(QPainter* painter) override;

    Q_INVOKABLE void advance(qreal dt);

    [[nodiscard]] QVector<double> values() const;
    void setValues(const QVector<double>& values);

    [[nodiscard]] QColor primaryColor() const;
    void setPrimaryColor(const QColor& color);

    [[nodiscard]] QColor secondaryColor() const;
    void setSecondaryColor(const QColor& color);

    [[nodiscard]] qreal rounding() const;
    void setRounding(qreal rounding);

    [[nodiscard]] qreal spacing() const;
    void setSpacing(qreal spacing);

    [[nodiscard]] int animationDuration() const;
    void setAnimationDuration(int duration);

    [[nodiscard]] bool settled() const;

    [[nodiscard]] bool mirrored() const;
    void setMirrored(bool mirrored);

    [[nodiscard]] bool singleRow() const;
    void setSingleRow(bool singleRow);

signals:
    void valuesChanged();
    void primaryColorChanged();
    void secondaryColorChanged();
    void roundingChanged();
    void spacingChanged();
    void animationDurationChanged();
    void settledChanged();
    void mirroredChanged();
    void singleRowChanged();

private:
    // Draws the whole set of values into one group: the two ends of the bar strip are drawn by two
    // calls, the single line layout by one. Reverse puts the spectrum in the opposite order, which
    // is what mirrors the two groups against each other.
    void drawGroup(QPainter* painter, qreal xOffset, qreal groupWidth, bool reverse);

    QVector<double> m_targetValues;
    QVector<double> m_displayValues;
    QColor m_primaryColor;
    QColor m_secondaryColor;
    qreal m_rounding = 0.0;
    qreal m_spacing = 0.0;
    int m_animationDuration = 200;
    bool m_settled = true;
    bool m_mirrored = false;
    bool m_singleRow = false;
};

} // namespace caelestia::components
