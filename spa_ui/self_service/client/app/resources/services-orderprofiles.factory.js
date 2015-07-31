(function() {
  'use strict';

  angular.module('app.resources')
    .factory('ServicesOrderProfilesCount', ServicesOrderProfilesCountFactory);

  /** @ngInject */
  function ServicesOrderProfilesCountFactory($resource) {
    var ServicesOrderProfilesCount = $resource('/api/v1/services/order_profiles', {});

    return ServicesOrderProfilesCount;
  }
})();

