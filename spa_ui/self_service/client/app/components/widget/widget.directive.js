(function() {
  'use strict';

  angular.module('app.components')
    .directive('widget', WidgetDirective);

  /** @ngInject */
  function WidgetDirective(MultiTransclude) {
    var directive = {
      restrict: 'AE',
      transclude: true,
      scope: {
        modifier: '@?'
      },
      link: link,
      templateUrl: 'app/components/widget/widget.html',
      controller: WidgetController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      MultiTransclude.transclude(element, transclude, true);
      vm.activate();
    }

    /** @ngInject */
    function WidgetController() {
      var vm = this;

      vm.activate = activate;

      function activate() {
        if (angular.isUndefined(vm.collapsed)) {
          vm.collapsed = false;
        }
      }
    }
  }
})();
