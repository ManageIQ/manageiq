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
    function HeaderNavController(Navigation, NotificationsService) {
      var vm = this;

      vm.activate = activate;
      vm.toggleNavigation = toggleNavigation;
      vm.clearNotifications = clearNotifications;

      function activate() {
        vm.notifications = NotificationsService.notifications;
      }

      function toggleNavigation() {
        Navigation.state.showMobileNav = !Navigation.state.showMobileNav;
      }

      function clearNotifications() {
        NotificationsService.clear();
      }
    }
  }
})();
