(function() {
  'use strict';

  angular.module('app.services')
    .factory('Session', SessionFactory);

  /** @ngInject */
  function SessionFactory($http, moment, $sessionStorage, gettextCatalog, lodash) {
    var model = {
      token: null,
      user: {}
    };

    var service = {
      current: model,
      create: create,
      destroy: destroy,
      active: active,
      currentUser: currentUser,
      loadUser: loadUser,
    };

    destroy();

    return service;

    function create(data) {
      model.token = data.auth_token;
      $http.defaults.headers.common['X-Auth-Token'] = model.token;
      $sessionStorage.token = model.token;
    }

    function destroy() {
      model.token = null;
      model.user = {};
      delete $http.defaults.headers.common['X-Auth-Token'];
      delete $sessionStorage.token;
    }

    function loadUser() {
      return $http.get('/api?attributes=authorization')
        .then(function(response) {
          currentUser(response.data.identity);
          setRBAC(response.data.authorization.product_features);

          var locale = response.data.settings && response.data.settings.locale;
          gettextCatalog.loadAndSet(locale);
        });
    }

    function currentUser(user) {
      if (angular.isDefined(user)) {
        model.user = user;
      }

      return model.user;
    }

    function setRBAC(productFeatures) {
      setRBACForActions(productFeatures);
      setRBACForNavigation(productFeatures);
    }

    // Helpers

    function active() {
      // may not be current, but if we have one, we'll rely on API 401ing if it's not
      return model.token;
    }

    function setRBACForNavigation(productFeatures) {
      var features = {
        dashboard: {show: entitledForDashboard(productFeatures)},
        services: {show: entitledForServices(productFeatures)},
        requests: {show: entitledForRequests(productFeatures)},
        marketplace: {show: entitledForServiceCatalogs(productFeatures)}
      };
      model.navFeatures = features;

      return model.navFeatures;
    }

    function setRBACForActions(productFeatures) {
      var features = {
        service_view: {show: angular.isDefined(productFeatures.service_view)},
        service_edit: {show: angular.isDefined(productFeatures.service_edit)},
        service_delete: {show: angular.isDefined(productFeatures.service_delete)},
        service_reconfigure: {show: angular.isDefined(productFeatures.service_reconfigure)},
        service_retire_now: {show: angular.isDefined(productFeatures.service_retire_now)}
      };
      model.actionFeatures = features;

      return model.actionFeatures;
    }

    function entitledForServices(productFeatures) {
      var serviceFeature = lodash.find(model.actionFeatures, function(o) {
        return o.show === true;
      });
      
      return angular.isDefined(serviceFeature);
    }

    function entitledForServiceCatalogs(productFeatures) {
      if (angular.isDefined(productFeatures.svc_catalog_provision)) {
        return true;
      } else {
        return false;
      }
    }

    function entitledForRequests(productFeatures) {
      if (angular.isDefined(productFeatures.miq_request_view)) {
        return true;
      } else {
        return false;
      }
    }

    function entitledForDashboard(productFeatures) {
      if (entitledForServices(productFeatures) ||
          entitledForRequests(productFeatures) ||
          entitledForServiceCatalogs(productFeatures)) {
        return true;
      } else {
        return false;
      }
    }
  }
})();
