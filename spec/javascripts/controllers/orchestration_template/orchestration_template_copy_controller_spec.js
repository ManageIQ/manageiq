describe('orchestrationTemplateCopyController', function() {
  var $scope, $controller, $httpBackend, miqService;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function($rootScope, _$controller_, _$httpBackend_, _miqService_) {
    miqService = _miqService_;
    spyOn(miqService, 'miqFlash');
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    $scope = $rootScope.$new();
    $scope.templateInfo = {
      templateId: null,
      templateName: null,
      templateDescription: null,
      templateDraft: null,
      templateContent: null
    };
    $httpBackend = _$httpBackend_;

    setFixtures('<html><head></head><body></body></html>');
    ManageIQ.editor = CodeMirror(document.body);

    $controller = _$controller_('orchestrationTemplateCopyController', {
      $scope: $scope,
      stackId: 1000000000001,
      miqService: miqService
    });
  }));

  beforeEach(inject(function(_$controller_) {
    var retirementFormResponse = {
      template_id: 1000000000001,
      template_name: 'template_name',
      template_description: 'template_description',
      template_draft: 'true',
      template_content: 'template_content',
    };
    $httpBackend.whenGET('/orchestration_stack/stacks_ot_info/1000000000001').respond(retirementFormResponse);
    $httpBackend.flush();
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('initialization', function() {
    it('sets the templateInfo to the values returned with http request', function() {
      expect($scope.templateInfo.templateId).toEqual(1000000000001);
      expect($scope.templateInfo.templateName).toEqual('Copy of template_name');
      expect($scope.templateInfo.templateDescription).toEqual('template_description');
      expect($scope.templateInfo.templateDraft).toEqual('true');
      expect($scope.templateInfo.templateContent).toEqual('template_content');
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
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/orchestration_stack/stacks_ot_copy?button=cancel&id=' + $scope.stackId);
    });
  });

  describe('#addClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){}
      };
      $scope.addClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('turns the spinner on once', function() {
      expect(miqService.sparkleOn.calls.count()).toBe(1);
    });

    it('delegates to miqService.miqAjaxButton', function() {
      var addContent = {
        templateId: $scope.templateInfo.templateId,
        templateName: $scope.templateInfo.templateName,
        templateDescription: $scope.templateInfo.templateDescription,
        templateDraft: $scope.templateInfo.templateDraft,
        templateContent: $scope.templateInfo.templateContent
      };
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/orchestration_stack/stacks_ot_copy?button=add', addContent);
    });
  });
});
