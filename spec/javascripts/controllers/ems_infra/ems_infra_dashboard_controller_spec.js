describe('emsInfraDashboardController gets data and', function() {
  var $scope, $controller, $httpBackend, infraDashboardUtilsFactory;
  var mock_data = getJSONFixture('ems_infra_dashboard_response.json');

  beforeEach(module('emsInfraDashboard'));

  beforeEach(function() {
    var $window = {location: { pathname: '/ems_infra_dashboard/show' }};

    module(function($provide) {
      $provide.value('$window', $window);
    });
  });

  beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, _infraDashboardUtilsFactory_) {
    var dummyDocument = document.createElement('div');
    spyOn(document, 'getElementById').and.returnValue(dummyDocument);
    $scope = $rootScope.$new();
    infraDashboardUtilsFactory = _infraDashboardUtilsFactory_;

    $httpBackend = _$httpBackend_;
    $httpBackend.when('GET','/ems_infra_dashboard/data').respond(mock_data);
    $controller = _$controller_('emsInfraDashboardController',
      {$scope: $scope,
        infraDashboardUtilsFactory: infraDashboardUtilsFactory
      });
    $httpBackend.flush();
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('data loads successfully', function() {
    it('in object statuses', function() {
      for (var entity in $scope.objectStatus) {
        expect($scope.objectStatus[entity].count).toBeGreaterThan(0);
      };
    });

    it('in heatmaps and donut', function() {
      expect($scope.clusterMemoryUsage.data).toBeDefined();
      expect($scope.clusterCpuUsage.data).toBeDefined();
      expect($scope.cpuUsageData).toBeDefined();
      expect($scope.memoryUsageData).toBeDefined();
    });

  });
});

describe('emsInfraDashboardController gets no data and', function() {
  var $scope, $controller, $httpBackend, infraDashboardUtilsFactory;
  var mock_data = getJSONFixture('ems_infra_dashboard_no_data_response.json');

  beforeEach(module('emsInfraDashboard'));

  beforeEach(function() {
    var $window = {location: { pathname: '/ems_infra_dashboard/show' }};

    module(function($provide) {
      $provide.value('$window', $window);
    });
  });

  beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, _infraDashboardUtilsFactory_) {
    var dummyDocument = document.createElement('div');
    spyOn(document, 'getElementById').and.returnValue(dummyDocument);
    $scope = $rootScope.$new();
    infraDashboardUtilsFactory = _infraDashboardUtilsFactory_;

    $httpBackend = _$httpBackend_;
    $httpBackend.when('GET','/ems_infra_dashboard/data').respond(mock_data);
    $controller = _$controller_('emsInfraDashboardController',
      {$scope: $scope,
      infraDashboardUtilsFactory: infraDashboardUtilsFactory
      });
    $httpBackend.flush();
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('data loads successfully', function() {
    it('in object statuses', function() {
      for (var entity in $scope.objectStatus) {
        expect($scope.objectStatus[entity].count).toBeGreaterThan(0);
      };
    });

    it('in heatmaps and donut', function() {
      expect($scope.clusterMemoryUsage.dataAvailable).toBeDefined();
      expect($scope.clusterCpuUsage.dataAvailable).toBeDefined();
      expect($scope.cpuUsageData.dataAvailable).toBeDefined();
      expect($scope.memoryUsageData.dataAvailable).toBeDefined();
    });
  });
});

describe('emsInfraDashboardController gets data for one provider and', function() {
  var $scope, $controller, $httpBackend, infraDashboardUtilsFactory;
  var mock_data = getJSONFixture('ems_infra_dashboard_response.json');

  beforeEach(module('emsInfraDashboard'));

  beforeEach(function() {
    var $window = {location: { pathname: '/ems_infra/42' }};

    module(function($provide) {
      $provide.value('$window', $window);
    });
  });

  beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, _infraDashboardUtilsFactory_) {
    var dummyDocument = document.createElement('div');
    spyOn(document, 'getElementById').and.returnValue(dummyDocument);
    $scope = $rootScope.$new();
    infraDashboardUtilsFactory = _infraDashboardUtilsFactory_;

    $httpBackend = _$httpBackend_;
    $httpBackend.when('GET','/ems_infra_dashboard/data/42').respond(mock_data);
    $controller = _$controller_('emsInfraDashboardController',
      {$scope: $scope,
        infraDashboardUtilsFactory: infraDashboardUtilsFactory
      });
    $httpBackend.flush();
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('data loads successfully', function() {
    it('in single provider', function() {
      expect($scope.isSingleProvider).toBe(true);
    });

    it('in heatmaps and donut', function() {
      expect($scope.clusterMemoryUsage.data).toBeDefined();
      expect($scope.clusterCpuUsage.data).toBeDefined();
      expect($scope.cpuUsageData).toBeDefined();
      expect($scope.memoryUsageData).toBeDefined();
    });
  });
});
