describe('mySettingsVisualsController', function() {
    var $scope, $controller, $httpBackend, miqService;

    beforeEach(module('ManageIQ'));

    beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, _miqService_) {
        miqService = _miqService_;
        spyOn(miqService, 'showButtons');
        spyOn(miqService, 'hideButtons');
        spyOn(miqService, 'miqAjaxButton');
        spyOn(miqService, 'sparkleOn');
        spyOn(miqService, 'sparkleOff');
        $scope = $rootScope.$new();
        spyOn($scope, '$broadcast');

        var mySettingsModel = {
                ems: true,
                ems_cloud: true,
                host: true,
                storage: true,
                vm: true,
                miq_template: true,
                quad_truncate: 'f',
                startpage: 'testing',
                perpage_grid: '5',
                perpage_tile: '5',
                perpage_list: '5',
                perpage_reports: '5',
                display_reporttheme: '',
                display_timezone: '',
                display_locale: ''
        };

        $scope.mySettingsModel = mySettingsModel;

        $httpBackend = _$httpBackend_;

        $httpBackend.whenGET('/configuration/get_visual_settings').respond(mySettingsModel);
        $controller = _$controller_('mySettingsVisualsController', {
            $scope: $scope,
            miqService: miqService
        });
    }));

    afterEach(function() {
        $httpBackend.verifyNoOutstandingExpectation();
        $httpBackend.verifyNoOutstandingRequest();
    });

    describe('initialization', function() {
        beforeEach(function() {
            $httpBackend.flush();
            $scope.angularForm = {
                $setPristine: function (value){}
            };
        });
        
        if('when the page is initialized', function() {
            expect($scope.mySettingsModel.startpage).toEqual('testing');
        });
    });

    describe('#saveClicked', function() {
        beforeEach(function() {
            $httpBackend.flush();
            $scope.angularForm = {
                $setPristine: function (value){}
            };
            $scope.saveClicked();
        });

        it('turns the spinner on via the miqService', function() {
            expect(miqService.sparkleOn).toHaveBeenCalled();
        });

        it('turns the spinner on twice', function() {
            expect(miqService.sparkleOn.calls.count()).toBe(2);
        });

        it('delegates to miqService.miqAjaxButton', function() {
            expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/configuration/set_visual_settings', miqService.serializeModel($scope.mySettingsModel));
        });
    });

    describe('#resetClicked', function() {
        beforeEach(function() {
            $httpBackend.flush();
            $scope.angularForm = {
                $setPristine: function (value){}
            };
            $scope.mySettingsModel.ems = false;
            $scope.mySettingsModel.perpage_grid = 20;
            $scope.mySettingsModel.startpage = 'updatedpagehere';
            $scope.resetClicked();
        });

        it('turns the spinner on via the miqService', function() {
            expect(miqService.sparkleOn).toHaveBeenCalled();
        });

        it('expect values to reset', function() {
            expect($scope.mySettingsModel.ems).toEqual(true);
            expect($scope.mySettingsModel.perpage_grid).toEqual('5');
            expect($scope.mySettingsModel.startpage).toEqual('testing');
        });
    });
});
