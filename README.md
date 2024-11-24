# QField GeoMapFish Locator Plugin

This [QField](https://qfield.org) plugin serves as a template to integrate
a [GeoMapFish service](https://geomapfish.org/) into the QField search bar. The plugin relies on new
functionalities within the plugin framework introduced in QField 3.5.

## Installation

To install the plugin, [download the plugin from the releases page](https://github.com/opengisch/qfield-geomapfish-locator/releases)
and follow the [plugin installation guide](https://docs.qfield.org/how-to/plugins/#application-plugins) to install
the zipped plugin in QField.

## Service customization

Users and plugin authors are encouraged to explore the plugin code. To change
the GeoMapFish service used by the plugin, look for the the "service_url"
and "service_crs" parameters attached to the QFieldLocatorFilter item
in main.qml 
