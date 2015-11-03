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
            title: 'Dashboard',
            state: 'dashboard',
            icon: 'fa fa-dashboard'
          },
          services: {
            title: 'My Services',
            state: 'services',
            icon: 'fa fa-file-o',
            tooltip: 'The total number of services that you have ordered, both active and retired'
          },
          requests: {
            title: 'My Requests',
            state: 'requests',
            icon: 'fa fa-file-text-o',
            tooltip: 'The total number of requests that you have submitted'
          },
          marketplace: {
            title: 'Service Catalog',
            state: 'marketplace',
            icon: 'fa fa-copy',
            tooltip: 'The total number of available catalog items'
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
      CollectionsApi.query('service_requests').then(lodash.partial(updateCount, 'requests'));
    }

    function fetchServices() {
      CollectionsApi.query('services').then(lodash.partial(updateCount, 'services'));
    }

    function fetchServiceTemplates() {
      CollectionsApi.query('service_templates').then(lodash.partial(updateCount, 'marketplace'));
    }

    function updateCount(item, data) {
      Navigation.items.primary[item].count = data.count;
    }
  }
})();
