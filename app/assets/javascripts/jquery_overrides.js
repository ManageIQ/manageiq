jQuery.evalLog = function (text) {
  try {
    jQuery.globalEval(text.slice('throw "error";'.length));
  } catch (ex) {
    if (typeof console !== "undefined" && typeof console.error !== "undefined") {
      console.error('exception caught evaling RJS');
      console.error(ex);
      console.debug('script follows:', text);
    }
  }
  return text;
};

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
    "text json": function (text) {
      return jQuery.jsonPayload(text, function (text) { return jQuery.parseJSON(text); });
    },
    "text script": function (text) {
      if (text.match(/^{/)) {
        return jQuery.jsonPayload(text, function (text) { return text; });
      } else { // JavaScript payload
        jQuery.evalLog.call(this, text);
        return text;
      }
    }
  }
});
