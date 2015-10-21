(function() {
  'use strict';

  var config = {
    appErrorPrefix: '[ManageIQ] ',
    appTitle: 'ManageIQ'
  };

  angular.module('app.skin', [])
    .config(configure);

  /** @ngInject */
  function configure(routerHelperProvider, exceptionHandlerProvider) {
    exceptionHandlerProvider.configure(config.appErrorPrefix);
    routerHelperProvider.configure({docTitle: config.appTitle + ': '});
  }
})();
