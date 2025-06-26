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

    ColumnLayout {
      width: parent.width
      spacing: 10

      Label {
        id: serviceUrlLabel
        text: qsTr("Service URL")
        font: Theme.defaultFont
      }
      
      TextField {
        id: serviceUrlTextField
        Layout.fillWidth: true
        font: Theme.defaultFont
        text: settings.service_url
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
      settings.service_url = serviceUrlTextField.text;
      settings.service_crs = serviceCrsTextField.text;
      mainWindow.displayToast(qsTr("Settings stored"));
    }
  }
}
