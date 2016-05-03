jQuery.evalLog = function (text) {
  try {
    if (text.match('^throw "error";')) {
      jQuery.globalEval(text.slice('throw "error";'.length));
    } else {
      jQuery.globalEval(text);
    }
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
  converters: { // Log exceptions when evaling javascripts
    "text script": function( text ) {
      jQuery.evalLog.call(this, text);
      return text;
    }
  }
});
