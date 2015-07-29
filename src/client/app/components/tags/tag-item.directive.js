(function() {
  'use strict';

  angular.module('app.components')
    .directive('tagItem', TagItemDirective);

  /** @ngInject */
  function TagItemDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        text: '=',
        selected: '=?',
        onRemove: '&'
      },
      link: link,
      templateUrl: 'app/components/tags/tag-item.html',
      controller: TagItemController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function TagItemController($scope) {
      var vm = this;

      vm.tagField = null;

      vm.activate = activate;
      vm.remove = remove;

      function activate() {
        vm.selected = angular.isUndefined(vm.selected) ? false : vm.selected;
      }

      function remove() {
        vm.onRemove();
      }
    }
  }
})();
