import QtQuick
import QtQuick.Controls

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

  QFieldLocatorFilter {
    id: geoMapFishLocatorFilter

    name: "GeoMapFish"
    displayName: "GeoMapFish"
    prefix: "gmf"
    locatorBridge: iface.findItemByObjectName('locatorBridge')

    parameters: {
      "service_url": "https://geomapfish-demo-2-8.camptocamp.com/search",
      "service_crs": "EPSG:2056"
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
      
      locatorBridge.locatorHighlightGeometry.qgsGeometry = result.userData;
      locatorBridge.locatorHighlightGeometry.crs = CoordinateReferenceSystemUtils.fromDescription(parameters["service_crs"]);
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
}
