(function() {
  'use strict';

  angular.module('app.components')
    .factory('CatalogService', CatalogServiceFactory);

  /** @ngInject */
  function CatalogServiceFactory($q, ProductCategory, Product, lodash) {
    var service = {
      getCatalog: getCatalog
    };

    return service;

    function getCatalog(tags) {
      var categories = [];
      var products = [];
      var deferred = $q.defer();

      $q.all([
        0 === categories.length ? ProductCategory.query().$promise : angular.noop,
        Product.query({'tags[]': tags}).$promise
      ]).then(buildProductLists);

      return deferred.promise;

      function buildProductLists(results) {
        if (0 === categories.length) {
          categories = results[0];
        }
        products = results[1];
        categories.forEach(filterProductsForCategory);
        deferred.resolve(categories);
      }

      function filterProductsForCategory(category) {
        category.products = lodash.filter(products, matchAllTags);

        function matchAllTags(item) {
          return lodash.all(category.tags, checkTag);

          function checkTag(tag) {
            return -1 !== item.tags.indexOf(tag);
          }
        }
      }
    }
  }
})();
