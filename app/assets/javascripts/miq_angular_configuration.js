ManageIQ.angular.app.config([ '$httpProvider', '$stateProvider', '$urlRouterProvider', '$locationProvider', function ($httpProvider, $stateProvider, $urlRouterProvider, $locationProvider) {
  /**
   * Routes and States for Repository
   */
  $stateProvider
    .state('edit', {
      url: '/ems_cloud/arbitration_profile_edit/:ems_id?show',
      templateUrl: 'ems_cloud/arbitration_profile_edit.html',
      controller: 'arbitrationProfileFormController',
      resolve: {
        arbitrationProfileData: function (arbitrationProfileDataFactory, $stateParams) {
          return arbitrationProfileDataFactory.getArbitrationProfileData($stateParams.ems_id, $stateParams.show);
        },
        arbitrationProfileOptions: function (arbitrationProfileDataFactory, $stateParams) {
          return arbitrationProfileDataFactory.getArbitrationProfileOptions($stateParams.ems_id);
        }
      }
    });
  $stateProvider
    .state("otherwise", {
      url: "*path"
    });

  // default fall back route
  //$urlRouterProvider.otherwise('/');

  // enable HTML5 Mode for SEO
  $locationProvider.html5Mode({enabled: true,requireBase: false});
}]);

ManageIQ.angular.app.run(['$rootScope', 'miqService', '$window', function($rootScope, miqService, $window) {
  var otherwisePath, newUrlPath;
  $rootScope.$on('$stateChangeStart', function(event, toState, toParams, fromState, fromParams) {
    if (toState.name === "otherwise") {
      event.preventDefault();
      otherwisePath = newUrlPath;
    }
    else {
      miqService.sparkleOn();
    }
  });

  $rootScope.$on('$stateChangeSuccess', function(event, toState, toParams, fromState, fromParams) {
    miqService.sparkleOff();
  });

  $rootScope.$on('$locationChangeSuccess', function(event, newURL, oldURL, newState, oldState) {
    if (angular.isDefined(otherwisePath) && $window.location.pathname != otherwisePath ) {
      miqService.sparkleOn();
      $window.location.href = otherwisePath;
    } else {
      newUrlPath = newURL;
    }
  });
}]);

