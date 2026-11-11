import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons as Commons
import "../.."

// The middle column of the lock card (Caelestia modules/lock/Center.qml and
// its center/ components): the split clock, the date, the profile picture,
// the password field and the state message under it. Everything scales off
// the screen height, so a 1080p panel gets Caelestia's smaller layout.
ColumnLayout {
  id: root

  required property var lock

  // Caelestia reads the screen height here; ours comes from the surface,
  // which is zero for the first frame -- and a zero scale is a zero point
  // size, which Qt refuses.
  readonly property real centerScale: Math.min(1, (root.lock.height || 1440) / 1440)
  readonly property var lockLocale: Qt.locale(Commons.I18n.formatLocale)
  readonly property int centerWidth: Tk.sizes.lockCenterWidth * centerScale

  Layout.preferredWidth: centerWidth
  Layout.fillWidth: false
  Layout.fillHeight: true

  spacing: Tk.spacing.largeIncreased

  SystemClock {
    id: sysClock
    precision: SystemClock.Minutes
  }

  // ---------------------------------------------------------- the clock
  // Fedora 42's lock clock: one crisp line, hours and minutes together. The
  // old Caelestia split clock and its stretched axes read as "1304".
  ColumnLayout {
    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: Tk.padding.large
    spacing: 0

    MText {
      Layout.alignment: Qt.AlignHCenter
      text: Sys.hour(sysClock.date) + ":" + Qt.formatTime(sysClock.date, "mm")
      color: Colours.m3onSurface
      font.family: Tk.clock
      font.pointSize: Tk.headline.large * 4 * root.centerScale
      weight: Font.Medium
      axes: ({})
    }

    MText {
      visible: Sys.h12
      Layout.alignment: Qt.AlignHCenter
      Layout.topMargin: -Tk.spacing.small
      text: Qt.formatTime(sysClock.date, "AP")
      color: Colours.m3onSurfaceVariant
      font.pointSize: Tk.headline.small * 0.8 * root.centerScale
      weight: Font.Medium
      axes: ({})
    }
  }

  MText {
    Layout.alignment: Qt.AlignHCenter

    text: sysClock.date.toLocaleDateString(lockLocale, "dddd, d 'de' MMMM").replace(/^./, c => c.toUpperCase())
    color: Colours.m3onSurface
    font.pointSize: Tk.title.medium
    weight: Font.DemiBold
  }

  // ---------------------------------------------------- profile picture
  // Caelestia center/ProfilePic.qml: ~/.face in a clam-shell shape, or a
  // person icon on the same shape when there is no picture.
  Item {
    id: profile

    Layout.alignment: Qt.AlignHCenter
    Layout.topMargin: Tk.spacing.extraExtraLarge * root.centerScale
    Layout.bottomMargin: Tk.spacing.extraLarge * root.centerScale

    implicitWidth: Math.round(root.centerWidth * 0.7)
    implicitHeight: implicitWidth

    MShape {
      id: shape

      anchors.centerIn: parent
      implicitSize: profile.implicitWidth
      shape: "clamShell"
      color: Colours.m3surfaceContainerHighest
    }

    Item {
      anchors.fill: parent
      layer.enabled: true
      layer.effect: ShaderMaskEffect {
        maskItem: shape
      }

      Image {
        id: pfp

        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/.face"
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: Tk.px(512)
        sourceSize.height: Tk.px(512)
        cache: false
      }

      MIcon {
        anchors.centerIn: parent
        visible: pfp.status !== Image.Ready
        text: "person"
        size: root.centerWidth / 4
        color: Colours.m3onSurfaceVariant
      }
    }
  }

  LockPassword {
    Layout.alignment: Qt.AlignHCenter
    centerScale: Math.max(0.8, root.centerScale)
    centerWidth: root.centerWidth
    lock: root.lock
  }

  LockMessage {
    Layout.fillWidth: true
    lock: root.lock
  }
}
