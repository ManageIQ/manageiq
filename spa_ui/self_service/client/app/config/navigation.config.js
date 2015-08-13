(function() {
  'use strict';

  angular.module('app.config')
    .config(navigation);

  /** @ngInject */
  function navigation(NavigationProvider) {
    NavigationProvider.configure({
      items: {
        primary: [
          {
            title: 'Dashboard',
            'state': 'dashboard',
            icon: 'fa fa-dashboard'
          },
          {
            title: 'My Services',
            state: 'services',
            icon: 'fa fa-file-o',
            count: 12
          },
          {
            title: 'My Requests',
            state: 'order-history',
            icon: 'fa fa-file-text-o',
            count: 2
          },
          {
            title: 'Service Catalog',
            state: 'marketplace',
            icon: 'fa fa-copy'
          }
        ],
        secondary: [
          {
            title: 'Help',
            icon: 'fa fa-question-circle',
            state: 'help'
          },
          {
            title: 'About Me',
            icon: 'fa fa-user',
            state: 'about-me'
          },
          {
            title: 'Search',
            icon: 'fa fa-search',
            state: 'search'
          }
        ]
      }
    });
  }
})();
