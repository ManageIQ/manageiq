(function() {
  'use strict';

  angular.module('app')
    .run(init);

  /** @ngInject */
  function init(gettextCatalog) {
    // prepend [MISSING] to untranslated strings
    gettextCatalog.debug = false;

    gettextCatalog.loadAndSet = function(lang) {
      gettextCatalog.setCurrentLanguage(lang);
      gettextCatalog.loadRemote("gettext/json/" + lang + ".json");
    };
  };
})();
