(function() {
  'use strict';

  angular.module('app.components')
    .directive('sidebarItem', SidebarItemDirective);

  /** @ngInject */
  function SidebarItemDirective(RecursionHelper) {
    var directive = {
      restrict: 'AE',
      require: '^navigation',
      scope: {
        item: '='
      },
      compile: compile,
      templateUrl: 'app/components/navigation/sidebar-item.html',
      controller: SidebarItemController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function compile(element) {
      return RecursionHelper.compile(element, link);
    }

    function link(scope, element, attrs, navigation, transclude) {
      var vm = scope.vm;

      vm.activate();
    }

    /** @ngInject */
    function SidebarItemController($state) {
      var vm = this;

      vm.activate = activate;
      vm.isActive = isActive;

      function activate() {
        vm.item.collapsed = !isActive();
      }

      function isActive() {
        return $state.includes(vm.item.state);
      }
    }
  }
})();
