(function() {
  'use strict';

  var text = {
    app: {
      name: 'ManageIQ Self Service'
    },
    login: {
      brand: '<strong>ManageIQ</strong> Self Service'
    }
  };

  angular.module('app.skin', [])
    .value('Text', text)
    .config(configure);

  /** @ngInject */
  function configure(routerHelperProvider, exceptionHandlerProvider) {
    exceptionHandlerProvider.configure('[ManageIQ] ');
    routerHelperProvider.configure({docTitle: 'ManageIQ: '});
  }
})();
