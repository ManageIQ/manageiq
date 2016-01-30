(function() {
  'use strict';

  angular.module('app')
    .run(init);

  /** @ngInject */
  function init(gettextCatalog, gettext) {
    // prepend [MISSING] to untranslated strings
    gettextCatalog.debug = false;

    gettextCatalog.loadAndSet = function(lang) {
      gettextCatalog.setCurrentLanguage(lang);

      if (lang) {
        gettextCatalog.loadRemote("gettext/json/" + lang + ".json");
      }
    };

    window.N_ = gettext;
    window.__ = gettextCatalog.getString.bind(gettextCatalog);
  }
})();
