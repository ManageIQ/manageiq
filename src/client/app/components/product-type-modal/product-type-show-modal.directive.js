(function() {
  'use strict';

  angular.module('app.components')
    .directive('productTypeShowModal', ProductTypeShowModalDirective);

  /** @ngInject */
  function ProductTypeShowModalDirective(DirectiveOptions) {
    var directive = {
      restrict: 'AE',
      scope: {
        productTypes: '=?',
        onOk: '&'
      },
      link: link,
      transclude: true,
      templateUrl: 'app/components/product-type-modal/product-type-show-modal.html',
      controller: ProductTypeShowModalController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, tagField, transclude) {
      var vm = scope.vm;

      DirectiveOptions.load(vm, attrs, {
        title: [String, 'Select Product Type'],
        heading: [String, 'Select Product Type'],
        message: [String, 'Select the product type.']
      });

      vm.activate(tagField);
    }

    /** @ngInject */
    function ProductTypeShowModalController($modal) {
      var vm = this;

      var modalOptions = {};

      vm.activate = activate;
      vm.showModal = showModal;

      function activate() {
        modalOptions = {
          templateUrl: 'app/components/product-type-modal/product-type-modal.html',
          controller: ProductTypeModalController,
          controllerAs: 'vm',
          resolve: {
            productTypes: resolveProductTypes,
            text: resolveText
          },
          windowTemplateUrl: 'app/components/product-type-modal/product-type-modal-window.html'
        };
      }

      function showModal() {
        var modal = $modal.open(modalOptions);

        modal.result.then(handleOk);

        function handleOk(productType) {
          vm.onOk({productType: productType});
        }
      }

      // Private

      /** @ngInject */
      function resolveProductTypes(ProductType) {
        if (vm.productTypes) {
          return vm.productTypes;
        } else {
          return ProductType.query().$promise;
        }
      }

      function resolveText() {
        return {
          heading: vm.options.heading,
          message: vm.options.message
        };
      }
    }

    /** @ngInject */
    function ProductTypeModalController(productTypes, text) {
      var vm = this;

      vm.productTypes = productTypes;
      vm.heading = text.heading;
      vm.message = text.message;
    }
  }
})();
