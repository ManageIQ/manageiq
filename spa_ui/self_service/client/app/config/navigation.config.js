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
            icon: 'fa fa-file-o'
          },
          requests: {
            title: 'My Requests',
            state: 'requests',
            icon: 'fa fa-file-text-o'
          },
          marketplace: {
            title: 'Service Catalog',
            state: 'marketplace',
            icon: 'fa fa-copy'
          }
        },
        secondary: {
          help: {
            title: 'Help',
            icon: 'fa fa-question-circle',
            state: 'help'
          },
          about: {
            title: 'About Me',
            icon: 'fa fa-user',
            state: 'about-me'
          },
          search: {
            title: 'Search',
            icon: 'fa fa-search',
            state: 'search'
          }
        }
      }
    });
  }

  /** @ngInject */
  function init(lodash, CollectionsApi, Navigation, NavCounts) {
    NavCounts.add('services', fetchServices, 60 * 1000);
    NavCounts.add('requests', fetchRequests, 60 * 1000);

    function fetchRequests() {
      CollectionsApi.query('service_requests').then(lodash.partial(updateCount, 'requests'));
    }

    function fetchServices() {
      CollectionsApi.query('services').then(lodash.partial(updateCount, 'services'));
    }

    function updateCount(item, data) {
      Navigation.items.primary[item].count = data.count;
    }
  }
})();
