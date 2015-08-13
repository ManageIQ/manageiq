(function() {
  'use strict';

  angular.module('app.components')
    .directive('siteLayout', SiteLayoutDirective);

  /** @ngInject */
  function SiteLayoutDirective() {
    var directive = {
      restrict: 'AE',
      scope: {},
      replace: true,
      template: '<div ng-class="vm.layoutClass" ng-include="vm.layout"></div>',
      controller: SiteLayoutController,
      controllerAs: 'vm'
    };

    return directive;

    /** @ngInject */
    function SiteLayoutController($rootScope, SiteLayoutService) {
      var vm = this;

      $rootScope.$on('$stateChangeSuccess', setLayout);
      $rootScope.$on('siteLayoutChange', setLayout);

      function setLayout() {
        vm.layout = SiteLayoutService.getLayout();
        vm.layoutClass = SiteLayoutService.getClass();
      }
    }
  }
})();
