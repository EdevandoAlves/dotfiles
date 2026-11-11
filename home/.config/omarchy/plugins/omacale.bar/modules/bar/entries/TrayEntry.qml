import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../../.."

// Caelestia bar/components/Tray.qml: compact collapses the tray behind a
// chevron that hovering expands (Caelestia's Bar.checkPopout), and
// hiddenIcons drops items for good. Compact is also switched on by the
// shared space budget (BarContent's "space budget") when the tray doesn't fit.
Rectangle {
  id: entry
  required property var bar
  Component.onCompleted: bar.registerEntry(entry)
  Component.onDestruction: bar.unregisterEntry(entry)
  property string entryId: "tray"
  readonly property bool shown: bar.cfg.tray.enabled && trayItems.length > 0
  property alias flick: trayFlick
  Layout.alignment: bar.crossAlign
  readonly property var trayItems: SystemTray.items.values.filter(i => i.status !== Status.Passive
    && bar.cfg.tray.hiddenIcons.indexOf(i.id) < 0)
  // Next to status icons or widgets the tray joins their pill (BarContent's
  // Section.runs): drawn as with a background of its own, but transparent.
  readonly property bool joinable: true
  property bool joinBefore: false
  property bool joinAfter: false
  readonly property bool joined: joinBefore || joinAfter
  readonly property bool bg: bar.cfg.tray.background || joined
  // Where the tray joins a neighbour the run's backdrop is the pill, so that
  // side drops its own padding (as StatusRun/PluginsEntry/PowerEntry do).
  readonly property int padSide: bg ? Tk.padding.medium : Tk.padding.extraSmall
  property real padStart: joinBefore ? 0 : padSide
  property real padEnd: joinAfter ? 0 : padSide
  Behavior on padStart { Anim {} }
  Behavior on padEnd { Anim {} }
  readonly property int spacingN: bg ? Tk.spacing.medium : Tk.spacing.extraSmall
  visible: shown

  readonly property bool compact: bar.cfg.tray.compact || bar.trayOverBudget
  property bool expanded: false
  onCompactChanged: if (!compact) expanded = false

  // Caelestia has no cascade: the tray is a plain list. Here the icons are
  // stacked as a deck of cards -- each one a step further along the bar and
  // partly over the one before it -- and fan out to their full spacing while
  // the pointer is on the tray. The topmost (last) icon stays whole, so the
  // tray still reads as one control until you reach for it.
  readonly property bool cascading: bar.cfg.tray.cascade && !compact && trayItems.length > 1
  property bool cascadeOpen: false
  readonly property real iconSize: Tk.body.small * 2
  // Half an icon of overlap collapsed; the normal gap fanned out.
  readonly property real cascadeStep: cascading && !cascadeOpen ? Math.round(iconSize * 0.45)
    : iconSize + Tk.spacing.small
  readonly property real cascadeLen: trayItems.length > 0
    ? iconSize + (trayItems.length - 1) * cascadeStep : 0
  onCascadingChanged: if (!cascading) cascadeOpen = false
  Timer {
    id: cascadeCollapse
    interval: 220
    onTriggered: entry.cascadeOpen = false
  }
  HoverHandler {
    onHoveredChanged: {
      if (!entry.cascading) return
      if (hovered) { cascadeCollapse.stop(); entry.cascadeOpen = true }
      else cascadeCollapse.start()
    }
  }

  // The size along the bar. Caelestia's nonAnimHeight, with the expanded
  // list capped to the budget.
  // Caelestia's expandIcon item is the glyph less padding.small, the glyph
  // hanging past it at the far end.
  readonly property real chevronLen: (bar.vertical ? expandTrayIcon.implicitHeight : expandTrayIcon.implicitWidth) - Tk.padding.small
  // The settled deck length, not trayCol's animated height: feeding the
  // animated value back here made the entry's own height wait for it, so the
  // clip only caught up after two 500 ms animations (~1 s).
  readonly property real listLen: entry.cascadeLen
  readonly property real fullLen: listLen + padStart + padEnd
  readonly property real collapsedLen: Math.max(bg ? Tk.barInner : 0, chevronLen + (bg ? Tk.padding.extraSmall : 0) + padStart)
  readonly property real sizeLen: {
    if (!visible) return 0
    if (!compact) return fullLen
    if (!expanded) return collapsedLen
    return Math.max(collapsedLen, Math.min(chevronLen + listLen + spacingN + (bg ? Tk.padding.extraSmall : 0) + padStart,
      bar.budget - bar.pluginLen))
  }
  implicitWidth: bar.vertical ? Tk.barInner : sizeLen
  implicitHeight: bar.vertical ? sizeLen : Tk.barInner
  radius: Tk.rounding.full
  color: bg && !joined ? Colours.m3surfaceContainer : "transparent"
  clip: true
  Behavior on implicitHeight { enabled: bar.vertical; Anim {} }
  Behavior on implicitWidth { enabled: !bar.vertical; Anim {} }

  // The tray menu keeps it open; closing the menu lets it fold again.
  Connections {
    target: bar.scope
    function onPopoutChanged() { if (bar.scope.popout === "") collapseTrayTimer.restart() }
  }
  Timer {
    id: collapseTrayTimer
    interval: 400
    onTriggered: if (bar.scope.popout !== "traymenu") entry.expanded = false
  }

  // Scrolls when an expanded tray is capped by the budget.
  MFlickable {
    id: trayFlick
    x: bar.vertical ? 0 : entry.padStart
    y: bar.vertical ? entry.padStart : 0
    // What is left along the bar once the padding and the chevron have theirs.
    readonly property real room: Math.max(0, (bar.vertical ? parent.height : parent.width) - entry.padStart
      - (entry.compact ? entry.chevronLen + entry.spacingN : entry.padEnd))
    width: bar.vertical ? parent.width : room
    height: bar.vertical ? room : parent.height
    contentWidth: bar.vertical ? width : trayCol.implicitWidth
    contentHeight: bar.vertical ? trayCol.implicitHeight : height
    interactive: bar.vertical ? contentHeight > height + 0.5 : contentWidth > width + 0.5
    clip: true

    // The deck: one item per tray icon, placed by hand so a cascade can
    // overlap them. Later icons paint over earlier ones, so the last one is
    // the whole card on top until the deck fans out.
    Item {
      id: trayCol
      readonly property int count: entry.trayItems.length
      // Centred across the bar.
      x: bar.vertical ? Math.round((parent.width - width) / 2) : 0
      y: bar.vertical ? 0 : Math.round((parent.height - height) / 2)
      implicitWidth: bar.vertical ? 0 : width
      implicitHeight: bar.vertical ? height : 0
      width: bar.vertical ? parent.width : entry.cascadeLen
      height: bar.vertical ? entry.cascadeLen : parent.height
      opacity: !entry.compact || entry.expanded ? 1 : 0
      Behavior on opacity { Anim { type: "effects" } }

      Repeater {
        id: trayRep
        model: entry.trayItems
        MouseArea {
          required property var modelData
          required property int index
          readonly property real step: entry.cascadeStep
          implicitWidth: entry.iconSize
          implicitHeight: entry.iconSize
          // Along the bar each icon starts one step after the last; across
          // it, they stay centred. A step shorter than the icon is the
          // overlap that makes the staircase.
          x: bar.vertical ? Math.round((trayCol.width - width) / 2) : index * step
          y: bar.vertical ? index * step : Math.round((trayCol.height - height) / 2)
          z: index
          Behavior on x { enabled: !bar.vertical; Anim {} }
          Behavior on y { enabled: bar.vertical; Anim {} }
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: Qt.PointingHandCursor
          onClicked: function(e) { if (e.button === Qt.LeftButton) modelData.activate(); else modelData.secondaryActivate() }
          // A card under each icon while the deck is stacked: without it two
          // busy, transparent app icons merge into one another.
          Rectangle {
            anchors.fill: parent
            visible: entry.cascading
            radius: width / 2
            color: Colours.m3surfaceContainerHigh
            border.width: 1
            border.color: Qt.alpha(Colours.m3onSurface, 0.10)
          }
          ColouredIcon {
            anchors.fill: parent
            anchors.margins: entry.cascading ? Tk.px(2) : 0
            visible: bar.cfg.tray.recolour
            colour: Colours.m3secondary
            source: trayImg.source
          }
          Image {
            id: trayImg
            anchors.fill: parent
            anchors.margins: entry.cascading ? Tk.px(2) : 0
            visible: !bar.cfg.tray.recolour
            source: {
              let icon = parent.modelData.icon
              if (icon.indexOf("?path=") >= 0) {
                const [name, path] = icon.split("?path=")
                const file = name.slice(name.lastIndexOf("/") + 1)
                const themed = Quickshell.iconPath(file, true)
                icon = themed ? themed : "file://" + path + "/" + file
              }
              return icon
            }
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            smooth: true
            mipmap: true
          }
          scale: 0
          Component.onCompleted: scale = 1
          Behavior on scale { Anim { easing.bezierCurve: Tk.curves.standardDecel } }
        }
      }
    }
  }

  // Caelestia's expandIcon: one glyph, turned 180° when expanded.
  MIcon {
    id: expandTrayIcon
    visible: entry.compact
    // At the far end of the pill, centred across it.
    x: bar.vertical ? Math.round((parent.width - width) / 2) : parent.width - width + (entry.bg ? -Tk.padding.extraSmall : Tk.padding.small)
    y: bar.vertical ? parent.height - height + (entry.bg ? -Tk.padding.extraSmall : Tk.padding.small) : Math.round((parent.height - height) / 2)
    text: bar.vertical ? "expand_less" : "chevron_left"
    size: Tk.iconSize.medium
    color: Colours.m3onSurfaceVariant
    rotation: entry.expanded ? 180 : 0
    Behavior on rotation { Anim {} }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: { collapseTrayTimer.stop(); entry.expanded = !entry.expanded }
    }
  }

  function navStops() {
    const out = []
    if (!visible) return out
    for (let i = 0; i < trayRep.count; i++) {
      const it = trayRep.itemAt(i)
      if (it) out.push({ item: it, kind: "tray", tray: it.modelData, act: () => it.modelData.activate() })
    }
    return out
  }
  function popoutAt(a) {
    const t = bar.pointAlong(bar.pointOn(trayCol, a))
    if (bar.cfg.popouts.tray && visible && (!compact || expanded) && t >= 0 && t <= bar.alen(trayCol)) {
      for (let i = 0; i < trayRep.count; i++) {
        const it = trayRep.itemAt(i)
        if (t >= bar.apos(it) - 4 && t <= bar.apos(it) + bar.alen(it) + 4)
          return { name: "traymenu", index: i, item: it.modelData, center: bar.centreOf(it) }
      }
    }
    return null
  }
  function popoutCenterFor(name) {
    const s = bar.cursorStop
    return name === "traymenu" && s && s.kind === "tray" ? bar.centreOf(s.item) : undefined
  }
  function hoverAt(a, onBar) {
    const t = bar.pointAlong(bar.pointOn(entry, a))
    if (onBar && visible && t >= 0 && t <= bar.alen(entry)) {
      collapseTrayTimer.stop()
      if (compact) expanded = true
    } else if (expanded && !collapseTrayTimer.running) collapseTrayTimer.start()
  }
  function scrollAt(a, dy) { return visible && bar.scrollList(trayFlick, a, dy) }
  // The compact tray opens while the bar focus cursor is in it.
  function cursorMoved(s) {
    if (!!s && s.kind === "tray") { collapseTrayTimer.stop(); if (compact) expanded = true }
    else if (expanded) collapseTrayTimer.restart()
  }
}
