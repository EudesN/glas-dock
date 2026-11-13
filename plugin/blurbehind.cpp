#include "blurbehind.h"

#include <KWindowEffects>
#include <QPainterPath>
#include <QRegion>

BlurBehind::BlurBehind(QQuickItem *parent)
    : QQuickItem(parent)
{
    setFlag(ItemHasContents, false);

    m_applyTimer.setSingleShot(true);
    m_applyTimer.setInterval(0);
    connect(&m_applyTimer, &QTimer::timeout, this, &BlurBehind::apply);

    // Plasma re-evaluates its own blur region when a window is shown, resized
    // or its theme changes; re-apply ours shortly after such events.
    m_refreshTimer.setSingleShot(true);
    m_refreshTimer.setInterval(250);
    connect(&m_refreshTimer, &QTimer::timeout, this, &BlurBehind::apply);

    connect(this, &QQuickItem::visibleChanged, this, &BlurBehind::scheduleApply);
}

BlurBehind::~BlurBehind()
{
    clear();
}

void BlurBehind::setActive(bool active)
{
    if (m_active == active)
        return;
    m_active = active;
    Q_EMIT activeChanged();
    scheduleApply();
}

void BlurBehind::setRadius(qreal radius)
{
    if (qFuzzyCompare(m_radius, radius))
        return;
    m_radius = radius;
    Q_EMIT radiusChanged();
    scheduleApply();
}

void BlurBehind::itemChange(ItemChange change, const ItemChangeData &data)
{
    if (change == ItemSceneChange)
        setWindow(data.window);
    QQuickItem::itemChange(change, data);
}

void BlurBehind::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    scheduleApply();
}

void BlurBehind::setWindow(QQuickWindow *window)
{
    if (m_window == window)
        return;
    clear();
    if (m_window)
        disconnect(m_window, nullptr, this, nullptr);
    m_window = window;
    if (!m_window)
        return;
    // the item can move without its own geometry changing (a parent moved), so
    // compare the scene rectangle once per rendered frame
    connect(m_window, &QQuickWindow::afterAnimating, this, &BlurBehind::checkSceneRect);
    connect(m_window, &QWindow::visibleChanged, this, [this] {
        scheduleApply();
        m_refreshTimer.start();
    });
    connect(m_window, &QWindow::widthChanged, this, [this] { m_refreshTimer.start(); });
    connect(m_window, &QWindow::heightChanged, this, [this] { m_refreshTimer.start(); });
    scheduleApply();
    m_refreshTimer.start();
}

void BlurBehind::checkSceneRect()
{
    const QRectF r = mapRectToScene(boundingRect());
    if (r != m_lastRect)
        scheduleApply();
}

void BlurBehind::scheduleApply()
{
    m_applyTimer.start();
}

void BlurBehind::apply()
{
    if (!m_window)
        return;
    const QRectF r = mapRectToScene(boundingRect());
    m_lastRect = r;
    if (!m_active || !isVisible() || r.isEmpty()) {
        KWindowEffects::enableBlurBehind(m_window, false);
        return;
    }
    QPainterPath path;
    const qreal radius = qMin(m_radius, qMin(r.width(), r.height()) / 2.0);
    path.addRoundedRect(r, radius, radius);
    const QRegion region(path.toFillPolygon().toPolygon());
    KWindowEffects::enableBlurBehind(m_window, true, region);
}

void BlurBehind::clear()
{
    if (m_window)
        KWindowEffects::enableBlurBehind(m_window, false);
}
