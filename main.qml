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
    property string custom_url: ""
    property string custom_crs: "EPSG:2056"
    property string saved_custom_endpoints: "[]"
  }

  function getActivePreset() {
    return presets.find(p => p.name === settings.selected_preset) || presets[0];
  }

  function getActiveUrl() {
    return settings.custom_url || getActivePreset().url;
  }

  function getActiveCrs() {
    return settings.custom_url ? settings.custom_crs : getActivePreset().crs;
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
      "service_url": plugin.getActiveUrl(),
      "service_crs": plugin.getActiveCrs()
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
    property string customPlaceholder: "Custom"

    function loadSavedCustomEndpoints() {
      try {
        const parsed = JSON.parse(settings.saved_custom_endpoints);
        savedCustomEndpoints = Array.isArray(parsed) ? parsed : [];
      } catch (e) {
        savedCustomEndpoints = [];
      }
    }

    function findPreset(name) {
      return presets.find(p => p.name === name);
    }

    function findCustomEndpoint(url) {
      return savedCustomEndpoints.find(e => e.url === url);
    }

    function isValidUrl(url) {
      return url.startsWith("http://") || url.startsWith("https://");
    }

    function saveCustomEndpoint(url, crs) {
      if (!url || !isValidUrl(url)) return;

      savedCustomEndpoints = savedCustomEndpoints.filter(e => e.url !== url);
      savedCustomEndpoints.unshift({ url: url, crs: crs });

      if (savedCustomEndpoints.length > 10) {
        savedCustomEndpoints = savedCustomEndpoints.slice(0, 10);
      }

      settings.saved_custom_endpoints = JSON.stringify(savedCustomEndpoints);
    }

    function deleteSelectedCustom() {
      const item = serviceCombo.model[serviceCombo.currentIndex];
      if (!item || !item.isCustom) return;

      savedCustomEndpoints = savedCustomEndpoints.filter(e => e.url !== item.url);
      settings.saved_custom_endpoints = JSON.stringify(savedCustomEndpoints);

      rebuildComboModel();
      serviceCombo.currentIndex = serviceCombo.model.length - 1;
      updateFromSelection();
    }

    function rebuildComboModel() {
      let items = [];

      presets.forEach(preset => {
        items.push({
          label: preset.name,
          url: preset.url,
          crs: preset.crs,
          isPreset: true,
          isCustom: false,
          isPlaceholder: false
        });
      });

      savedCustomEndpoints.forEach(endpoint => {
        items.push({
          label: endpoint.url,
          url: endpoint.url,
          crs: endpoint.crs,
          isPreset: false,
          isCustom: true,
          isPlaceholder: false
        });
      });

      items.push({
        label: customPlaceholder,
        url: "",
        crs: settings.custom_crs,
        isPreset: false,
        isCustom: false,
        isPlaceholder: true
      });

      serviceCombo.model = items;
    }

    function updateFromSelection() {
      const item = serviceCombo.model[serviceCombo.currentIndex];
      if (!item) return;

      if (item.isPlaceholder) {
        serviceCombo.editable = true;
        serviceCombo.editText = "";
        serviceCrsTextField.text = settings.custom_crs;
        deleteButton.visible = false;
      } else if (item.isPreset) {
        serviceCombo.editable = false;
        serviceCrsTextField.text = item.crs;
        deleteButton.visible = false;
      } else if (item.isCustom) {
        serviceCombo.editable = false;
        serviceCrsTextField.text = item.crs;
        deleteButton.visible = true;
      }
    }

    onOpened: {
      loadSavedCustomEndpoints();
      rebuildComboModel();

      let foundIndex = -1;

      if (settings.selected_preset) {
        for (let i = 0; i < serviceCombo.model.length; i++) {
          if (serviceCombo.model[i].isPreset && serviceCombo.model[i].label === settings.selected_preset) {
            foundIndex = i;
            break;
          }
        }
      } else if (settings.custom_url) {
        for (let i = 0; i < serviceCombo.model.length; i++) {
          if (serviceCombo.model[i].isCustom && serviceCombo.model[i].url === settings.custom_url) {
            foundIndex = i;
            break;
          }
        }
      }

      if (foundIndex !== -1) {
        serviceCombo.currentIndex = foundIndex;
      } else {
        serviceCombo.currentIndex = 0;
      }

      updateFromSelection();
    }

    ColumnLayout {
      width: parent.width
      spacing: 10

      Label {
        text: qsTr("Service URL")
        font: Theme.defaultFont
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ComboBox {
          id: serviceCombo
          Layout.fillWidth: true
          font: Theme.defaultFont
          textRole: "label"
          editable: false

          onActivated: settingsDialog.updateFromSelection()
        }

        QfToolButton {
          id: deleteButton
          visible: false
          bgcolor: "transparent"
          iconSource: Theme.getThemeVectorIcon("ic_delete_forever_white_24dp")
          iconColor: Theme.mainTextColor

          onClicked: {
            settingsDialog.deleteSelectedCustom();
            mainWindow.displayToast(qsTr("Removed URL"));
          }
        }
      }

      Label {
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
      const item = serviceCombo.model[serviceCombo.currentIndex];
      const crs = serviceCrsTextField.text.trim();

      if (!crs) {
        mainWindow.displayToast(qsTr("CRS is required"));
        return;
      }

      if (item.isPlaceholder) {
        const customUrl = serviceCombo.editText.trim();

        if (!customUrl) {
          mainWindow.displayToast(qsTr("URL is required"));
          return;
        }

        if (!isValidUrl(customUrl)) {
          mainWindow.displayToast(qsTr("Invalid URL entered"));
          return;
        }

        settings.selected_preset = "";
        settings.custom_url = customUrl;
        settings.custom_crs = crs;

        saveCustomEndpoint(customUrl, crs);
        mainWindow.displayToast(qsTr("Settings stored"));
      } else if (item.isPreset) {
        const presetCrsChanged = crs !== item.crs;

        settings.selected_preset = item.label;
        settings.custom_url = "";
        settings.custom_crs = crs;

        if (presetCrsChanged) {
          mainWindow.displayToast(qsTr("Preset CRS changed"));
        } else {
          mainWindow.displayToast(qsTr("Settings stored"));
        }
      } else if (item.isCustom) {
        settings.selected_preset = "";
        settings.custom_url = item.url;
        settings.custom_crs = crs;

        saveCustomEndpoint(item.url, crs);
        mainWindow.displayToast(qsTr("Settings stored"));
      }
    }
  }
}
