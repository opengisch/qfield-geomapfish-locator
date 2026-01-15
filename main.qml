import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QtCore

import org.qfield
import org.qgis
import Theme

Item {
  id: plugin

  property var mainWindow: iface.mainWindow()
  property var mapCanvas: iface.mapCanvas()

  Component.onCompleted: {
    geoMapFishLocatorFilter.locatorBridge.registerQFieldLocatorFilter(geoMapFishLocatorFilter);
  }

  Component.onDestruction: {
    geoMapFishLocatorFilter.locatorBridge.deregisterQFieldLocatorFilter(geoMapFishLocatorFilter);
  }

  Settings {
    id: settings
    category: "qfield-geomapfish-locator"

    property string service_url: "https://geomapfish-demo-2-9.camptocamp.com/search"
    property string service_crs: "EPSG:2056"

    // user pinned urls (json array)
    property string pinned_service_urls: "[]"
  }

  function configure() {
    settingsDialog.open();
  }

  QFieldLocatorFilter {
    id: geoMapFishLocatorFilter

    name: "GeoMapFish"
    displayName: "GeoMapFish"
    prefix: "gmf"
    locatorBridge: iface.findItemByObjectName('locatorBridge')

    parameters: {
      "service_url": settings.service_url,
      "service_crs": settings.service_crs
    }
    source: Qt.resolvedUrl('geomapfish.qml')

    Component.onCompleted: {
      if (geoMapFishLocatorFilter.description !== undefined) {
        geoMapFishLocatorFilter.description = "Returns GeoMapFish search results."
      }
    }

    function triggerResult(result) {
      if (result.userData.type === Qgis.GeometryType.Point) {
        const centroid = GeometryUtils.reprojectPoint(
          GeometryUtils.centroid(result.userData),
          CoordinateReferenceSystemUtils.fromDescription(parameters["service_crs"]),
          mapCanvas.mapSettings.destinationCrs
        )
        mapCanvas.mapSettings.setCenter(centroid, true);
      } else {
        const extent = GeometryUtils.reprojectRectangle(
          GeometryUtils.boundingBox(result.userData),
          CoordinateReferenceSystemUtils.fromDescription(parameters["service_crs"]),
          mapCanvas.mapSettings.destinationCrs
        )
        mapCanvas.mapSettings.setExtent(extent, true);
      }

      locatorBridge.geometryHighlighter.qgsGeometry = result.userData;
      locatorBridge.geometryHighlighter.crs = CoordinateReferenceSystemUtils.fromDescription(parameters["service_crs"]);
    }

    function triggerResultFromAction(result, actionId) {
      if (actionId === 1) {
        let navigation = iface.findItemByObjectName('navigation')
        const centroid = GeometryUtils.reprojectPoint(
          GeometryUtils.centroid(result.userData),
          CoordinateReferenceSystemUtils.fromDescription(parameters["service_crs"]),
          mapCanvas.mapSettings.destinationCrs
        )
        navigation.destination = centroid
      }
    }
  }

  Dialog {
    id: settingsDialog
    parent: mainWindow.contentItem
    visible: false
    modal: true
    font: Theme.defaultFont
    standardButtons: Dialog.Ok | Dialog.Cancel
    title: qsTr("GeoMapFish search settings")

    x: (mainWindow.width - width) / 2
    y: (mainWindow.height - height) / 2

    width: mainWindow.width * 0.8

    property string pendingServiceUrl: settings.service_url
    property bool showCustomInput: false

    ListModel { id: serviceUrlModel }

    function normalizeUrl(url) {
      return (url || "").trim()
    }

    function loadPinnedUrls() {
      let arr = []
      try {
        arr = JSON.parse(settings.pinned_service_urls)
      } catch (e) {
        arr = []
      }
      if (!Array.isArray(arr)) {
        arr = []
      }

      let clean = []
      for (let i = 0; i < arr.length; i++) {
        const normalUrl = normalizeUrl(arr[i])
        if (!normalUrl) {
          continue
        }
        if (clean.indexOf(normalUrl) === -1) {
          clean.push(normalUrl)
        }
      }
      return clean
    }

    function savePinnedUrls(arr) {
      settings.pinned_service_urls = JSON.stringify(arr)
    }

    function isPinned(url) {
      url = normalizeUrl(url)
      if (!url) return false
      return loadPinnedUrls().indexOf(url) !== -1
    }

    function rebuildModel() {
      serviceUrlModel.clear()

      const pinned = loadPinnedUrls()
      for (let i = 0; i < pinned.length; i++) {
        serviceUrlModel.append({ text: pinned[i], url: pinned[i], isCustom: false })
      }

      serviceUrlModel.append({ text: qsTr("Custom"), url: "__custom__", isCustom: true })
    }

    function setSelectionFromUrl(url) {
      url = normalizeUrl(url)
      settingsDialog.pendingServiceUrl = url

      const pinned = loadPinnedUrls()
      const idx = pinned.indexOf(url)

      if (idx !== -1) {
        // select pinned, hide custom input
        serviceUrlCombo.currentIndex = idx
        settingsDialog.showCustomInput = false
        customServiceUrlTextField.text = url
      } else {
        // select custom, show input
        serviceUrlCombo.currentIndex = serviceUrlModel.count - 1
        settingsDialog.showCustomInput = true
        customServiceUrlTextField.text = url
      }
    }

    function pinUrl(url) {
      url = normalizeUrl(url)
      if (!url)
      {
        return
      }

      //avoid obvious invalid entries
      if (url.indexOf("http://") !== 0 && url.indexOf("https://") !== 0) {
        mainWindow.displayToast(qsTr("Please enter a valid http(s) URL"))
        return
      }

      let pinned = loadPinnedUrls()
      if (pinned.indexOf(url) === -1) {
        pinned.unshift(url) // newest first
        savePinnedUrls(pinned)
      }

      rebuildModel()
      setSelectionFromUrl(url) // switches to pinned -> hides input
    }

    function unpinUrl(url) {
      url = normalizeUrl(url)
      if (!url)
      {
        return
      }

      let pinned = loadPinnedUrls()
      const idx = pinned.indexOf(url)
      if (idx !== -1) {
        pinned.splice(idx, 1)
        savePinnedUrls(pinned)
      }

      rebuildModel()
      // after unpin -> go to Custom with the same url
      serviceUrlCombo.currentIndex = serviceUrlModel.count - 1
      settingsDialog.pendingServiceUrl = url
      settingsDialog.showCustomInput = true
      customServiceUrlTextField.text = url
      customServiceUrlTextField.forceActiveFocus()
    }

    onOpened: {
      settingsDialog.pendingServiceUrl = settings.service_url
      serviceCrsTextField.text = settings.service_crs

      rebuildModel()
      setSelectionFromUrl(settingsDialog.pendingServiceUrl)
    }

    ColumnLayout {
      width: parent.width
      spacing: 10

      Label {
        id: serviceUrlLabel
        text: qsTr("Service URL")
        font: Theme.defaultFont
      }

      QfComboBox {
        id: serviceUrlCombo
        Layout.fillWidth: true
        font: Theme.defaultFont
        model: serviceUrlModel
        textRole: "text"

        delegate: ItemDelegate {
          width: ListView.view ? ListView.view.width : 200

          contentItem: RowLayout {
            width: parent.width
            spacing: 10

            Label {
              Layout.fillWidth: true
              text: model.text
              font: Theme.defaultFont
              elide: Text.ElideRight
              verticalAlignment: Text.AlignVCenter
            }

            // pin icon on right only for pinned entries
            Item {
              visible: !model.isCustom
              Layout.preferredWidth: 35
              Layout.fillHeight: true
              Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

              QfToolButton {
                width: parent.width
                anchors.centerIn: parent
                iconSource: Theme.getThemeVectorIcon("ic_pin_black_24dp")
                iconColor: Theme.mainColor
                bgcolor: "transparent"
                enabled: false // click handled by MouseArea
              }

              MouseArea {
                anchors.fill: parent
                preventStealing: true

                onClicked: function(mouse) {
                  mouse.accepted = true
                  settingsDialog.unpinUrl(model.url)
                  mainWindow.displayToast(qsTr("Unpinned url "));
                }
              }
            }
          }

          onClicked: {
            serviceUrlCombo.currentIndex = index
            serviceUrlCombo.popup.close()
          }
        }

        onActivated: function(index) {
          if (index < 0 || index >= serviceUrlModel.count)
          {
            return
          }

          const obj = serviceUrlModel.get(index)
          if (!obj)
          {
            return
          }

          if (obj.url === "__custom__") {
            settingsDialog.showCustomInput = true
            customServiceUrlTextField.text = settingsDialog.pendingServiceUrl
            customServiceUrlTextField.forceActiveFocus()
          } else {
            settingsDialog.pendingServiceUrl = obj.url
            settingsDialog.showCustomInput = false
          }
        }
      }

      // custom input appears only if custom selected
      RowLayout {
        Layout.fillWidth: true
        visible: settingsDialog.showCustomInput
        spacing: 10

        TextField {
          id: customServiceUrlTextField
          Layout.fillWidth: true
          font: Theme.defaultFont
          text: settingsDialog.pendingServiceUrl

          onTextChanged: {
            settingsDialog.pendingServiceUrl = settingsDialog.normalizeUrl(text)
          }
        }

        // Pin icon beside custom field
        Item {
          Layout.preferredWidth: 45
          Layout.preferredHeight: customServiceUrlTextField.implicitHeight

          QfToolButton {
            width: parent.width
            anchors.centerIn: parent
            iconSource: Theme.getThemeVectorIcon("ic_pin_black_24dp")
            iconColor: settingsDialog.isPinned(settingsDialog.pendingServiceUrl) ? Theme.mainTextDisabledColor : Theme.mainColor
            bgcolor: "transparent"
            enabled: false
          }

          MouseArea {
            anchors.fill: parent
            onClicked: {
              if (settingsDialog.isPinned(settingsDialog.pendingServiceUrl)) {
                mainWindow.displayToast(qsTr("This URL is already pinned"))
                return
              }
              settingsDialog.pinUrl(settingsDialog.pendingServiceUrl)
              mainWindow.displayToast(qsTr("Pinned URL"))
            }
          }
        }
      }

      Label {
        id: serviceCrsLabel
        text: qsTr("Service CRS")
        font: Theme.defaultFont
      }

      TextField {
        id: serviceCrsTextField
        Layout.fillWidth: true
        font: Theme.defaultFont
        text: settings.service_crs
      }
    }

    onAccepted: {
      settings.service_url = settingsDialog.pendingServiceUrl;
      settings.service_crs = serviceCrsTextField.text;
      mainWindow.displayToast(qsTr("Settings stored"));
    }
  }
}
