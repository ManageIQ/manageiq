miqHttpInject(
  angular.module('ManageIQ.gtl', [
    'miqStaticAssets', 'ui.bootstrap', 'patternfly.views'
  ])
  .config(['$locationProvider', function ($locationProvider) {
    $locationProvider.html5Mode({
      enabled: true,
      requireBase: false
    })
  }])
);
