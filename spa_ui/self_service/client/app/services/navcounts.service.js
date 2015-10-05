(function() {
  'use strict';

  angular.module('app.services')
    .factory('NavCounts', NavCountsFactory);

  /** @ngInject */
  function NavCountsFactory($interval, CollectionsApi) {
    var model = {};

    var service = {
      getCounts: getCounts
    };

    function getCounts(navItems) {
      model = navItems;

      return model;
    }

    init();

    return service;

    // Private
    function init() {
      updateCounts();
      $interval(updateCounts, 60000);
    }

    function updateCounts() {
      CollectionsApi.query('service_requests').then(setCount);
      CollectionsApi.query('services').then(setCount);
    }

    function setCount(data) {
      if (data.name === 'service_requests') {
        model.requests.count = data.count;
      } else if (data.name === 'services') {
        model.services.count = data.count;
      }
    }
  }
})();
