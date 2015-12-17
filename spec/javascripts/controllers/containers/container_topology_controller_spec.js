describe('containerTopologyController', function() {
    var $scope, $controller, $httpBackend;
    var mock_data =  getJSONFixture('container_topology_response.json');

    beforeEach(module('topologyApp'));

    beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, $location) {
        spyOn($location, 'absUrl').and.returnValue('/container_topology/show');
        $scope = $rootScope.$new();

        $httpBackend = _$httpBackend_;
        $httpBackend.when('GET','/container_topology/data').respond(mock_data);
        $controller = _$controller_('containerTopologyController',
            {$scope: $scope});
        $httpBackend.flush();
    }));

    afterEach(function() {
        $httpBackend.verifyNoOutstandingExpectation();
        $httpBackend.verifyNoOutstandingRequest();
    });

    describe('data loads successfully', function() {
        it('in all main objects', function() {
            expect($scope.items).not.toBe(undefined);
            expect($scope.relations).not.toBe(undefined);
            expect($scope.kinds).not.toBe(undefined);
        });
    });
});
