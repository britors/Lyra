// Lyra OS — tela de seleção da migração do Windows
// (PROMPT-CALAMARES-MIGRACAO-WINDOWS.md §6.1, §7)
//
// View step puramente QML (sem C++), consumindo o resultado já
// calculado pelo job winmigrate-detect (globalstorage.windowsMigration).
// Se nada foi detectado, a etapa se auto-pula (§2: "não aparece — o
// fluxo segue direto para Users, sem tela vazia").

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import io.calamares.core 1.0 as Calamares

Item {
    id: root

    property var migration: Calamares.GlobalStorage.value("windowsMigration") || { "found": false }
    property var profileNames: migration.found ? Object.keys(migration.profiles) : []
    property string currentProfile: profileNames.length > 0 ? profileNames[0] : ""
    property var currentItems: currentProfile ? migration.profiles[currentProfile] : []

    ListModel { id: itemsModel }

    function bytesToHuman(bytes) {
        var units = ["B", "KB", "MB", "GB", "TB"]
        var value = bytes
        var unitIndex = 0
        while (value >= 1024 && unitIndex < units.length - 1) {
            value = value / 1024
            unitIndex += 1
        }
        return value.toFixed(unitIndex === 0 ? 0 : 1) + " " + units[unitIndex]
    }

    function reloadItemsModel() {
        itemsModel.clear()
        for (var i = 0; i < currentItems.length; i++) {
            var entry = currentItems[i]
            itemsModel.append({
                itemId: entry.id,
                dest: entry.dest,
                sizeBytes: entry.size_bytes,
                selected: entry.default
            })
        }
    }

    function totalSelectedBytes() {
        var total = 0
        for (var i = 0; i < itemsModel.count; i++) {
            var row = itemsModel.get(i)
            if (row.selected) {
                total += row.sizeBytes
            }
        }
        return total
    }

    function persistSelectionAndAdvance(skipped) {
        var selectedIds = []
        for (var i = 0; i < itemsModel.count; i++) {
            var row = itemsModel.get(i)
            if (row.selected) {
                selectedIds.push(row.itemId)
            }
        }
        Calamares.GlobalStorage.insert("windowsMigrationSelection", {
            skipped: skipped,
            profile: currentProfile,
            selectedIds: skipped ? [] : selectedIds
        })
        Calamares.ViewManager.next()
    }

    Component.onCompleted: {
        if (!migration.found) {
            // Nada detectado (ou BitLocker/hibernação abortaram a
            // detecção) — segue direto para a próxima etapa (Users).
            persistSelectionAndAdvance(true)
            return
        }
        reloadItemsModel()
    }

    Loader {
        anchors.fill: parent
        active: migration.found
        sourceComponent: ColumnLayout {
            width: root.width
            spacing: 16

            Label {
                text: qsTr("Encontramos uma instalação do Windows")
                font.pixelSize: 22
                font.bold: true
            }

            Label {
                text: qsTr("Selecione o que deseja copiar para a sua nova conta. Os arquivos serão copiados — nunca movidos — e o Windows não será alterado.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                visible: profileNames.length > 1
                Label { text: qsTr("Conta do Windows:") }
                ComboBox {
                    model: profileNames
                    onCurrentTextChanged: {
                        currentProfile = currentText
                        currentItems = migration.profiles[currentProfile]
                        reloadItemsModel()
                    }
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: itemsModel
                delegate: RowLayout {
                    width: ListView.view.width
                    CheckBox {
                        checked: model.selected
                        text: model.dest
                        onToggled: itemsModel.setProperty(index, "selected", checked)
                    }
                    Item { Layout.fillWidth: true }
                    Label { text: bytesToHuman(model.sizeBytes) }
                }
            }

            Label {
                text: qsTr("Total selecionado: %1").arg(bytesToHuman(totalSelectedBytes()))
                font.bold: true
            }

            Label {
                text: qsTr("Nada será apagado do Windows.")
                font.italic: true
            }

            RowLayout {
                Layout.fillWidth: true
                Button {
                    text: qsTr("Pular esta etapa")
                    onClicked: persistSelectionAndAdvance(true)
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: qsTr("Continuar")
                    highlighted: true
                    onClicked: persistSelectionAndAdvance(false)
                }
            }
        }
    }
}
