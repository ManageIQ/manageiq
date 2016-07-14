miqHttpInject(angular.module('miq.provider', ['miqStaticAssets', 'ui.bootstrap', 'ui.router', 'patternfly.select', 'ui.bootstrap.tabs', 'patternfly.views', 'ngAnimate']))
.config(function($stateProvider, $locationProvider, $urlRouterProvider, MiQNewProviderStateServiceProvider) {
  MiQNewProviderStateServiceProvider.$stateProvider = $stateProvider;
  var urlPrefix = '/' + location.pathname.split('/')[1];
  $stateProvider.state('list_providers', {
    url: urlPrefix + '/show_list',
    views: {
      'toolbar': {
        templateUrl: '/static/providers/toolbar.html'
      },
      'content': {
        templateUrl: '/static/providers/list_providers.html'
      }
    }
  })
  .state('list_providers.list', {
    url: '/list',
    templateUrl: '/static/providers/list_providers/list_view.html',
    hasTree: true
  })
  .state('list_providers.tile', {
    url: '/tile',
    templateUrl: '/static/providers/list_providers/tile_view.html',
    hasTree: true
  })
  .state('list_providers.grid', {
    url: '/grid',
    templateUrl: '/static/providers/list_providers/grid_view.html',
    hasTree: true
  })
  .state('new_provider', {
    url: urlPrefix + '/new',
    views: {
      'content': {
        templateUrl: '/static/providers/new_provider/new.html',
        controller: 'miqNewProviderController as mwNew'
      }
    }
  });

  $locationProvider.html5Mode({
    enabled: true,
    requireBase: false
  });
  $urlRouterProvider.otherwise(urlPrefix + '/show_list/list');
  $urlRouterProvider.otherwise(function ($injector, $location) {
    if ($location.hash().length != 0) {
      var rootUrl = $location.path().substring(0, $location.path().lastIndexOf('/'));
      return rootUrl +
        ($location.hash().indexOf('/') !== 0 ? '/' + $location.hash() : $location.hash());
    } else {
      return urlPrefix + '/show_list/list';
    }
  });
});
