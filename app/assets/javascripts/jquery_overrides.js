jQuery.evalLog = function (text) {
  try {
    jQuery.globalEval(text.slice('throw "error";'.length));
  } catch (ex) {
    if (typeof console !== "undefined" && typeof console.error !== "undefined") {
      console.error('exception caught evaling RJS');
      console.error(ex);
      console.error('script follows:')
      console.error(text);
    }
  }
  return text;
};

$.ajaxSetup({
  converters: {
    "text script": function(text) {
      if (text.match(/^{/)) { // JSON payload
        var parsed_json = jQuery.parseJSON(text);
        if (parsed_json['explorer']) {
          return ManageIQ.explorer.process(parsed_json); // ExplorerPresenter payload
        } else {
          return null;
        }
      } else { // JavaScript payload
        jQuery.evalLog.call(this, text);
        return text;
      }
    }
  }
});
