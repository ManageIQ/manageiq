describe('containerDashboardController gets data and', function() {
  var $scope, $controller, $httpBackend;
  var mock_data = getJSONFixture('container_dashboard_response.json');

  beforeEach(module('containerDashboard'));

  beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, $location) {
    var dummyDocument = document.createElement('div');
    spyOn(document, 'getElementById').and.returnValue(dummyDocument);
    spyOn($location, 'absUrl').and.returnValue('/container_dashboard/show');
    $scope = $rootScope.$new();

    $httpBackend = _$httpBackend_;
    $httpBackend.when('GET','/container_dashboard/data').respond(mock_data);
    $controller = _$controller_('containerDashboardController',
      {$scope: $scope});
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
      expect($scope.nodeMemoryUsage.data).toBeDefined();
      expect($scope.nodeCpuUsage.data).toBeDefined();
      expect($scope.cpuUsageData).toBeDefined();
      expect($scope.memoryUsageData).toBeDefined();
    });

    it('in network metrics', function() {
      expect($scope.dailyNetworkUtilization).toBeDefined();
    });

    it('in pod metrics', function() {
      expect($scope.dailyPodEntityTrend).toBeDefined();
    });
  });
});

describe('containerDashboardController gets no data and', function() {
  var $scope, $controller, $httpBackend;
  var mock_data = getJSONFixture('container_dashboard_no_data_response.json');

  beforeEach(module('containerDashboard'));

  beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, $location) {
    var dummyDocument = document.createElement('div');
    spyOn(document, 'getElementById').and.returnValue(dummyDocument);
    spyOn($location, 'absUrl').and.returnValue('/container_dashboard/show');
    $scope = $rootScope.$new();

    $httpBackend = _$httpBackend_;
    $httpBackend.when('GET','/container_dashboard/data').respond(mock_data);
    $controller = _$controller_('containerDashboardController',
      {$scope: $scope});
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
      expect($scope.nodeMemoryUsage.dataAvailable).toBeDefined();
      expect($scope.nodeCpuUsage.dataAvailable).toBeDefined();
      expect($scope.cpuUsageData.dataAvailable).toBeDefined();
      expect($scope.memoryUsageData.dataAvailable).toBeDefined();
    });

    it('in network metrics', function() {
      expect($scope.dailyNetworkUtilization.dataAvailable).toBeDefined();
    });

    it('in pod metrics', function() {
      expect($scope.dailyPodEntityTrend.dataAvailable).toBeDefined();
    });
  });
});
