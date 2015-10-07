(function() {
  'use strict';

  angular.module('app.components')
    .directive('customButton', CustomButtonDirective);

  /** @ngInject */
  function CustomButtonDirective() {
    var directive = {
      restrict: 'AE',
      replace: true,
      scope: {
        customActions: '=',
        actions: '=?'
      },
      link: link,
      templateUrl: 'app/components/custom-button/custom-button.html',
      controller: CustomButtonController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function CustomButtonController() {
      var vm = this;

      vm.activate = activate;

      function activate() {
      }
    }
  }
})();
