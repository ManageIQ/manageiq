(function() {
  'use strict';

  angular.module('app.config')
    .run(init);

  /** @ngInject */
  function init(routerHelper) {
    routerHelper.configureStates(getLayouts());
  }

  function getLayouts() {
    return {
      'blank': {
        abstract: true,
        templateUrl: 'app/layouts/blank.html'
      },
      'application': {
        abstract: true,
        templateUrl: 'app/layouts/application.html'
      }
    };
  }
})();
