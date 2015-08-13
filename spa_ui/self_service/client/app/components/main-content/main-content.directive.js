(function() {
  'use strict';

  angular.module('app.components')
    .directive('mainContent', MainContentDirective);

  /** @ngInject */
  function MainContentDirective() {
    var directive = {
      restrict: 'AE',
      replace: true,
      scope: {},
      link: link,
      templateUrl: 'app/components/main-content/main-content.html',
      controller: MainContentController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function MainContentController(Navigation) {
      var vm = this;

      vm.activate = activate;

      function activate() {
        vm.state = Navigation.state;
      }
    }
  }
})();
