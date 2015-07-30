(function() {
  'use strict';

  angular.module('app.components')
    .directive('servicesTable', ServicesTableDirective);

  /** @ngInject */
  function ServicesTableDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        services: '='
      },
      link: link,
      templateUrl: 'app/components/services-table/services-table.html',
      controller: ServicesTableController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ServicesTableController() {
      var vm = this;

      vm.activate = activate;

      function activate() {
      }
    }
  }
})();
