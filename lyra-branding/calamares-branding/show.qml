/*
 * Lyra OS — slideshow do instalador Calamares
 * PROMPT-LYRA-IDENTIDADE.md §4.5 — 6 slides, Lyro aparece só no último.
 */
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation

    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#0D0D1F" }
        Image {
            source: "wordmark.png"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -40
            width: 340; height: 81
            fillMode: Image.PreserveAspectFit
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: 30
            text: "HARMONIA. PERFORMANCE. LIBERDADE."
            color: "#A78BFA"
            font.pixelSize: 16
            font.letterSpacing: 3
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#0D0D1F" }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -20
            text: "Seu escritório completo"
            color: "#E8ECFF"
            font.pixelSize: 28
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: 16
            text: "Prosa, Calco e Pulso vêm pré-instalados —\ntexto, planilhas e apresentações, prontos para usar."
            color: "#E8ECFF"
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#0D0D1F" }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -20
            text: "Suas finanças organizadas"
            color: "#E8ECFF"
            font.pixelSize: 28
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: 16
            text: "O Fina acompanha seu orçamento e suas contas\nsem sair do seu computador."
            color: "#E8ECFF"
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#0D0D1F" }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -20
            text: "Restaure com um clique"
            color: "#E8ECFF"
            font.pixelSize: 28
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: 16
            text: "Snapper cria pontos de restauração automáticos —\nse algo der errado, é só voltar no tempo."
            color: "#E8ECFF"
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#0D0D1F" }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -20
            text: "Milhares de apps"
            color: "#E8ECFF"
            font.pixelSize: 28
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: 16
            text: "GNOME Software conecta você ao Flathub —\ninstale o que precisar em poucos cliques."
            color: "#E8ECFF"
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#0D0D1F" }
        Image {
            source: "lyro.png"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: -10
            width: 130; height: 169
            fillMode: Image.PreserveAspectFit
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: 22
            text: "Quase lá!"
            color: "#E8ECFF"
            font.pixelSize: 28
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: 60
            text: "O Lyro vai estar por aqui se você precisar de ajuda."
            color: "#E8ECFF"
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
