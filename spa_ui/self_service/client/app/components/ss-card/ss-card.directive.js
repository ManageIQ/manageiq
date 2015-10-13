(function() {
  'use strict';

  angular.module('app.components')
    .directive('ssCard', SsCardDirective);

  /** @ngInject */
  function SsCardDirective() {
    var directive = {
      restrict: 'AE',
      replace: true,
      scope: {
        title: '@heading',
        description: '@',
        more: '@',
        img: '@?'
      },
      link: link,
      templateUrl: 'app/components/ss-card/ss-card.html',
      controller: SsCardController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function SsCardController() {
      var vm = this;

      vm.activate = activate;

      function activate() {
      }
    }
  }
})();
