import QtQuick
import qs.Ui
import qs.Commons
import qs.Commons as Commons

// Local copy of qs.Ui/PanelSlider with two additions:
//   * a second fill colour for the part of the value above `boostFrom`
//   * a notch marking that boundary
// Everything else (moved/released/rightClicked, dragging, wheel, ticks) mirrors
// the stock slider so the audio panel behaves identically apart from the boost
// colouring.
Item {
  id: root

  property QtObject bar: null
  property real value: 0
  property real minimum: 0
  property real maximum: 1
  property real step: 0.05
  property bool integer: false
  property color trackColor: bar ? Style.selectedFillFor(bar.foreground, Commons.Color.accent) : "#333"
  property color fillColor: bar ? bar.foreground : Commons.Color.foreground
  property color knobColor: bar ? bar.foreground : Commons.Color.foreground
  property bool dragging: false
  property real trackHeight: Math.max(4, Math.round(Style.spacing.controlHeight * 0.11))
  property real knobSize: Math.max(14, Math.round(Style.spacing.controlHeight * 0.38))
  property real liveValue: value

  // Boost rendering. `boostFrom` is in the same units as `value`.
  property real boostFrom: 1
  property color boostColor: bar ? bar.urgent : Commons.Color.urgent
  property color notchColor: bar ? bar.background : Commons.Color.background

  property int tickCount: 0
  property color tickColor: bar ? bar.background : Commons.Color.background

  readonly property real _boostStart: Math.max(minimum, Math.min(maximum, boostFrom))
  readonly property real _baseValue: Math.min(liveValue, _boostStart)
  readonly property real _boostValue: Math.max(0, liveValue - _boostStart)

  onValueChanged: if (!dragging) liveValue = value

  signal moved(real value)
  signal released(real value)
  signal rightClicked()

  implicitWidth: Style.space(200)
  implicitHeight: Math.max(Style.space(22), knobSize + Style.spacing.md)

  readonly property real range: Math.max(0.0001, maximum - minimum)
  readonly property real progress: Math.max(0, Math.min(1, (liveValue - minimum) / range))
  readonly property bool _hot: mouseArea.containsMouse || root.dragging

  Rectangle {
    id: track
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.trackHeight
    radius: height / 2
    color: root.trackColor
  }

  Rectangle {
    id: fill
    anchors.verticalCenter: track.verticalCenter
    anchors.left: track.left
    height: track.height
    radius: track.radius
    color: root.fillColor
    width: track.width * Math.max(0, Math.min(1, (root._baseValue - root.minimum) / root.range))

    Behavior on width {
      enabled: !root.dragging
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
  }

  Rectangle {
    id: boostFill
    visible: root._boostValue > 0.0001
    anchors.verticalCenter: track.verticalCenter
    height: track.height
    radius: track.radius
    color: root.boostColor
    x: track.width * Math.max(0, Math.min(1, (root._boostStart - root.minimum) / root.range))
    width: track.width * Math.max(0, Math.min(1, root._boostValue / root.range))

    Behavior on width {
      enabled: !root.dragging
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
  }

  // Boundary marker: only meaningful when the boost segment can exist.
  Rectangle {
    visible: root._boostStart > root.minimum && root._boostStart < root.maximum
    width: Math.max(1, Style.space(2))
    height: root.trackHeight + Style.space(4)
    radius: 1
    color: root.notchColor
    anchors.verticalCenter: track.verticalCenter
    x: Math.max(0, Math.min(track.width - width,
                            track.width * ((root._boostStart - root.minimum) / root.range) - width / 2))
  }

  Repeater {
    model: root.tickCount > 1 ? root.tickCount : 0
    Rectangle {
      required property int index
      width: Math.max(1, Style.space(2))
      height: root.trackHeight + Style.space(4)
      radius: 1
      color: root.tickColor
      anchors.verticalCenter: track.verticalCenter
      x: Math.max(0, Math.min(track.width - width,
                              track.width * (index / (root.tickCount - 1)) - width / 2))
    }
  }

  Rectangle {
    id: knob
    width: root.knobSize
    height: root.knobSize
    radius: root.knobSize / 2
    color: root.knobColor
    border.width: Math.max(1, Style.space(2))
    border.color: root.bar ? root.bar.background : "#101315"
    anchors.verticalCenter: track.verticalCenter
    x: Math.max(0, Math.min(track.width - width, track.width * root.progress - width / 2))
    scale: root._hot ? 1.15 : 1.0

    Behavior on x {
      enabled: !root.dragging
      NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    Behavior on scale {
      NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    function valueFromX(x) {
      var clamped = Math.max(0, Math.min(track.width, x))
      var raw = root.minimum + (clamped / track.width) * root.range
      if (root.integer) raw = Math.round(raw)
      return Math.max(root.minimum, Math.min(root.maximum, raw))
    }

    onPressed: function(mouse) {
      if (mouse.button !== Qt.LeftButton) return
      root.dragging = true
      var next = valueFromX(mouse.x)
      root.liveValue = next
      root.moved(next)
    }
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.rightClicked()
    }
    onPositionChanged: function(mouse) {
      if (!root.dragging) return
      var next = valueFromX(mouse.x)
      root.liveValue = next
      root.moved(next)
    }
    onReleased: function(mouse) {
      if (mouse.button !== Qt.LeftButton) return
      root.dragging = false
      root.released(root.liveValue)
      root.liveValue = root.value
    }
    onWheel: function(wheel) {
      var delta = wheel.angleDelta.y > 0 ? root.step : -root.step
      var next = Math.max(root.minimum, Math.min(root.maximum, root.liveValue + delta))
      if (root.integer) next = Math.round(next)
      root.liveValue = next
      root.moved(next)
      root.released(next)
    }
  }
}
