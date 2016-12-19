/* global miqSparkleOff */

// CTRL+SHIFT+X stops the spinner
$(document).bind('keyup', 'ctrl+shift+x', miqSparkleOff);

/// Warn for duplicate DOM IDs
(function () {
  var duplicate = function() {
    $('[id]').each(function() {
      var ids = $('[id="' + this.id + '"]');
      if (ids.length > 1 && $.inArray(this, ids) !== -1)
        console.warn('Duplicate DOM ID #' + this.id, this);
    });
  };

  $(duplicate);
  $(document).ajaxComplete(duplicate);
})();

// toast on error
$(function() {
  var orig = {
    error: window.console.error,
    warn: window.console.warn,
  };

  Object.keys(orig).forEach(function(key) {
    window.console[key] = function() {
      orig[key].apply(window.console, arguments);
      window.debug_toast(key, Array.from(arguments));
    };
  });

  window.onerror = function(msg, url, lineNo, columnNo, error) {
    window.debug_toast('error', {
      message: msg,
      url: url,
      lineNo: lineNo,
      columnNo: columnNo,
      error: error,
    });
  };

  window.addEventListener('error', function(ev) {
    window.debug_toast('error', ev);
  }, true);

  window.debug_toast = function (type, data) {
    // Don't display debug toasts if the user doesn't want it
    if (sessionStorage.getItem('disableDebugToasts')) {
      return false;
    }

    if (type == 'warn') {
      type = 'warning';
    }

    // to make sure user can see the whole error even if we show incomplete toast
    console.debug('debug_toast', type, data);

    sendDataWithRx({
      error: {
        type: type,
        data: data,
      },
    });
  };

  var el = $('<toast-wrapper></toast-wrapper>');
  el.appendTo(document.body);
  miq_bootstrap(el, 'miq.debug');
});

angular.module('miq.debug', [])
  .component('toastWrapper', {
    template: [
      '<div class="container miq-toast-wrapper" ng-if="$ctrl.items.length">',
      '  <div class="row">',
      '    <div class="toast-pf alert col-xs-12" ng-click="$ctrl.clear()">',
      '      <span class="pficon pficon-close"></span>',
      '      <a href="">Clear all</a>',
      '      &nbsp;|&nbsp;',
      '      <a href="" ng-click="$ctrl.disable()">Disable notifications</a>',
      '    </div>',
      '  </div>',
      '',
      '  <toast-item ng-repeat="item in $ctrl.items" data="item" close="$ctrl.close"></toast-item>',
      '</div>',
    ].join("\n"),
    controller: ['$timeout', function($timeout) {
      var $ctrl = this;
      this.items = [];

      listenToRx(function(event) {
        if (!event.error || !event.error.data) {
          return;
        }

        $timeout(function() {
          $ctrl.items.push(event.error);
        });
      });

      this.close = function(item) {
        _.remove(this.items, item);
      };

      this.clear = function() {
        _.remove(this.items, _.identity);
      };

      this.disable = function() {
        sessionStorage.setItem('disableDebugToasts', true);
      }
    }],
  })
  .component('toastItem', {
    bindings: {
      data: '<',
      _close: '< close',
    },
    template: [
      '<div class="row">',
      '  <div class="toast-pf alert alert-dismissable col-xs-12" ng-class="$ctrl.alert">',
      '    <button type="button" class="close" data-dismiss="alert" aria-hidden="true" ng-click="$ctrl.close()">',
      '      <span class="pficon pficon-close"></span>',
      '    </button>',
      '    <span ng-class="$ctrl.icon"></span>',
      '    {{$ctrl.message}}',
      '  </div>',
      '</div>',
    ].join("\n"),
    controller: [function() {
      var $ctrl = this;

      var level2class = {
        error: 'alert-danger',
        warning: 'alert-warning',
        info: 'alert-info',
        success: 'alert-success',
      };

      var level2icon = {
        error: 'pficon pficon-error-circle-o',
        warning: 'pficon pficon-warning-triangle-o',
        info: 'pficon pficon-info',
        success: 'pficon pficon-ok',
      };

      var sanitize = function(data) {
        if (_.isPlainObject(data) && (data.error || data.message))
          return (data.error || "").toString() + " " + (data.message || "").toString();

        if (_.isPlainObject(data))
          return JSON.stringify(data);

        if (_.isArray(data) && data.length == 1)
          return sanitize(data[0]);

        if (data.toString().substr(0, 8) === '[object ')
          return "Unknown error, please see the console for details"; // no i18n, devel mode only

        return data.toString();
      };

      this.$onInit = function() {
        $ctrl.icon = level2icon[$ctrl.data.type];
        $ctrl.alert = level2class[$ctrl.data.type];

        $ctrl.message = sanitize($ctrl.data.data);
      };

      this.close = function() {
        $ctrl._close($ctrl.data);
      };
    }],
  });
