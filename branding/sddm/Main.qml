// Lyra OS — SDDM login theme (§10). Minimal, Wayland-friendly, Qt6.
import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920; height: 1080
    color: "#0a0a1f"

    TextConstants { id: textConstants }

    // Wallpaper (falls back to the navy base color if missing).
    Image {
        anchors.fill: parent
        source: config.background || "background.png"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        onStatusChanged: if (status === Image.Error) visible = false
    }

    // Subtle sapphire->violet overlay for legibility.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#990a0a1f" }
            GradientStop { position: 1.0; color: "#cc1a1140" }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 18
        width: 320

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Lyra OS"
            color: "#6e6aff"
            font.pixelSize: 40
            font.bold: true
        }

        ComboBox {
            id: userBox
            width: parent.width
            model: userModel
            currentIndex: userModel.lastIndex
            textRole: "name"
        }

        TextField {
            id: passwordField
            width: parent.width
            echoMode: TextInput.Password
            placeholderText: "Senha"
            focus: true
            onAccepted: sddm.login(userBox.currentText, passwordField.text, sessionBox.currentIndex)
        }

        Button {
            width: parent.width
            text: "Entrar"
            onClicked: sddm.login(userBox.currentText, passwordField.text, sessionBox.currentIndex)
        }

        ComboBox {
            id: sessionBox
            width: parent.width
            model: sessionModel
            currentIndex: sessionModel.lastIndex
            textRole: "name"
        }

        Text {
            id: errorText
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#ff6b6b"
            text: ""
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() { errorText.text = "Falha no login. Tente novamente." }
    }
}
