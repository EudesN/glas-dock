#include "blurbehind.h"

#include <KWindowEffects>
#include <QList>
#include <QPainterPath>
#include <QtMath>
#include <utility>

static QList<BlurBehind *> s_instances;

BlurBehind::BlurBehind(QQuickItem *parent) : QQuickItem(parent) {
  s_instances.append(this);
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

BlurBehind::~BlurBehind() {
  s_instances.removeOne(this);
  updateWindow(m_window);
}

void BlurBehind::setActive(bool active) {
  if (m_active == active)
    return;
  m_active = active;
  Q_EMIT activeChanged();
  scheduleApply();
}

void BlurBehind::setRadius(qreal radius) {
  if (qFuzzyCompare(1.0 + m_radius, 1.0 + radius))
    return;
  m_radius = radius;
  Q_EMIT radiusChanged();
  scheduleApply();
}

void BlurBehind::itemChange(ItemChange change, const ItemChangeData &data) {
  if (change == ItemSceneChange)
    setWindow(data.window);
  else if (change == ItemVisibleHasChanged)
    scheduleApply();
  QQuickItem::itemChange(change, data);
}

void BlurBehind::geometryChange(const QRectF &newGeometry,
                                const QRectF &oldGeometry) {
  QQuickItem::geometryChange(newGeometry, oldGeometry);
  scheduleApply();
}

void BlurBehind::setWindow(QQuickWindow *window) {
  if (m_window == window)
    return;
  QQuickWindow *oldWindow = m_window;
  if (m_window)
    disconnect(m_window, nullptr, this, nullptr);
  m_window = window;
  m_region = QRegion();
  m_lastRect = QRectF();
  updateWindow(oldWindow);
  if (!m_window)
    return;
  // the item can move without its own geometry changing (a parent moved), so
  // compare the scene rectangle once per rendered frame
  connect(m_window, &QQuickWindow::afterAnimating, this,
          &BlurBehind::checkSceneRect);
  connect(m_window, &QWindow::visibleChanged, this, [this] {
    scheduleApply();
    m_refreshTimer.start();
  });
  connect(m_window, &QWindow::activeChanged, this,
          [this] { m_refreshTimer.start(); });
  connect(m_window, &QWindow::widthChanged, this,
          [this] { m_refreshTimer.start(); });
  connect(m_window, &QWindow::heightChanged, this,
          [this] { m_refreshTimer.start(); });
  scheduleApply();
  m_refreshTimer.start();
}

void BlurBehind::checkSceneRect() {
  if (!m_active || !isVisible())
    return;
  const QRectF r = mapRectToScene(boundingRect());
  if (r != m_lastRect)
    scheduleApply();
}

void BlurBehind::scheduleApply() { m_applyTimer.start(); }

void BlurBehind::apply() {
  if (!m_window)
    return;
  const QRectF r = mapRectToScene(boundingRect());
  m_lastRect = r;
  if (!m_active || !isVisible() || r.isEmpty()) {
    m_region = QRegion();
    updateWindow(m_window);
    return;
  }
  // Round inward so KWin's un-antialiased blur region never peeks 1 px outside
  // the QML rounded rectangle's antialiased edge.
  const int left = qCeil(r.left() - 0.05);
  const int top = qCeil(r.top() - 0.05);
  const int right = qFloor(r.right() + 0.05);
  const int bottom = qFloor(r.bottom() + 0.05);
  if (right <= left || bottom <= top) {
    m_region = QRegion();
    updateWindow(m_window);
    return;
  }
  const QRectF snapped(left, top, right - left, bottom - top);
  const qreal radius =
      qMin(m_radius, qMin(snapped.width(), snapped.height()) / 2.0);
  if (radius <= 0.5) {
    m_region = QRegion(snapped.toRect());
  } else {
    QPainterPath path;
    const QRectF inner = snapped.adjusted(0.5, 0.5, -0.5, -0.5);
    path.addRoundedRect(inner, qMax(0.0, radius - 0.5),
                        qMax(0.0, radius - 0.5));
    m_region = QRegion(path.toFillPolygon().toPolygon());
  }
  updateWindow(m_window);
}

void BlurBehind::updateWindow(QQuickWindow *window) {
  if (!window)
    return;
  QRegion total;
  for (const BlurBehind *item : std::as_const(s_instances)) {
    if (item->m_window == window && item->m_active && item->isVisible() &&
        !item->m_region.isEmpty())
      total += item->m_region;
  }
  if (total.isEmpty())
    KWindowEffects::enableBlurBehind(window, false);
  else
    KWindowEffects::enableBlurBehind(window, true, total);
}
