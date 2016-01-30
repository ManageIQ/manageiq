(function() {
  'use strict';

  angular.module('app.core')
    .config(configure)
    .run(init);

  /** @ngInject */
  function configure($logProvider, $compileProvider) {
    $logProvider.debugEnabled(true);
    $compileProvider.debugInfoEnabled(false);
  }

  /** @ngInject */
  function init(logger) {
    logger.showToasts = false;
  }
})();
