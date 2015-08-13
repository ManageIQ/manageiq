(function() {
  'use strict';

  angular.module('blocks.logger')
    .factory('logger', logger);

  /** @ngInject */
  function logger($log, toastr) {
    var service = {
      showToasts: true,

      error: error,
      info: info,
      success: success,
      warning: warning,

      // straight to console; bypass toastr
      log: $log.log
    };

    var options = {
      positionClass: 'toast-bottom-right'
    };

    return service;

    function error(message, data, title) {
      if (service.showToasts) {
        toastr.error(message, title, options);
      }
      $log.error('Error: ' + message, data);
    }

    function info(message, data, title) {
      if (service.showToasts) {
        toastr.info(message, title, options);
      }
      $log.info('Info: ' + message, data);
    }

    function success(message, data, title) {
      if (service.showToasts) {
        toastr.success(message, title, options);
      }
      $log.info('Success: ' + message, data);
    }

    function warning(message, data, title) {
      if (service.showToasts) {
        toastr.warning(message, title, options);
      }
      $log.warn('Warning: ' + message, data);
    }
  }
}());
