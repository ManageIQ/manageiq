(function() {
  'use strict';

  angular.module('app.components').config(productFormDecorator);

  /** @ngInject */
  function productFormDecorator(schemaFormDecoratorsProvider) {
    var base = 'app/components/product-form/controls/';

    schemaFormDecoratorsProvider.createDecorator('productFormDecorator', {
      select: base + 'select.html',
      textarea: base + 'textarea.html',
      'default': base + 'default.html'
    }, []);
  }
})();
