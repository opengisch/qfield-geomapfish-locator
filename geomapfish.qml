import QtQuick
import org.qfield

Item {
  signal prepareResult(var details)
  signal fetchResultsEnded()
  
  function fetchResults(string, context, parameters) {
    console.log('Fetching results....');
    if (parameters["service_url"] === undefined) {
      fetchResultsEnded();
    }
    
    let request = new XMLHttpRequest();
    request.onreadystatechange = function() {
      if (request.readyState === XMLHttpRequest.DONE) {
        let features = FeatureUtils.featuresFromJsonString(request.response)
        for (let feature of features) {
          let details = {
            "userData": feature.geometry,
            "displayString": feature.attribute('label'),
            "description": "",
            "score": 1,
            "group": feature.attribute('layer_name'),
            "groupScore":1
          };
          prepareResult(details);
        }
        fetchResultsEnded()
      }
    }

    request.open("GET", parameters["service_url"] + "?query=" + string + '&limit=20&partitionlimit=20')
    request.send();
  }
}
