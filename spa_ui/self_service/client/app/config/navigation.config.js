(function() {
  'use strict';

  angular.module('app.config')
    .config(navigation);

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
})();
