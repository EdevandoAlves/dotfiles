import QtQuick
import QtQuick.Layouts
import "../../.."

// Settings › Audio. Port of Caelestia's nexus pages/AudioPage.qml, backed by
// AudioService (the engine behind Omarchy's own audio panel).
ColumnLayout {
  id: root
  property var row
  property var settings
  property bool first
  property bool last

  spacing: Tk.spacing.extraSmall / 2
  Component.onCompleted: AudioService.users++
  Component.onDestruction: AudioService.users--

  // Output
  AudioSlider {
    first: true
    icon: AudioService.volumeIcon(AudioService.volume, AudioService.muted)
    label: "Saída"
    value: AudioService.volume
    muted: AudioService.muted
    onMoved: v => AudioService.setVolume(v)
  }
  RowToggle {
    Layout.fillWidth: true
    text: "Mudo"
    checked: AudioService.muted
    onToggled: c => AudioService.setMuted(c)
  }
  AudioDeviceList {
    nodes: AudioService.sinks
    current: AudioService.sink
    iconName: "speaker"
    placeholderIcon: "speaker"
    placeholderText: "Nenhum dispositivo de saída"
    onSelected: n => AudioService.setAudioSink(n)
  }

  // Input
  AudioSlider {
    Layout.topMargin: Tk.spacing.large - root.spacing
    first: true
    icon: AudioService.micIcon(AudioService.sourceVolume, AudioService.sourceMuted)
    label: "Entrada"
    value: AudioService.sourceVolume
    muted: AudioService.sourceMuted
    onMoved: v => AudioService.setSourceVolume(v)
  }
  RowToggle {
    Layout.fillWidth: true
    text: "Mudo"
    checked: AudioService.sourceMuted
    onToggled: c => AudioService.setSourceMuted(c)
  }
  AudioDeviceList {
    nodes: AudioService.sources
    current: AudioService.source
    iconName: "mic"
    placeholderIcon: "mic_off"
    placeholderText: "Nenhum dispositivo de entrada"
    onSelected: n => AudioService.setAudioSource(n)
  }

  // Per-app volumes
  RowNav {
    Layout.fillWidth: true
    Layout.topMargin: Tk.spacing.large - root.spacing
    first: true
    last: true
    settings: root.settings
    row: ({
      icon: "tune", label: "Volumes dos apps", page: "appVolumes",
      subtext: AudioService.streams.length === 0 ? "No apps playing audio"
        : AudioService.streams.length + (AudioService.streams.length === 1 ? " app playing audio" : " apps playing audio")
    })
  }
}
