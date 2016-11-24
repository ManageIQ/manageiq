function logError(fn) {
  return function (text) {
    try {
      fn(text);
    } catch (ex) {
      if (typeof console !== "undefined" && typeof console.error !== "undefined") {
        console.error('exception caught evaling RJS');
        console.error(ex);
        console.debug('script follows:', text);
      }
    }
    return text;
  };
}

jQuery.jsonPayload = function (text, fallback) {
  var parsed_json = jQuery.parseJSON(text);
  if (parsed_json['explorer']) {
    return ManageIQ.explorer.process(parsed_json); // ExplorerPresenter payload
  } else {
    return fallback(text);
  }
};

$.ajaxSetup({
  accepts: {
    json: "text/javascript, application/javascript, application/ecmascript, application/x-ecmascript"
  },
  contents: {
    json: /application\/json/
  },
  converters: {
    "text json": logError(function (text) {
      return jQuery.jsonPayload(text, function (text) { return jQuery.parseJSON(text); });
    }),
    "text script": logError(function (text) {
      if (text.match(/^{/)) {
        return jQuery.jsonPayload(text, function (text) { return text; });
      } else { // JavaScript payload
        jQuery.globalEval(text.slice('throw "error";'.length));
        return text;
      }
    }),
  }
});
