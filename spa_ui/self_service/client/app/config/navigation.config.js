(function() {
  'use strict';

  angular.module('app.config')
    .config(navigation)
    .run(init);

  /** @ngInject */
  function navigation(NavigationProvider) {
    NavigationProvider.configure({
      items: {
        primary: {
          dashboard: {
            title: N_('Dashboard'),
            state: 'dashboard',
            icon: 'fa fa-dashboard',
          },
          services: {
            title: N_('My Services'),
            state: 'services',
            icon: 'fa fa-file-o',
            tooltip: N_('The total number of services that you have ordered, both active and retired'),
          },
          requests: {
            title: N_('My Requests'),
            state: 'requests',
            icon: 'fa fa-file-text-o',
            tooltip: N_('The total number of requests that you have submitted'),
          },
          marketplace: {
            title: N_('Service Catalog'),
            state: 'marketplace',
            icon: 'fa fa-copy',
            tooltip: N_('The total number of available catalog items'),
          }
        },
        secondary: {
        }
      }
    });
  }

  /** @ngInject */
  function init(lodash, CollectionsApi, Navigation, NavCounts) {
    NavCounts.add('services', fetchServices, 60 * 1000);
    NavCounts.add('requests', fetchRequests, 60 * 1000);
    NavCounts.add('marketplace', fetchServiceTemplates, 60 * 1000);

    function fetchRequests() {
      var options = {
        auto_refresh: true,
      };

      CollectionsApi.query('service_requests', options)
        .then(lodash.partial(updateCount, 'requests'));
    }

    function fetchServices() {
      var options = {
        expand: false,
        filter: ['service_id>0'],
        auto_refresh: true,
      };

      CollectionsApi.query('services', options)
        .then(lodash.partial(updateServicesCount, 'services'));
    }

    function fetchServiceTemplates() {
      var options = {
        expand: false,
        filter: ['service_template_catalog_id>0', 'display=true'],
        auto_refresh: true,
      };

      CollectionsApi.query('service_templates', options)
        .then(lodash.partial(updateServiceTemplatesCount, 'marketplace'));
    }

    function updateCount(item, data) {
      Navigation.items.primary[item].count = data.count;
    }

    function updateServicesCount(item, data) {
      Navigation.items.primary[item].count = data.count - data.subcount;
    }

    function updateServiceTemplatesCount(item, data) {
      Navigation.items.primary[item].count = data.subcount;
    }
  }
})();
