(function() {
  'use strict';

  angular.module('app.config')
    .constant('API_LOGIN', 'admin')
    .constant('API_PASSWORD', 'smartvm')
    .value('API_BASE', 'http://localhost:4000')
    .run(origin);

  /** @ngInject */
  function origin(API_BASE, $location) {
    var host;

    if (null !== API_BASE) {
      return;
    }

    host = $location.protocol() + '//' + $location.host();

    if ('' !== $location.port()) {
      host = host + ':' + $location.port();
    }

    API_BASE = host;
  }
})();
