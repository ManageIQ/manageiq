(function() {
  'use strict';

  angular.module('app.components')
    .directive('navProfile', NavProfileDirective);

  /** @ngInject */
  function NavProfileDirective() {
    var directive = {
      restrict: 'AE',
      scope: {},
      link: link,
      templateUrl: 'app/components/profile/nav-profile.html',
      controller: NavProfileController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function NavProfileController(SessionService) {
      var vm = this;

      vm.alerts = [];

      vm.activate = activate;

      function activate() {
        vm.name = SessionService.fullName();
      }
    }
  }
})();
