(function() {
  'use strict';

  angular.module('app.components')
    .directive('headerNav', HeaderNavDirective);

  /** @ngInject */
  function HeaderNavDirective() {
    var directive = {
      restrict: 'AE',
      replace: true,
      scope: {},
      link: link,
      templateUrl: 'app/components/navigation/header-nav.html',
      controller: HeaderNavController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function HeaderNavController(Navigation, Messages) {
      var vm = this;

      vm.activate = activate;
      vm.toggleNavigation = toggleNavigation;
      vm.clearMessages = clearMessages;

      function activate() {
        vm.messages = Messages.items;
      }

      function toggleNavigation() {
        if (!Navigation.state.isMobileNav) {
            Navigation.state.isCollapsed = !Navigation.state.isCollapsed; 
            Navigation.state.forceCollapse = true;
          } else {
            Navigation.state.showMobileNav = !Navigation.state.showMobileNav;
          }
      }

      function clearMessages() {
        Messages.clear();
      }
    }
  }
})();
