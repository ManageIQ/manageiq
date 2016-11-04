ManageIQ.qe.get_debounce_index = function () {
  if (ManageIQ.qe.debounce_counter > 30000) {
    ManageIQ.qe.debounce_counter = 0;
  }
  return ManageIQ.qe.debounce_counter++;
};

if (typeof _ !== 'undefined' && typeof _.debounce !== 'undefined') {
  var orig_debounce = _.debounce;
  _.debounce = function(func, wait, options) {
    var debounce_index = ManageIQ.qe.get_debounce_index();

    // Override the original fn; new_func will be the original fn with wait prepended to it
    // We make sure that once this fn is actually run, it decreases the counter
    var new_func = function() {
      try {
        return func.apply(this, arguments);
      } finally {
        // this is run before the return above, always
        delete ManageIQ.qe.debounced[debounce_index];
      }
    };
    // Override the newly-created fn (prepended wait + original fn)
    // We have to increase the counter before the waiting is initiated
    var debounced_func = orig_debounce.call(this, new_func, wait, options);
    var new_debounced_func = function() {
      ManageIQ.qe.debounced[debounce_index] = 1;
      return debounced_func.apply(this, arguments);
    };
    return new_debounced_func;
  };
}

ManageIQ.qe.xpath = function(root, xpath) {
  if (root == null) {
     root = document;
  }
  return document.evaluate(xpath, root, null,
    XPathResult.ANY_UNORDERED_NODE_TYPE, null).singleNodeValue;
};

ManageIQ.qe.isHidden = function(el) {
  if (el === null) {
    return true;
  }
  return el.offsetParent === null;
};

ManageIQ.qe.setAngularJsValue = function (el, value) {
  var angular_elem = angular.element(elem);
  var $parse = angular_elem.injector().get('$parse');
  var getter = $parse(elem.getAttribute('ng-model'));
  var setter = getter.assign;
  angular_elem.scope().$apply(function($scope) { setter($scope, value); });
};

ManageIQ.qe.anythingInFlight = function() {
  var state = ManageIQ.qe.inFlight();

  return (state.autofocus != 0) ||
    (state.debounce) ||
    (state.document != 'complete') ||
    (state.jquery != 0) ||
    (state.spinner);
};

ManageIQ.qe.spinnerPresent = function() {
  return (!ManageIQ.qe.isHidden(document.getElementById("spinner_div"))) &&
     ManageIQ.qe.isHidden(document.getElementById("lightbox_div"));
};

ManageIQ.qe.debounceRunning = function() {
  return Object.keys(ManageIQ.qe.debounced).length > 0;
};

ManageIQ.qe.inFlight = function() {
  return {
    autofocus:  ManageIQ.qe.autofocus,
    debounce:   ManageIQ.qe.debounceRunning(),
    document:   document.readyState,
    jquery:     $.active,
    spinner:    ManageIQ.qe.spinnerPresent(),
  };
};
