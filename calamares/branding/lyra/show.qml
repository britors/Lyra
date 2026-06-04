/* Lyra OS — minimal installer slideshow (§11) */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        interval: 6000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            color: "#6e6aff"
            font.pixelSize: 24
            text: "Lyra OS\nSimples. Poderoso. Seu."
        }
    }
    Slide {
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            color: "#ffffff"
            font.pixelSize: 18
            text: "Loja de aplicativos Flatpak/Flathub já configurada.\nInstale o que quiser com um clique."
        }
    }
    Slide {
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            color: "#ffffff"
            font.pixelSize: 18
            text: "Snapshots automáticos: se um update der problema,\nvocê volta no tempo pelo menu de inicialização."
        }
    }
}
