import QtQuick
import QtQuick.Layouts
import qs.Commons as Commons
import "../../.."

// Caelestia bar/components/Clock.qml (and Caelestia KDE's row form). The
// SystemClock lives in BarContent (bar.sysClock), shared by every screen's entry.
Rectangle {
  id: entry
  required property var bar
  Component.onCompleted: bar.registerEntry(entry)
  Component.onDestruction: bar.unregisterEntry(entry)
  property string entryId: "clock"
  readonly property bool shown: bar.cfg.clock.enabled
  visible: shown
  // The calendar icon's length along the bar, worked out whether or not it
  // is shown, so hiding it can't bring it straight back (see BarContent's budget).
  readonly property real calendarLen: bar.cfg.clock.enabled && bar.cfg.clock.showIcon ? (bar.vertical ? calIcon.implicitHeight + clockCol.spacing : calIconH.implicitWidth + clockRow.spacing) : 0
  Layout.alignment: bar.crossAlign
  readonly property real pad: bar.cfg.clock.background ? Tk.padding.medium : Tk.padding.extraSmall
  implicitWidth: bar.vertical ? Tk.barInner : clockRow.implicitWidth + pad * 2
  implicitHeight: bar.vertical ? clockCol.implicitHeight + pad * 2 : Tk.barInner
  radius: (bar.vertical ? width : height) / 2
  color: bar.cfg.clock.background ? Colours.m3surfaceContainer : "transparent"
  readonly property bool h12: Sys.h12
  // Qt.locale() follows the locale the shell started with (English here);
  // Omarchy keeps the chosen display locale in I18n.
  readonly property var clockLocale: Qt.locale(Commons.I18n.formatLocale)
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: e => {
      if (e.button === Qt.RightButton) bar.host.toggle("sidebar")
      else bar.host.toggle("dashboard")
    }
  }
  // Fedora 42's top-bar clock, in Omacale's type: the date in the muted text
  // colour, then the time in the main text colour. No rounded/expanded axes
  // and no width stretching, so the digits stay crisp and stable as they
  // count. Caelestia's calendar glyph is still there, but off by default.
  RowLayout {
    id: clockRow
    anchors.centerIn: parent
    visible: !bar.vertical
    spacing: Tk.spacing.small
    MIcon {
      id: calIconH
      visible: bar.calIconShown
      Layout.alignment: Qt.AlignVCenter
      text: "calendar_month"
      color: Colours.m3onSurfaceVariant
    }
    MText {
      visible: bar.cfg.clock.showDate
      Layout.alignment: Qt.AlignVCenter
      text: bar.sysClock.date.toLocaleDateString(clockLocale, "ddd, d MMM").replace(/\./g, "")
      font.pointSize: Tk.body.small
      color: Colours.m3onSurfaceVariant
      axes: ({})
    }
    MText {
      Layout.alignment: Qt.AlignVCenter
      text: Sys.hour(bar.sysClock.date) + ":" + Qt.formatTime(bar.sysClock.date, "mm")
        + (bar.cfg.clock.showSeconds ? ":" + Qt.formatTime(bar.sysClock.date, "ss") : "")
      font.pointSize: Tk.body.small * 1.1
      weight: Font.Medium
      color: Colours.m3onSurface
      axes: ({})
    }
    MText {
      visible: entry.h12
      Layout.alignment: Qt.AlignVCenter
      text: Qt.formatTime(bar.sysClock.date, "AP").toLowerCase()
      font.pointSize: Tk.body.small * 0.9
      color: Colours.m3onSurfaceVariant
      axes: ({})
    }
  }

  // A column has no room for the date and the time side by side: the date
  // sits above the clock, stacked hours over minutes as before, but plain.
  ColumnLayout {
    id: clockCol
    anchors.centerIn: parent
    visible: bar.vertical
    spacing: Tk.spacing.extraSmall
    readonly property real size: Tk.body.small * 1.15
    MIcon {
      id: calIcon
      visible: bar.calIconShown
      Layout.alignment: Qt.AlignHCenter
      text: "calendar_month"
      color: Colours.m3onSurfaceVariant
    }
    ColumnLayout {
      visible: bar.cfg.clock.showDate
      Layout.alignment: Qt.AlignHCenter
      spacing: -Tk.px(1)
      MText {
        Layout.alignment: Qt.AlignHCenter
        text: bar.sysClock.date.toLocaleDateString(clockLocale, "ddd").replace(/\./g, "").toUpperCase()
        font.pointSize: Tk.label.small * 0.85
        font.letterSpacing: 0.6
        color: Colours.m3onSurfaceVariant
        axes: ({})
      }
      MText {
        Layout.alignment: Qt.AlignHCenter
        text: bar.sysClock.date.toLocaleDateString(clockLocale, "dd MMM").replace(/\./g, "").toUpperCase()
        font.pointSize: Tk.label.small * 0.95
        font.letterSpacing: 0.3
        weight: Font.Medium
        color: Colours.m3onSurfaceVariant
        axes: ({})
      }
    }
    MText {
      Layout.alignment: Qt.AlignHCenter
      text: Sys.hour(bar.sysClock.date)
      font.family: Tk.clock
      font.pointSize: clockCol.size
      weight: Font.Medium
      color: Colours.m3onSurface
      axes: ({})
    }
    MText {
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: -clockCol.spacing - Tk.px(2)
      text: Qt.formatTime(bar.sysClock.date, "mm")
      font.family: Tk.clock
      font.pointSize: clockCol.size
      weight: Font.Medium
      color: Colours.m3onSurface
      axes: ({})
    }
    MText {
      visible: bar.cfg.clock.showSeconds
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: -clockCol.spacing - Tk.px(2)
      text: Qt.formatTime(bar.sysClock.date, "ss")
      font.family: Tk.clock
      font.pointSize: clockCol.size * 0.75
      color: Colours.m3onSurfaceVariant
      axes: ({})
    }
    MText {
      visible: parent.parent.h12
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: -clockCol.spacing - Tk.px(2)
      text: Qt.formatTime(bar.sysClock.date, "AP").toLowerCase()
      font.pointSize: Tk.body.small * 0.85
      color: Colours.m3onSurfaceVariant
      axes: ({})
    }
  }

  function navStops() {
    return [{ item: entry, act: () => bar.leaveFor("dashboard") }]
  }
}
