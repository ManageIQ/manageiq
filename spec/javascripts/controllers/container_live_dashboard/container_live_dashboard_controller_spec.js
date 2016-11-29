describe('containerLiveDashboardController', function() {
  var $scope, $controller, $httpBackend, pfViewUtils;
  var mock_data = getJSONFixture('container_live_dashboard_response.json');
  var mock_metrics_data = getJSONFixture('container_live_dashboard_metrics_response.json');
  var mock_data1_data = getJSONFixture('container_live_dashboard_data1_response.json');
  var mock_data2_data = getJSONFixture('container_live_dashboard_data2_response.json');

  beforeEach(module('containerLiveDashboard'));

  beforeEach(function() {
    var $window = {location: { pathname: '/ems_container/42' }};
    module(function($provide) {
      $provide.value('$window', $window);
    });
  });

  beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, _pfViewUtils_) {
    pfViewUtils = _pfViewUtils_;
    $scope = $rootScope.$new();
    $httpBackend = _$httpBackend_;
    $httpBackend.when('GET','/container_dashboard/data/42/?live=true&tenant=_ops&query=metric_tags').respond(mock_data);
    $httpBackend.when('GET','/container_dashboard/data/42/?live=true&tenant=_ops&query=metric_definitions&tags={}').respond(mock_metrics_data);
    $httpBackend.when('GET','/container_dashboard/data/42/?live=true&tenant=_ops&query=get_data&metric_id=hello1&limit=5&order=DESC').respond(mock_data1_data);
    $httpBackend.when('GET','/container_dashboard/data/42/?live=true&tenant=_ops&query=get_data&metric_id=hello2&limit=5&order=DESC').respond(mock_data2_data);
    $controller = _$controller_('containerLiveDashboardController', {
        $scope: $scope,
        pfViewUtils: pfViewUtils
    });
    $scope.refresh();
    $httpBackend.flush();
  }));

  afterEach(function() {
      $httpBackend.verifyNoOutstandingExpectation();
      $httpBackend.verifyNoOutstandingRequest();
  });

  describe('loading page data', function() {
    it('should load tag list', function() {
      expect($scope.filterConfig.fields.length).toBe(12);
    });

    it('should load metrics definitions', function() {
      expect($scope.loadingMetrics).toBeDefined();
      expect($scope.loadingMetrics).toBe(false);
      expect($scope.items.length).toBe(2);
    });
  });

  describe('count increment', function() {    
    it('should increment the count', function() {
      $scope.countIncrement();
      expect($scope.timeFilter.range_count).toBe(2);
    });

    it('should decrement the count', function() {
      $scope.timeFilter.range_count = 10;
      $scope.countDecrement();
      expect($scope.timeFilter.range_count).toBe(9);
    });
  });

  describe('check numeric formater', function() {    
    it('should fomrat numbers correctly', function() {
      expect($scope.items[0].lastValues[1480424640000]).toBe("10.00");
      expect($scope.items[0].lastValues[1480424630000]).toBe("1.01k");
      expect($scope.items[0].lastValues[1480424620000]).toBe("20.00t");
    });
  });
});
