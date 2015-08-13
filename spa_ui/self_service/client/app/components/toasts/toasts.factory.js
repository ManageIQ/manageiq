(function() {
  'use strict';

  angular.module('app.components')
    .factory('Toasts', ToastsFactory);

  /** @ngInject */
  function ToastsFactory(toastr) {
    var service = {
      toast: toast,
      info: info,
      success: success,
      error: error,
      warning: warning
    };

    var defaults = {
      containerId: 'toasts__container',
      positionClass: 'toasts--top-center',
      // Timing
      extendedTimeOut: 1000,
      timeOut: 5000,
      showDuration: 500,
      hideDuration: 500,
      // Classes
      toastClass: 'toasts',
      titleClass: 'toasts__title',
      messageClass: 'toasts__message'
    };

    return service;

    function toast(message, title, options) {
      toastr.info(message, title, angular.extend({}, defaults, options || {iconClass: 'toasts--default'}));
    }

    function info(message, title, options) {
      toastr.info(message, title, angular.extend({}, defaults, options || {iconClass: 'toasts--info'}));
    }

    function success(message, title, options) {
      toastr.success(message, title, angular.extend({}, defaults, options || {iconClass: 'toasts--success'}));
    }

    function error(message, title, options) {
      toastr.error(message, title, angular.extend({}, defaults, options || {iconClass: 'toasts--danger'}));
    }

    function warning(message, title, options) {
      toastr.warning(message, title, angular.extend({}, defaults, options || {iconClass: 'toasts--warning'}));
    }
  }
})();
