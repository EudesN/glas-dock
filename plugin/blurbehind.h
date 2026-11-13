// Glasdock — BlurBehind: asks KWin to blur the desktop behind this item's
// area (a rounded rectangle) in its window. Used by the glass surfaces so the
// blur has exactly their shape, which QML alone cannot request.
#pragma once

#include <QPointer>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class BlurBehind : public QQuickItem
{
    Q_OBJECT
    QML_ELEMENT

    // blur on/off
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    // corner radius of the blurred area
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)

public:
    explicit BlurBehind(QQuickItem *parent = nullptr);
    ~BlurBehind() override;

    bool active() const { return m_active; }
    void setActive(bool active);
    qreal radius() const { return m_radius; }
    void setRadius(qreal radius);

Q_SIGNALS:
    void activeChanged();
    void radiusChanged();

protected:
    void itemChange(ItemChange change, const ItemChangeData &data) override;
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

private:
    void setWindow(QQuickWindow *window);
    void checkSceneRect();
    void scheduleApply();
    void apply();
    void clear();

    bool m_active = true;
    qreal m_radius = 0;
    QRectF m_lastRect;
    QPointer<QQuickWindow> m_window;
    QTimer m_applyTimer;     // coalesces changes
    QTimer m_refreshTimer;   // re-applies after Plasma may have reset the region
};
