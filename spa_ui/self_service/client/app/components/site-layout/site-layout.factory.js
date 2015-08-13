(function() {
  'use strict';

  angular.module('app.components')
    .factory('SiteLayoutService', SiteLayoutFactory);

  /** @ngInject */
  function SiteLayoutFactory($rootScope, $state, logger) {
    var service = {
      setLayout: setLayout,
      getLayout: getLayout,
      getClass: getClass
    };

    var current = 'application';

    return service;

    function setLayout(layout) {
      if (current === layout) {
        return;
      }
      current = layout;
      logger.info('Site layout set to `' + current + '`.');
      $rootScope.$broadcast('siteLayoutChange');
    }

    function getLayout() {
      var layout = current;

      if ($state.current.data && $state.current.data.layout) {
        layout = $state.current.data.layout;
      }

      return 'app/layouts/' + layout + '.html';
    }

    function getClass() {
      return 'layout-' + current;
    }
  }
})();
