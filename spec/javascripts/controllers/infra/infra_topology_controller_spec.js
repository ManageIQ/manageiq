describe('infraTopologyController', function() {
    var scope, $controller, $httpBackend;
    var mock_data =  getJSONFixture('infra_topology_response.json');
    var cluster = { id:"396086e5-7b0d-11e5-8286-18037327aaeb",  item:{display_kind:"EmsCluster", name:"overcloud-Compute-xr5gaw2saehi", kind:"EmsCluster", id:"396086e5-7b0d-11e5-8286-18037327aaeb", miq_id:"100012"}};
    var infra_provider = { id:"4",  item:{display_kind:"Openstack", name:"myProvider", kind:"InfraManager", id:"2", miq_id:"2"}};

    beforeEach(module('infraTopologyApp'));

    beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, $location) {
      spyOn($location, 'absUrl').and.returnValue('/infra_topology/show');
      scope = $rootScope.$new();

      $httpBackend = _$httpBackend_;
      $httpBackend.when('GET','/infra_topology/data').respond(mock_data);
      $controller = _$controller_('infraTopologyController',
          {$scope: scope});
      $httpBackend.flush();
    }));

    afterEach(function() {
      $httpBackend.verifyNoOutstandingExpectation();
      $httpBackend.verifyNoOutstandingRequest();
    });

    describe('data loads successfully', function() {
      it('in all main objects', function() {
        expect(scope.items).toBeDefined();
        expect(scope.relations).toBeDefined();
        expect(scope.kinds).toBeDefined();
      });
    });

    describe('kinds contain all expected kinds', function() {
      it('in all main objects', function() {
        expect(Object.keys(scope.kinds).length).toBeGreaterThan(2);
        expect(scope.kinds["EmsCluster"]).toBeDefined();
        expect(scope.kinds["Host"]).toBeDefined();
      });
    });

    describe('the topology gets correct icons', function() {
      it('in graph elements', function() {
        var d = { id:"2",  item:{display_kind:"Openstack", kind:"InfraManager", id:"2"}};
        expect($controller.getIcon(d)).toContain("/assets/svg/vendor-openstack");
        expect($controller.getIcon(infra_provider)).toContain("/assets/svg/vendor-openstack");
        d = { id:"4",  item:{display_kind:"Host", kind:"Host", id:"4"}};
        expect($controller.getIcon(d)).toEqual("\uE600");
        expect($controller.getIcon(cluster)).toEqual("\uE620");
      });
    });

    describe('dimensions are returned correctly', function() {
      it('of all objects', function() {
        var d = { id:"2",  item:{display_kind:"Openstack", kind:"InfraManager", id:"2", miq_id:"37"}};
        expect($controller.getDimensions(d)).toEqual({ x: -20, y: -20, r: 28 });
        expect($controller.getDimensions(infra_provider)).toEqual({ x: -20, y: -20, r: 28 });
        d = { id:"4",  item:{display_kind:"Host", kind:"Host", id:"4", miq_id:"25"}};
        expect($controller.getDimensions(d)).toEqual({ x: 0, y: 9, r: 17 });
        expect($controller.getDimensions(cluster)).toEqual({ x: 0, y: 9, r: 17 });
      });
    });

});
