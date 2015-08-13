(function() {
  'use strict';

  angular.module('app.services')
    .factory('NotificationsService', NotificationsServiceFactory);

  /** @ngInject */
  function NotificationsServiceFactory() {
    var model = {
      notifications: []
    };

    var service = {
      notifications: model.notifications,
      clear: clear
    };

    init();

    return service;

    function clear() {
      model.notifications.length = 0;
    }

    // Private

    function init() {
      // TODO perhaps use $timeout to fetch new notifications from the server
    }
  }
})();
