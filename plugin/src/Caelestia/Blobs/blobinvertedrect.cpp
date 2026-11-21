#include "blobinvertedrect.hpp"

#include "blobgroup.hpp"

namespace caelestia::shell::blobs {

BlobInvertedRect::BlobInvertedRect(QQuickItem* parent)
    : BlobShape(parent) {}

BlobInvertedRect::~BlobInvertedRect() {
    if (m_group)
        m_group->clearInvertedRect(this);
}

qreal BlobInvertedRect::borderLeft() const {
    return m_borderLeft;
}

void BlobInvertedRect::setBorderLeft(qreal v) {
    if (qFuzzyCompare(m_borderLeft, v))
        return;
    m_borderLeft = v;
    emit borderLeftChanged();
    if (m_group)
        m_group->markDirty();
}

qreal BlobInvertedRect::borderRight() const {
    return m_borderRight;
}

void BlobInvertedRect::setBorderRight(qreal v) {
    if (qFuzzyCompare(m_borderRight, v))
        return;
    m_borderRight = v;
    emit borderRightChanged();
    if (m_group)
        m_group->markDirty();
}

qreal BlobInvertedRect::borderTop() const {
    return m_borderTop;
}

void BlobInvertedRect::setBorderTop(qreal v) {
    if (qFuzzyCompare(m_borderTop, v))
        return;
    m_borderTop = v;
    emit borderTopChanged();
    if (m_group)
        m_group->markDirty();
}

qreal BlobInvertedRect::borderBottom() const {
    return m_borderBottom;
}

void BlobInvertedRect::setBorderBottom(qreal v) {
    if (qFuzzyCompare(m_borderBottom, v))
        return;
    m_borderBottom = v;
    emit borderBottomChanged();
    if (m_group)
        m_group->markDirty();
}

bool BlobInvertedRect::isInvertedRect() const {
    return true;
}

void BlobInvertedRect::registerWithGroup() {
    if (m_group)
        m_group->setInvertedRect(this);
}

void BlobInvertedRect::unregisterFromGroup() {
    if (m_group)
        m_group->clearInvertedRect(this);
}

} // namespace caelestia::shell::blobs
