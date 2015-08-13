describe('retirementFormController', function() {
  var $scope, $controller, $httpBackend, miqService;

  beforeEach(module('ManageIQ.angularApplication'));

  beforeEach(inject(function($rootScope, _$controller_, _$httpBackend_, _miqService_) {
    miqService = _miqService_;
    spyOn(miqService, 'miqFlash');
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    $scope = $rootScope.$new();
    $scope.retirementInfo = { retirementDate: '', retirementWarning: ''};
    $httpBackend = _$httpBackend_;
    $controller = _$controller_('retirementFormController', {
      $scope: $scope,
      objectIds: [1000000000001],
      miqService: miqService
    });
  }));

  beforeEach(inject(function(_$controller_) {
    var retirementFormResponse = {
      retirement_date: '12/31/2015',
      retirement_warning: '0'
    };
    $httpBackend.whenGET('retirement_info/1000000000001').respond(retirementFormResponse);
    $httpBackend.flush();
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('initialization', function() {
    it('sets the retirementDate to the value returned with http request', function() {
      expect($scope.retirementInfo.retirementDate).toEqual('12/31/2015');
    });

    it('sets the retirementWarning to the value returned with http request', function() {
      expect($scope.retirementInfo.retirementWarning).toEqual('0');
    });
  });

  describe('#cancelClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function(value) {}
      };
      $scope.cancelClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('turns the spinner on once', function() {
      expect(miqService.sparkleOn.calls.count()).toBe(1);
    });

    it('delegates to miqService.miqAjaxButton', function() {
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('retire?button=cancel');
    });
  });

  describe('#saveClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.saveClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('turns the spinner on once', function() {
      expect(miqService.sparkleOn.calls.count()).toBe(1);
    });

    it('delegates to miqService.miqAjaxButton', function() {
      var saveContent = {
        retire_date: $scope.retirementInfo.retirementDate,
        retire_warn: $scope.retirementInfo.retirementWarning
      };
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('retire?button=save', saveContent);
    });
  });
});
