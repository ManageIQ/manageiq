describe('hostFormController', function() {
  var $scope, $controller, $httpBackend, miqService;

  beforeEach(module('miqAngularApplication'));

  beforeEach(inject(function($rootScope, _$controller_, _$httpBackend_, _miqService_) {
    miqService = _miqService_;
    spyOn(miqService, 'miqFlash');
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    $scope = $rootScope.$new();
    $scope.hostModel = { name: 'name', ipaddress: 'ipaddress' };
    $scope.hostForm = { name: {},
      ipaddress: {
                    $dirty:       false,
                    $name:       'ipaddress',
                    $setValidity: function (validationErrorKey, isValid){}
                  },
                  $setPristine: function (){}
                };
    //$scope.hostForm = { name: {},
    //                    ipaddress: {},
    //                    $setPristine: function (){}
    //};

    $scope.hostForm.$invalid = false;
    $httpBackend = _$httpBackend_;
    $httpBackend.whenGET('/host/host_form_fields/new').respond();
      $controller = _$controller_('hostFormController', {
        $scope: $scope,
        hostFormId: 'new',
        miqService: miqService
      });
    }));

    afterEach(function() {
      $httpBackend.verifyNoOutstandingExpectation();
      $httpBackend.verifyNoOutstandingRequest();
    });

    describe('initialization', function() {
      describe('when the hostFormId is new', function() {
        it('sets the name to blank', function () {
          expect($scope.hostModel.name).toEqual('');
        });
        it('sets the ipaddress to blank', function () {
          expect($scope.hostModel.ipaddress).toEqual('');
        });
      });

      describe('when the hostFormId is an Id', function() {
        var hostFormResponse = {
          name: 'aaa',
          ipaddress: '1.1.1.1'
        };
        describe('when the filter type is all', function() {
          beforeEach(inject(function(_$controller_) {

            $httpBackend.whenGET('/host/host_form_fields/12345').respond(hostFormResponse);

            $controller = _$controller_('hostFormController', {$scope: $scope, hostFormId: '12345'});
            $httpBackend.flush();
          }));

          it('sets the name to the value returned from the http request', function() {
            expect($scope.hostModel.name).toEqual('aaa');
          });

          it('sets the ipaddress to the value returned from the http request', function() {
            expect($scope.hostModel.ipaddress).toEqual('1.1.1.1');
          });
        });
      });
    });
});
