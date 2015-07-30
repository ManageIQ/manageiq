(function() {
  'use strict';

  angular.module('app.components')
    .directive('viewModeSwitch', ViewModeSwitchDirective);

  /** @ngInject */
  function ViewModeSwitchDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        viewMode: '='
      },
      link: link,
      templateUrl: 'app/components/view-mode-switch/view-mode-switch.html',
      controller: ViewModeSwitchController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ViewModeSwitchController(VIEW_MODES) {
      var vm = this;

      vm.activate = activate;
      vm.setViewMode = setViewMode;

      function activate() {
        vm.viewMode = vm.viewMode || VIEW_MODES.grid;
      }

      function setViewMode(mode) {
        if (mode === vm.viewMode) {
          return;
        }
        vm.viewMode = mode;
      }
    }
  }
})();
