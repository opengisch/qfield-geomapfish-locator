# QField GeoMapFish Locator Plugin

This [QField](https://qfield.org) plugin serves as a template to integrate
a [GeoMapFish service](https://geomapfish.org/) into the QField search bar. The plugin relies on new
functionalities within the plugin framework introduced in QField 3.5.

## Installation

To install the plugin, [download the plugin from the releases page](https://github.com/opengisch/qfield-geomapfish-locator/releases)
and follow the [plugin installation guide](https://docs.qfield.org/how-to/plugins/#application-plugins) to install
the zipped plugin in QField.

## Usage

To start searches once the plugin is installed, expand the search bar, type
the prefix gmf followed by the search string, and wait for the GeoMapFish
service to provide you with results:

[Screencast](https://github.com/user-attachments/assets/63ae86c2-b59c-4a7f-ae73-1c39ee2bafe8)

## Customization

Users and plugin authors are encouraged to explore the plugin code. To change
the GeoMapFish service used by the plugin, look for the the "service_url"
and "service_crs" attached to the parameters property of the QFieldLocatorFilter
item in main.qml 

You can customize the search bar prefix by changing the prefix property 
of the QFieldLocatorFilter item. By having unique prefixes, you can
integrate multiple services.
