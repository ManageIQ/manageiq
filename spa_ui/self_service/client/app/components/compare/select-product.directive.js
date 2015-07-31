(function() {
  'use strict';

  angular.module('app.components')
    .directive('selectProduct', SelectProductDirective);

  /** @ngInject */
  function SelectProductDirective($position, $window) {
    var directive = {
      restrict: 'AE',
      scope: {
        product: '='
      },
      link: link,
      templateUrl: 'app/components/compare/select-product.html',
      controller: SelectProductController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate({
        getPosition: getPosition,
        getOffset: getOffset
      });

      function getOffset() {
        return $window.pageYOffset;
      }

      function getPosition() {
        return $position.offset(element);
      }
    }

    /** @ngInject */
    function SelectProductController($scope, Compare, $modal) {
      var vm = this;

      vm.activate = activate;
      vm.toggle = toggle;
      vm.isAdded = isAdded;

      function activate(api) {
        angular.extend(vm, api);
      }

      function toggle() {
        if (Compare.contains(vm.product)) {
          Compare.remove(vm.product);
        } else {
          if (!Compare.add(vm.product)) {
            showLimitModal();
          }
        }
      }

      function isAdded() {
        return Compare.contains(vm.product);
      }

      // Private

      function showLimitModal() {
        var modalOptions = {
          templateUrl: 'app/components/compare/limit-modal.html',
          windowTemplateUrl: 'app/components/compare/limit-modal-window.html',
          scope: $scope
        };

        var offset = vm.getPosition();
        var modal = $modal.open(modalOptions);

        vm.left = offset.left + offset.width + 20;
        vm.top = offset.top - 115 - vm.getOffset();

        modal.result.then(showCompareModal);
      }

      function showCompareModal() {
        Compare.showModal();
      }
    }
  }
})();
