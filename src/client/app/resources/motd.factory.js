(function() {
  'use strict';

  angular.module('app.resources')
    .factory('Motd', MotdFactory);

  /** @ngInject */
  function MotdFactory($resource) {
    var Motd = $resource('/api/v1/motd/', {});

    return Motd;
  }
})();
