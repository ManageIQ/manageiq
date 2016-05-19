// CTRL+SHIFT+X stops the spinner
$(document).bind('keyup', 'ctrl+shift+x', miqSparkleOff);

/// Warn for duplicate DOM IDs
(function () {
  var duplicate = function () {
    $('[id]').each(function(){
      var ids = $('[id="' + this.id + '"]');
      if (ids.length > 1 && ids.indexOf(this) !== -1)
        console.warn('Duplicate DOM ID #' + this.id);
    });
  };

  $(duplicate);
  $(document).ajaxComplete(duplicate);
})();
