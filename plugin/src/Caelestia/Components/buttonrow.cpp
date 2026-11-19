#include "buttonrow.hpp"

namespace caelestia::shell::components {

ButtonRow::ButtonRow(QQuickItem* parent)
    : QQuickItem(parent)
    , m_dirty(false)
    , m_spacing(0.0) {
    setFlag(QQuickItem::ItemHasContents, true);
    QObject::connect(this, &ButtonRow::widthChanged, this, &ButtonRow::invalidate);
}

qreal ButtonRow::spacing() const {
    return m_spacing;
}

void ButtonRow::setSpacing(qreal spacing) {
    if (qFuzzyCompare(m_spacing + 1.0, spacing + 1.0))
        return;

    m_spacing = spacing;
    emit spacingChanged();

    invalidate();
}

void ButtonRow::itemChange(QQuickItem::ItemChange change, const QQuickItem::ItemChangeData& data) {
    if (change == QQuickItem::ItemChildAddedChange) {
        const auto* child = data.item;
        QObject::connect(child, &QQuickItem::implicitWidthChanged, this, &ButtonRow::invalidate);
        QObject::connect(child, &QQuickItem::implicitHeightChanged, this, &ButtonRow::invalidate);
        QObject::connect(child, &QQuickItem::visibleChanged, this, &ButtonRow::invalidate);

        const auto* childMeta = child->metaObject();
        const auto morphSignalIdx = childMeta->indexOfSignal("shapeMorphExpansionChanged()");
        if (morphSignalIdx != -1)
            QObject::connect(child, childMeta->method(morphSignalIdx), this,
                metaObject()->method(metaObject()->indexOfSlot("invalidate()")));

        invalidate();
    } else if (change == QQuickItem::ItemChildRemovedChange) {
        QObject::disconnect(data.item, nullptr, this, nullptr);
        invalidate();
    }

    QQuickItem::itemChange(change, data);
}

void ButtonRow::updatePolish() {
    if (m_dirty) {
        relayout();
        m_dirty = false;
    }
}

void ButtonRow::invalidate() {
    m_dirty = true;
    polish();
}

void ButtonRow::relayout() {
    const auto allChildren = childItems();

    QList<QQuickItem*> validChildren;
    for (auto* const child : allChildren) {
        if (child->isVisible() && !child->inherits("QQuickRepeater"))
            validChildren.append(child);
    }
    const auto nChildren = validChildren.size();
    const auto totalSpacing = static_cast<qreal>(nChildren - 1) * m_spacing;

    qreal reservedWidth = 0;
    qreal unreservedWidth = 0;
    qreal totalWeight = 0;
    qreal maxHeight = 0;
    for (const auto* child : validChildren) {
        maxHeight = qMax(maxHeight, child->implicitHeight());

        const auto prop = child->property("fillWidth");
        if (!prop.isValid())
            continue;

        if (prop.toBool()) {
            totalWeight += fillWeight(child);
            unreservedWidth += child->implicitWidth();
        } else {
            reservedWidth += child->implicitWidth();
        }
    }

    if (totalWeight <= 0)
        totalWeight = 1; // Avoid divide by 0

    const auto widthPerWeight = (width() - totalSpacing - reservedWidth) / totalWeight;

    QList<qreal> baseWidths;
    baseWidths.reserve(nChildren);
    for (const auto* child : validChildren)
        baseWidths.append(
            child->property("fillWidth").toBool() ? widthPerWeight * fillWeight(child) : child->implicitWidth());

    qreal accX = 0;
    for (int i = 0; i < nChildren; ++i) {
        auto* const child = validChildren[i];

        // clang-format off
        auto prevExtraWidth = i > 0             ? getMorphExpansion(validChildren[i - 1]) : 0.0;
        auto nextExtraWidth = i < nChildren - 1 ? getMorphExpansion(validChildren[i + 1]) : 0.0;
        // clang-format on

        // Items at edges push by full amount, items in middle push by half
        if (i > 1)
            prevExtraWidth /= 2;
        if (i < nChildren - 2)
            nextExtraWidth /= 2;

        child->setWidth(baseWidths[i] + getMorphExpansion(child) - prevExtraWidth - nextExtraWidth);
        child->setHeight(maxHeight);

        child->setX(accX);
        child->setY(0);
        accX += child->width() + m_spacing;
    }

    setImplicitWidth(reservedWidth + unreservedWidth + totalSpacing);
    setImplicitHeight(maxHeight);
}

// How many shares of the free width a filling child takes. Children without the property take one
qreal ButtonRow::fillWeight(const QQuickItem* item) {
    const auto prop = item->property("fillWeight");
    if (!prop.isValid())
        return 1.0;
    const auto weight = prop.toReal();
    return weight > 0 ? weight : 1.0;
}

qreal ButtonRow::getMorphExpansion(const QQuickItem* item) {
    return item->property("shapeMorphExpansion").toReal();
}

} // namespace caelestia::shell::components
