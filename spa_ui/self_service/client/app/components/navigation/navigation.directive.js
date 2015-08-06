(function() {
  'use strict';

  angular.module('app.components')
    .directive('navigation', NavigationDirective);

  /** @ngInject */
  function NavigationDirective(MultiTransclude) {
    var directive = {
      priority: -1,
      restrict: 'AE',
      scope: {
      },
      transclude: true,
      link: link,
      templateUrl: 'app/components/navigation/navigation.html',
      controller: NavigationController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      MultiTransclude.transclude(element, transclude, true);
      vm.activate();
    }

    /** @ngInject */
    function NavigationController($rootScope, navigationHelper) {
      var vm = this;

      vm.navItems = [];
      vm.sidebarItems = [];
      vm.sidebarCollapsed = false;

      vm.activate = activate;
      vm.brandState = brandState;
      vm.navSearch = navigationHelper.navSearch();
      vm.sidebarSearch = navigationHelper.sidebarSearch();

      function activate() {
        $rootScope.$on('$navigationRefresh', reloadNavigation);
        reloadNavigation();
      }

      function brandState() {
        return navigationHelper.brandState();
      }

      // Private

      function reloadNavigation() {
        vm.navItems = navigationHelper.navItems();
        vm.sidebarItems = navigationHelper.sidebarItems();
      }
    }
  }
})();
