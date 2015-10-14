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
        templateUrl: 'app/layouts/application.html',
        onEnter: enterApplication,
        onExit: exitApplication
      }
    };
  }

  /** @ngInject */
  function enterApplication(Polling, NavCounts) {
    // Application layout displays the navigation which might have items that require polling to update the counts
    angular.forEach(NavCounts.counts, updateCount);

    function updateCount(count, key) {
      count.func();
      if (count.interval) {
        Polling.start(key, count.func, count.interval);
      }
    }
  }

  /** @ngInject */
  function exitApplication(lodash, Polling, NavCounts) {
    // Remove all of the navigation polls
    angular.forEach(lodash.keys(NavCounts.counts), Polling.stop);
  }
})();
