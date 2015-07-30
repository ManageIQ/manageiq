(function() {
  'use strict';

  angular.module('app.components')
    .factory('CartService', CartServiceFactory);

  /** @ngInject */
  function CartServiceFactory(SessionService, Order, Toasts, $modal, lodash) {
    var service = {
      items: {},
      itemCount: 0,
      add: add,
      remove: remove,
      quantity: quantity,
      clear: clear,
      isEmpty: isEmpty,
      showModal: showModal
    };

    return service;

    function add(project, product, quantity) {
      quantity = isNaN(quantity) ? 1 : quantity;

      if (angular.isUndefined(service.items[project.id])) {
        service.items[project.id] = {
          project: project,
          products: {},
          total: 0
        };
      }

      if (angular.isUndefined(service.items[project.id].products[product.id])) {
        service.items[project.id].products[product.id] = {
          product: product,
          quantity: 0,
          price: 0
        };
      }

      service.items[project.id].products[product.id].quantity += quantity;
      service.itemCount += quantity;

      totalUpProject(project);
      Toasts.toast(product.name + ' has been add to your cart.');
    }

    function remove(project, product) {
      if (!inCart(project, product)) {
        return;
      }

      service.items[project.id].products[product.id].quantity -= 1;
      service.itemCount -= 1;

      if (0 === service.items[project.id].products[product.id].quantity) {
        delete service.items[project.id].products[product.id];

        if (0 === Object.keys(service.items[project.id].products).length) {
          delete service.items[project.id];
        }
      }

      totalUpProject(project);
    }

    function quantity(project, product) {
      if (!inCart(project, product)) {
        return 0;
      }

      return service.items[project.id].products[product.id].quantity;
    }

    function clear() {
      service.items = {};
      service.itemCount = 0;
    }

    function isEmpty() {
      return 0 === Object.keys(service.items).length;
    }

    function showModal() {
      var modalOptions = {
        templateUrl: 'app/components/cart/cart-modal.html',
        controller: CartModalController,
        controllerAs: 'vm',
        windowTemplateUrl: 'app/components/cart/cart-modal-window.html'
      };
      var modal = $modal.open(modalOptions);

      modal.result.then(handleCheckout);

      function handleCheckout() {
        var order = {
          staff_id: SessionService.id,
          order_items: lodash.flatten(lodash.map(service.items, eachProject))
        };

        Order.save(order, saveSuccess, saveError);

        function eachProject(item) {
          return lodash.flatten(lodash.map(item.products, eachProduct));

          function eachProduct(row) {
            return lodash.times(row.quantity, asOrderItem);

            function asOrderItem() {
              return {
                project_id: item.project.id,
                product_id: row.product.id
              };
            }
          }
        }

        function saveSuccess() {
          clear();
          Toasts.toast('Order accepted.');
        }

        function saveError() {
          Toasts.error('Could not place order at this time.');
        }
      }
    }

    function inCart(project, product) {
      return service.items[project.id] && service.items[project.id].products[product.id];
    }

    function totalUpProject(project) {
      if (angular.isUndefined(service.items[project.id])) {
        return;
      }

      service.items[project.id].total = 0;
      angular.forEach(service.items[project.id].products, computeProductTotal);

      function computeProductTotal(line) {
        line.price = (parseFloat(line.product.monthly_price))
          + ((parseFloat(line.product.hourly_price)) * 750)
          * line.quantity;

        service.items[project.id].total += line.price;
      }
    }
  }

  /** @ngInject */
  function CartModalController(CartService) {
    var vm = this;

    vm.remove = remove;
    vm.change = change;
    vm.clear = clear;
    vm.isEmpty = isEmpty;

    vm.items = CartService.items;

    function remove(project, product) {
      CartService.remove(project, product);
    }

    function change(project, product) {
      // TODO: Change quantity and re-compute totals.
    }

    function clear() {
      CartService.clear();
    }

    function isEmpty() {
      return CartService.isEmpty();
    }
  }
})();
