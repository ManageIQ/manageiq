if (typeof _ !== 'undefined' && typeof _.debounce !== 'undefined') {
  var orig_debounce = _.debounce;
  _.debounce = function(func, wait, options) {
    // Override the original fn; new_func will be the original fn with wait prepended to it
    // We make sure that once this fn is actually run, it decreases the counter
    var new_func = function() {
      try {
        return func.apply({}, arguments);
      } finally {
        // this is run before the return above, always
        ManageIQ.qe.debounce -= 1;
      }
    }
    // Override the newly-created fn (prepended wait + original fn)
    // We have to increase the counter before the waiting is initiated
    var debounced_func = orig_debounce.call(this, new_func, wait, options);
    var new_debounced_func = function() {
      ManageIQ.qe.debounce += 1;
      return debounced_func.apply(this, arguments);
    }
    return new_debounced_func;
  }
}
