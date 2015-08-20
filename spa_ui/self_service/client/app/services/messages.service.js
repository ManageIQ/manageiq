(function() {
  'use strict';

  angular.module('app.services')
    .factory('Messages', MessagesFactory);

  /** @ngInject */
  function MessagesFactory() {
    var model = {
      messages: []
    };

    var service = {
      items: model.messages,
      clear: clear
    };

    init();

    return service;

    function clear() {
      model.messages.length = 0;
    }

    // Private

    function init() {
      // TODO perhaps use $timeout to fetch new notifications from the server
    }
  }
})();
