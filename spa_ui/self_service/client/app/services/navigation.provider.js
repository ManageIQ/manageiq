(function() {
  'use strict';

  angular.module('app.services')
    .provider('Navigation', NavigationProvider);

  /** @ngInject */
  function NavigationProvider() {
    var provider = {
      $get: Navigation,
      configure: configure
    };

    var model = {
      resizeThrottle: 150,
      breakpoints: {
        tablet: 768,
        desktop: 1024
      },
      items: {
        primary: [],
        secondary: []
      },
      state: {
        isCollapsed: false,
        forceCollapse: false,
        showMobileNav: false,
        isMobileNav: false
      }
    };

    return provider;

    function configure(value) {
      angular.extend(model, value);
    }

    /** @ngInject */
    function Navigation($rootScope, $window, lodash) {
      var service = {
        items: model.items,
        state: model.state
      };
      var win;

      init();

      return service;

      // Private

      function init() {
        win = angular.element($window);
        // Throttle firing of resize checks to reduce application digests
        win.bind('resize', lodash.throttle(onResize, model.resizeThrottle));
        $rootScope.$watch(windowWidth, processWindowWidth, true);
        // Set the initial state
        processWindowWidth(null, win.width());
      }

      function onResize() {
        $rootScope.$apply();
      }

      function windowWidth() {
        return $window.innerWidth;
      }

      function processWindowWidth(oldValue, newValue) {
        var width = newValue;

        // Always remove the hidden & peek class
        model.state.isMobileNav = false;
        model.state.showMobileNav = false;

        // Force collapsed nav state based on developer state
        if (model.state.forceCollapse) {
          model.state.isCollapsed = true;
        } else {
          model.state.isCollapsed = width < model.breakpoints.desktop;
        }

        // Mobile state - must always hide
        if (width < model.breakpoints.tablet) {
          model.state.isMobileNav = true;
          model.state.isCollapsed = false;
        }
      }
    }
  }
})();
