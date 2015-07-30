(function() {
  'use strict';

  angular.module('app.components')
    .directive('navItem', NavItemDirective);

  /** @ngInject */
  function NavItemDirective(RecursionHelper) {
    var directive = {
      restrict: 'AE',
      require: '^navigation',
      scope: {
        item: '='
      },
      compile: compile,
      templateUrl: 'app/components/navigation/nav-item.html',
      controller: NavItemController,
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
    function NavItemController() {
      var vm = this;

      vm.activate = activate;

      function activate() {
      }
    }
  }
})();
