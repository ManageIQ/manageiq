(function() {
  'use strict';

  var config = {
    appErrorPrefix: '[Jellyfish] ',
    appTitle: 'Jellyfish'
  };

  angular.module('app.core')
    .value('config', config)
    .config(configure)
    .run(init);

  /** @ngInject */
  function configure($logProvider, routerHelperProvider, exceptionHandlerProvider, $compileProvider) {
    exceptionHandlerProvider.configure(config.appErrorPrefix);
    routerHelperProvider.configure({docTitle: config.appTitle + ': '});

    $logProvider.debugEnabled(true);
    $compileProvider.debugInfoEnabled(false);
  }

  /** @ngInject */
  function init(logger) {
    logger.showToasts = false;
  }
})();
