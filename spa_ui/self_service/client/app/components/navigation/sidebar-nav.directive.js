(function() {
  'use strict';

  angular.module('app.components')
    .directive('sidebarNav', SidebarNavDirective);

  /** @ngInject */
  function SidebarNavDirective() {
    var directive = {
      restrict: 'AE',
      replace: true,
      scope: {},
      link: link,
      templateUrl: 'app/components/navigation/sidebar-nav.html',
      controller: SidebarNavController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function SidebarNavController(Navigation) {
      var vm = this;

      vm.activate = activate;
      vm.navigate = navigate;

      function activate() {
        vm.state = Navigation.state;
        vm.items = Navigation.items;
      }

      function navigate(item) {
        Navigation.state.showMobileNav = false;
      }
    }
  }
})();
