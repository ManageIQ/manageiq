(function() {
  'use strict';

  angular.module('app.components')
    .directive('userCatalog', UserCatalogDirective);

  /** @ngInject */
  function UserCatalogDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        users: '=',
        viewMode: '=?',
        collapsed: '=?'
      },
      link: link,
      templateUrl: 'app/components/user-catalog/user-catalog.html',
      controller: UserCatalogController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function UserCatalogController(VIEW_MODES, $state) {
      var vm = this;

      vm.activate = activate;
      vm.goTo = goTo;

      function activate() {
        vm.viewMode = vm.viewMode || VIEW_MODES.list;
        vm.collapsed = angular.isDefined(vm.collapsed) ? vm.collapsed : false;
      }
      function goTo(id) {
        $state.go('admin.user.details', {id: id});
      }
    }
  }
})();
