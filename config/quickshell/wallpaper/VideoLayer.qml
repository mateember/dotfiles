import QtQuick
import QtMultimedia

// Native QtMultimedia playback layer for full-framerate video (.mp4, .webm, .mkv, .mov, .m4v, .avi)
// and APNG (.apng / animated .png) wallpapers.
// Isolated in its own file and loaded dynamically via Qt.createComponent() in Wallpapers.qml
// so the shell degrades cleanly to ffmpeg GIF fallback when QtMultimedia is unavailable.
Item {
    id: root

    property string sourceUrl: ""
    property string fitMode: "crop"   // "crop" | "fit" | "stretch" | "center"
    property bool paused: false
    property real playbackRate: 1.0
    property bool ready: false

    // Internal flag used to decode and display frame 1 when initially loaded while paused.
    property bool primingFrame: false

    signal mediaReady()
    signal mediaError(string message)

    function applyPlaybackState(): void {
        if (!root.sourceUrl) {
            player.stop();
            return;
        }
        if (root.paused) {
            if (!root.ready) {
                root.primingFrame = true;
                player.play();
                primeFallbackTimer.restart();
            } else {
                root.primingFrame = false;
                player.pause();
            }
        } else {
            root.primingFrame = false;
            primeFallbackTimer.stop();
            player.play();
        }
    }

    onSourceUrlChanged: {
        root.ready = false;
        root.primingFrame = false;
        primeFallbackTimer.stop();
        if (!sourceUrl) {
            player.stop();
            player.source = "";
        } else {
            player.source = sourceUrl;
            applyPlaybackState();
        }
    }

    onPausedChanged: applyPlaybackState()

    Component.onCompleted: {
        if (root.sourceUrl) {
            player.source = root.sourceUrl;
            applyPlaybackState();
        }
    }

    Component.onDestruction: {
        primeFallbackTimer.stop();
        player.stop();
        player.source = "";
    }

    Timer {
        id: primeFallbackTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (root.primingFrame && root.paused) {
                root.primingFrame = false;
                root.ready = true;
                player.pause();
            }
        }
    }

    VideoOutput {
        id: videoOut
        anchors.fill: parent
        endOfStreamPolicy: VideoOutput.KeepLastFrame
        fillMode: {
            if (root.fitMode === "fit" || root.fitMode === "center")
                return VideoOutput.PreserveAspectFit;
            if (root.fitMode === "stretch")
                return VideoOutput.Stretch;
            return VideoOutput.PreserveAspectCrop;
        }
    }

    // No audioOutput attached: desktop wallpapers never open PipeWire audio streams.
    MediaPlayer {
        id: player
        videoOutput: videoOut
        loops: MediaPlayer.Infinite
        playbackRate: Math.max(0.25, Math.min(2.0, root.playbackRate))

        onHasVideoChanged: {
            if (hasVideo && !root.ready && root.sourceUrl) {
                root.ready = true;
                root.mediaReady();
            }
        }

        onMediaStatusChanged: {
            if ((mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia)
                    && !root.ready && root.sourceUrl) {
                root.ready = true;
                root.mediaReady();
            }
        }

        onPositionChanged: position => {
            if (root.primingFrame && root.paused && position > 0) {
                root.primingFrame = false;
                primeFallbackTimer.stop();
                root.ready = true;
                player.pause();
            }
        }

        onErrorOccurred: (error, errorString) => {
            root.primingFrame = false;
            primeFallbackTimer.stop();
            const msg = errorString ? errorString : ("Media error code " + error);
            root.mediaError(msg);
        }
    }
}
