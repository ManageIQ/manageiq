describe('timelineOptionsController', function() {
    var $scope, $controller, $httpBackend, miqService;

    beforeEach(module('ManageIQ'));

    beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, _miqService_) {
        miqService = _miqService_;
        spyOn(miqService, 'showButtons');
        spyOn(miqService, 'hideButtons');
        spyOn(miqService, 'buildCalendar');
        spyOn(miqService, 'miqAjaxButton');
        spyOn(miqService, 'sparkleOn');
        spyOn(miqService, 'sparkleOff');
        $scope = $rootScope.$new();
        spyOn($scope, '$broadcast');
        $httpBackend = _$httpBackend_;
        $controller = _$controller_('timelineOptionsController', {
            $scope: $scope,
            keyPairFormId: 'new',
            url: '/host/tl_chooser',
            categories: [],
            miqService: miqService
        });
    }));

    afterEach(function() {
        $httpBackend.verifyNoOutstandingExpectation();
        $httpBackend.verifyNoOutstandingRequest();
    });

    describe('count increment', function() {
        it('should increment the count', function() {
            $scope.countIncrement();
            expect($scope.reportModel.tl_range_count).toBe(2);
        });

        it('should decrement the count', function() {
            $scope.reportModel.tl_range_count = 10;
            $scope.countDecrement();
            expect($scope.reportModel.tl_range_count).toBe(9);
        });
    });

    describe('options update', function() {
        it('should update the type to be hourly', function() {
            $scope.reportModel.tl_timerange = 'days';
            $scope.applyButtonClicked();
            expect($scope.reportModel.tl_typ).toBe('Hourly');
        });

        it('should update the type to be daily', function() {
            $scope.reportModel.tl_timerange = 'weeks';
            $scope.applyButtonClicked();
            expect($scope.reportModel.tl_typ).toBe('Daily');
        });

        it('should update the miq_date correctly', function() {
            $scope.reportModel.tl_timerange = 'days';
            $scope.reportModel.tl_range_count = 10;
            var timeLineDate = new Date('2016-04-01')
            $scope.reportModel.tl_date = new Date(timeLineDate.getTime() + (timeLineDate.getTimezoneOffset() * 60000));
            $scope.reportModel.tl_timepivot = 'starting';
            $scope.applyButtonClicked();
            expect($scope.reportModel.miq_date).toBe('04/11/2016');
        });

        it('should update the miq_date correctly based on centered', function() {
            $scope.reportModel.tl_timerange = 'days';
            $scope.reportModel.tl_range_count = 10;
            var timeLineDate = new Date('2016-04-01')
            $scope.reportModel.tl_date = new Date(timeLineDate.getTime() + (timeLineDate.getTimezoneOffset() * 60000));
            $scope.reportModel.tl_timepivot = 'centered';
            $scope.applyButtonClicked();
            expect($scope.reportModel.miq_date).toBe('04/06/2016');
        });
    });
});

