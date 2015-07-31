(function() {
  'use strict';

  angular.module('app.resources')
    .factory('ServicesAllCount', ServicesAllCountFactory);

  /** @ngInject */
  function ServicesAllCountFactory($resource) {
    var ServicesAllCount = $resource('/api/v1/services/all_count', {});

    return ServicesAllCount;
  }
})();
