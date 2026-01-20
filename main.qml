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

  readonly property var presets: [
    { name: "GeoMapFish Demo", url: "https://geomapfish-demo-2-9.camptocamp.com/search", crs: "EPSG:2056" },
    { name: "SIGIP", url: "https://www.sigip.ch/search", crs: "EPSG:2056" },
    { name: "Cartoriviera", url: "https://map.cartoriviera.ch/search", crs: "EPSG:2056" },
    { name: "SITN", url: "https://sitn.ne.ch/search", crs: "EPSG:2056" }
  ]

  function getPresetByName(name) {
    return presets.find(p => p.name === name);
  }

  function getActivePreset() {
    return getPresetByName(settings.selected_preset) || presets[0];
  }

  Component.onCompleted: {
    geoMapFishLocatorFilter.locatorBridge.registerQFieldLocatorFilter(geoMapFishLocatorFilter);
  }

  Component.onDestruction: {
    geoMapFishLocatorFilter.locatorBridge.deregisterQFieldLocatorFilter(geoMapFishLocatorFilter);
  }

  Settings {
    id: settings
    category: "qfield-geomapfish-locator"

    property string selected_preset: "GeoMapFish Demo"
    property string service_url: ""
    property string service_crs: ""
    property string saved_custom_endpoints: "[]"
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
      "service_url": settings.service_url || plugin.getActivePreset().url,
      "service_crs": settings.service_crs || plugin.getActivePreset().crs
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

    property var savedCustomEndpoints: []

    function loadCustomEndpoints() {
      try {
        savedCustomEndpoints = JSON.parse(settings.saved_custom_endpoints);
        if (!Array.isArray(savedCustomEndpoints)) savedCustomEndpoints = [];
      } catch (e) {
        savedCustomEndpoints = [];
      }
    }

    function saveCustomEndpoint(url, crs) {
      savedCustomEndpoints = savedCustomEndpoints.filter(e => e.url !== url);
      savedCustomEndpoints.unshift({ url: url, crs: crs });
      if (savedCustomEndpoints.length > 10) savedCustomEndpoints.length = 10;
      settings.saved_custom_endpoints = JSON.stringify(savedCustomEndpoints);
    }

    function deleteCustomEndpoint() {
      const selected = endpointCombo.model[endpointCombo.currentIndex];
      savedCustomEndpoints = savedCustomEndpoints.filter(e => e.url !== selected.url);
      settings.saved_custom_endpoints = JSON.stringify(savedCustomEndpoints);
      populateEndpoints();
      endpointCombo.currentIndex = endpointCombo.model.length - 1;
      updateFields();
    }

    function populateEndpoints() {
      let items = [];

      presets.forEach(p => items.push({ name: p.name, url: p.url, crs: p.crs, isCustom: false }));
      savedCustomEndpoints.forEach(e => items.push({ name: e.url, url: e.url, crs: e.crs, isCustom: true }));
      items.push({ name: qsTr("Custom"), url: "", crs: "", isCustom: false });

      endpointCombo.model = items;
    }

    function updateFields() {
      const selected = endpointCombo.model[endpointCombo.currentIndex];
      const isCustomNew = !selected.url;

      serviceUrlTextField.visible = isCustomNew;
      deleteButton.visible = selected.isCustom;

      if (isCustomNew) {
        serviceUrlTextField.text = "";
        serviceCrsTextField.text = settings.service_crs || plugin.getActivePreset().crs;
      } else {
        serviceCrsTextField.text = selected.crs;
      }
    }

    onOpened: {
      loadCustomEndpoints();
      populateEndpoints();

      let index = 0;
      if (settings.service_url) {
        index = endpointCombo.model.findIndex(m => m.url === settings.service_url);
      } else if (settings.selected_preset) {
        index = endpointCombo.model.findIndex(m => m.name === settings.selected_preset);
      }

      endpointCombo.currentIndex = index !== -1 ? index : 0;
      updateFields();
    }

    ColumnLayout {
      width: parent.width
      spacing: 10

      Label {
        id: serviceUrlLabel
        text: qsTr("Service URL")
        font: Theme.defaultFont
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ComboBox {
          id: endpointCombo
          Layout.fillWidth: true
          font: Theme.defaultFont
          textRole: "name"
          onActivated: settingsDialog.updateFields()
        }

        QfToolButton {
          id: deleteButton
          visible: false
          bgcolor: "transparent"
          iconSource: Theme.getThemeVectorIcon("ic_delete_forever_white_24dp")
          iconColor: Theme.mainTextColor
          onClicked: {
            settingsDialog.deleteCustomEndpoint();
            mainWindow.displayToast(qsTr("Removed URL"));
          }
        }
      }

      TextField {
        id: serviceUrlTextField
        Layout.fillWidth: true
        font: Theme.defaultFont
        visible: false
        placeholderText: qsTr("e.g., https://example.com/search")
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
        placeholderText: qsTr("e.g., EPSG:2056")
      }
    }

    onAccepted: {
      const selected = endpointCombo.model[endpointCombo.currentIndex];
      const crs = serviceCrsTextField.text.trim();

      if (!crs) {
        mainWindow.displayToast(qsTr("CRS is required"));
        return;
      }

      // Custom new entry
      if (!selected.url) {
        const url = serviceUrlTextField.text.trim();
        if (!url) {
          mainWindow.displayToast(qsTr("URL is required"));
          return;
        }
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
          mainWindow.displayToast(qsTr("Invalid URL entered"));
          return;
        }

        settings.selected_preset = "";
        settings.service_url = url;
        settings.service_crs = crs;
        saveCustomEndpoint(url, crs);
        mainWindow.displayToast(qsTr("Settings stored"));
        return;
      }

      // Preset selected
      if (!selected.isCustom) {
        const preset = plugin.getPresetByName(selected.name);
        settings.selected_preset = selected.name;
        settings.service_url = "";
        settings.service_crs = crs;

        if (preset && crs !== preset.crs) {
          mainWindow.displayToast(qsTr("Preset CRS changed"));
        } else {
          mainWindow.displayToast(qsTr("Settings stored"));
        }
        return;
      }

      // Custom saved entry
      settings.selected_preset = "";
      settings.service_url = selected.url;
      settings.service_crs = crs;
      saveCustomEndpoint(selected.url, crs);
      mainWindow.displayToast(qsTr("Settings stored"));
    }
  }
}
