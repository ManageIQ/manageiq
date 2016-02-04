(function() {
  'use strict';

  angular.module('app.skin', [])
    .factory('Text', function() {
      return {
        app: {
          name: __('ManageIQ Self Service'),
        },
        login: {
          brand: '<strong>ManageIQ</strong> ' + __('Self Service'),
        },
      };
    })
    .config(configure);

  /** @ngInject */
  function configure(routerHelperProvider, exceptionHandlerProvider) {
    exceptionHandlerProvider.configure('[ManageIQ] ');
    routerHelperProvider.configure({docTitle: 'ManageIQ: '});
  }
})();
