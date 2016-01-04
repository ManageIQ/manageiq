describe('containerDashboardController', function() {
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
      expect($scope.nodeMemoryUsage.data).not.toEqual(undefined);
      expect($scope.nodeCpuUsage.data).not.toEqual(undefined);
      expect($scope.cpuUsageData).not.toEqual(undefined);
      expect($scope.memoryUsageData).not.toEqual(undefined);
    });
  });
});
