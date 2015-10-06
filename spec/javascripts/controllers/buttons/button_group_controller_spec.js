describe('buttonGroupController', function() {
  var $scope, $controller, $httpBackend, miqService;

  beforeEach(module('ManageIQ.angularApplication'));

  beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, _miqService_) {
    miqService = _miqService_;
    $scope = $rootScope.$new();
    $httpBackend = _$httpBackend_;
    $controller = _$controller_('buttonGroupController',
      {$http: $httpBackend, $scope: $scope, miqService: miqService});
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('saveable should exist in the scope', function() {
    it('returns true', function() {
      expect($scope.saveable).toBeDefined();
    });
  });

  describe('disabledClick should exist in the scope', function() {
    it('returns true', function() {
      expect($scope.disabledClick).toBeDefined();
    });
  });
});
