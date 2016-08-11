describe('ownershipFormController', function() {
  var $scope, $controller, $httpBackend, miqService;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function($rootScope, _$controller_, _$httpBackend_, _miqService_) {
    miqService = _miqService_;
    spyOn(miqService, 'miqFlash');
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    $scope = $rootScope.$new();
    $scope.ownershipModel = {owner: '',
                             group: ''};
    $httpBackend = _$httpBackend_;
    $controller = _$controller_('ownershipFormController', { $scope: $scope,
      objectIds:  [1000000000001,1000000000003],
      user:       'testUser',
      group:      'testGroup',
      miqService: miqService
    });
  }));

  beforeEach(inject(function(_$controller_) {
    var ownershipFormResponse = { user:  'testUser2',
                                  group: 'testGroup2'};
    $httpBackend.whenGET('ownership_form_fields/1000000000001,1000000000003').respond(ownershipFormResponse);
    $httpBackend.flush();
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('initialization', function() {
    it('sets the owner and group to the values returned via the http request', function() {
      describe('#cancelClicked', function() {
        expect($scope.ownershipModel.user).toEqual('testUser2');
        expect($scope.ownershipModel.group).toEqual('testGroup2');
      });
    });

    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function(value) {}
      };
      $scope.cancelClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.miqAjaxButton', function() {
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('ownership_update/?button=cancel');
    });
  });

  describe('#saveClicked', function(){
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.saveClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.miqAjaxButton', function() {
      submitContent = { objectIds:  $scope.objectIds,
        user: $scope.ownershipModel.user,
        group: $scope.ownershipModel.group};

      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('ownership_update/?button=save', submitContent);
    });
  });
});
