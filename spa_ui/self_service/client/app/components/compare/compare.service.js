(function() {
  'use strict';

  angular.module('app.components')
    .service('Compare', CompareService);

  /** @ngInject */
  function CompareService($modal, lodash, MAX_COMPARES) {
    var self = this;

    self.items = [];

    self.add = add;
    self.remove = remove;
    self.clear = clear;
    self.contains = inList;
    self.showModal = showModal;

    function add(product) {
      if (isValid(product)) {
        self.items.push(product);

        return true;
      }

      return false;
    }

    function remove(product) {
      var index = indexOf(product);

      if (index >= 0) {
        self.items.splice(index, 1);

        return true;
      }

      return false;
    }

    function clear() {
      self.items.length = 0;
    }

    function inList(product) {
      return indexOf(product) !== -1;
    }

    function indexOf(product) {
      return lodash.pluck(self.items, 'id').indexOf(product.id);
    }

    function isValid(product) {
      return self.items.length < MAX_COMPARES && !inList(product);
    }

    function showModal(project) {
      var modalOptions = {
        templateUrl: 'app/components/compare/compare-modal.html',
        controller: CompareModalController,
        controllerAs: 'vm',
        resolve: {
          productList: resolveItems,
          project: resolveProject
        },
        windowTemplateUrl: 'app/components/compare/compare-modal-window.html'
      };
      var modal = $modal.open(modalOptions);

      modal.result.then();

      function resolveItems() {
        return self.items;
      }

      function resolveProject() {
        return project;
      }
    }
  }

  /** @ngInject */
  function CompareModalController(lodash, productList, project) {
    var vm = this;

    vm.products = productList;
    vm.rowData = [];

    buildData();

    function buildData() {
      var properties = [];
      var data = {
        description: [],
        setup: [],
        hourly: [],
        monthly: [],
        properties: {}
      };

      angular.forEach(productList, processBasics);
      vm.rowData.push({name: 'Description', values: data.description});
      properties = lodash.uniq(properties.sort(), true);
      angular.forEach(properties, initProperty);
      angular.forEach(productList, processProperties);
      angular.forEach(properties, appendProperty);
      vm.rowData.push({name: 'Setup', values: data.setup});
      vm.rowData.push({name: 'Hourly', values: data.hourly});
      vm.rowData.push({name: 'Monthly', values: data.monthly});

      function processBasics(product) {
        data.description.push(product.description);
        data.setup.push(product.setup_price);
        data.hourly.push(product.hourly_price);
        data.monthly.push(product.monthly_price);
        properties = properties.concat(lodash.keys(product.properties));
      }

      function initProperty(property) {
        data.properties[property] = {name: lodash.startCase(property), values: []};
      }

      function processProperties(product) {
        for (var idx = properties.length; --idx >= 0;) {
          data.properties[properties[idx]].values.push(product.properties[properties[idx]]);
        }
      }

      function appendProperty(property) {
        vm.rowData.push(data.properties[property]);
      }

      function isPurchasable() {
        return angular.isDefined(project);
      }
    }
  }
})();
