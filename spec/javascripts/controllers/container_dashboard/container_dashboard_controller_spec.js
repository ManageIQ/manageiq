describe('containerDashboardController', function() {
    var $scope, $controller, $httpBackend;
    var mock_data = {
        data: {
            status: {
                services: {
                    errorCount: 0,
                    count: 9,
                    warningCount: 0
                },
                containers: {
                    count: 11,
                    errorCount: 0,
                    warningCount: 0
                },
                projects: {
                    count: 11,
                    errorCount: 0,
                    warningCount: 0
                },
                pods: {
                    warningCount: 0,
                    errorCount: 0,
                    count: 11
                },
                routes: {
                    count: 2,
                    errorCount: 0,
                    warningCount: 0
                },
                images: {
                    errorCount: 0,
                    count: 8,
                    warningCount: 0
                },
                nodes: {
                    errorCount: 0,
                    count: 9,
                    warningCount: 0
                },
                registries: {
                    count: 3,
                    errorCount: 0,
                    warningCount: 0
                }
            },
            heatmaps: {
                nodeCpuUsage: [],
                nodeMemoryUsage: []
            },
            providers: [
                {
                    count: 2,
                    providerType: "OpenShift",
                    id: "openshift",
                    iconClass: "pficon pficon-openshift"
                },
                {
                    iconClass: "pficon pficon-kubernetes",
                    id: "kubernetes",
                    count: 1,
                    providerType: "Kubernetes"
                }
            ]
        }
    };

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
    });
});
