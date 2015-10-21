(function() {
  'use strict';

  var text = {
    app: {
      name: 'ManageIQ Self Service'
    },
    login: {
      brand: '<strong>ManageIQ</strong> Self Service',
      message: '<strong>Welcome!</strong> This is placeholder text, only. Use this area to place any ' +
      'information or introductory message about your application that may be relevant for users. For ' +
      'example, you might include news or information about the latest release of your product ' +
      'here&mdash;such as a version number.'
    }
  };

  angular.module('app.skin', [])
    .constant('Text', text)
    .config(configure);

  /** @ngInject */
  function configure(routerHelperProvider, exceptionHandlerProvider) {
    exceptionHandlerProvider.configure('[ManageIQ] ');
    routerHelperProvider.configure({docTitle: 'ManageIQ: '});
  }
})();
