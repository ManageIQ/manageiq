describe('hostFormController', function() {
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
    $scope.hostModel = { name: 'name', ipaddress: 'ipaddress' };
    $scope.hostForm = { name: {},
      ipaddress: {
                    $dirty:       false,
                    $name:       'ipaddress',
                    $setValidity: function (validationErrorKey, isValid){}
                  },
                  $setPristine: function (){}
                };

    $scope.hostForm.$invalid = false;
    $httpBackend = _$httpBackend_;
    $httpBackend.whenGET('/host/host_form_fields/new').respond();
      $controller = _$controller_('hostFormController', {
        $scope: $scope,
        $attrs: {'formFieldsUrl': '/host/host_form_fields/',
                 'createUrl': '/host/create/',
                 'updateUrl': '/host/update/'},
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
        it('sets the hostname to blank', function () {
          expect($scope.hostModel.hostname).toEqual('');
        });

        it('sets the custom identifier to blank', function() {
          expect($scope.hostModel.user_assigned_os).toEqual('');
        });

        it('sets the custom identifier to blank', function() {
          expect($scope.hostModel.custom_1).toEqual('');
        });

        it('sets the MAC address to blank', function() {
          expect($scope.hostModel.mac_address).toEqual('');
        });

        it('sets the IPMI Address to blank', function() {
          expect($scope.hostModel.ipmi_address).toEqual('');
        });
      });

      describe('when the hostFormId is an Id', function() {
        var hostFormResponse = {
          name: 'aaa',
          hostname: '1.1.1.1',
          custom_1: 'custom',
          mac_address: '2.2.2.2',
          ipmi_address: '3.3.3.3',
          default_userid: 'abc',
          remote_userid: 'xyz',
          ws_userid: 'aaa',
          ipmi_userid: 'zzz'
        };
        describe('when the filter type is all', function() {
          beforeEach(inject(function(_$controller_) {

            $httpBackend.whenGET('/host/host_form_fields/12345').respond(hostFormResponse);

            $controller = _$controller_('hostFormController', {$scope: $scope,
                                                               $attrs: {'formFieldsUrl': '/host/host_form_fields/',
                                                                        'createUrl': '/host/create/',
                                                                        'updateUrl': '/host/update/'},
                                                               hostFormId: '12345'});
            $httpBackend.flush();
          }));

          it('sets the name to the value returned from the http request', function() {
            expect($scope.hostModel.name).toEqual('aaa');
          });

          it('sets the hostname to the value returned from the http request', function() {
            expect($scope.hostModel.hostname).toEqual('1.1.1.1');
          });

          it('sets the custom identifier to the value returned from the http request', function() {
            expect($scope.hostModel.custom_1).toEqual('custom');
          });

          it('sets the MAC address to the value returned from the http request', function() {
            expect($scope.hostModel.mac_address).toEqual('2.2.2.2');
          });

          it('sets the IPMI Address to the value returned from the http request', function() {
            expect($scope.hostModel.ipmi_address).toEqual('3.3.3.3');
          });

          it('sets the default password to the placeholder value if a default user exists', function() {
            expect($scope.hostModel.default_password).toEqual(miqService.storedPasswordPlaceholder);
          });

          it('sets the remote password to the placeholder value if a remote user exists', function() {
            expect($scope.hostModel.remote_password).toEqual(miqService.storedPasswordPlaceholder);
          });

          it('sets the ws password to the placeholder value if a ws user exists', function() {
            expect($scope.hostModel.ws_password).toEqual(miqService.storedPasswordPlaceholder);
          });

          it('sets the ipmi password to the placeholder value if a ipmi user exists', function() {
            expect($scope.hostModel.ipmi_password).toEqual(miqService.storedPasswordPlaceholder);
          });
        });
      });
    });

  describe('#resetClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){},
        $setUntouched: function (value){},
      };
      $scope.resetClicked();
    });

    it('does not turn the spinner on', function() {
      expect(miqService.sparkleOn.calls.count()).toBe(0);
    });

    it("issues a broadcast for resetClicked event", function() {
      expect($scope.$broadcast).toHaveBeenCalledWith('resetClicked');
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
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/host/update/new?button=save', true);
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

    it('delegates to miqService.miqAjaxButton', function() {
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('create/new?button=add', true);
    });
  });

  describe('Validates credential fields', function() {
    beforeEach(inject(function($compile, miqService) {
      var angularForm;
      var element = angular.element(
        '<form name="angularForm">' +
        '<input ng-model="hostModel.hostname" name="hostname" required text />' +
        '<input ng-model="hostModel.default_userid" name="default_userid" required text />' +
        '<input ng-model="hostModel.default_password" name="default_password" text />' +
        '<input ng-model="hostModel.default_verify" name="default_verify" text />' +
        '</form>'
      );

      $compile(element)($scope);
      $scope.$digest();
      angularForm = $scope.angularForm;

      $scope.angularForm.hostname.$setViewValue('abchost');
      $scope.angularForm.default_userid.$setViewValue('abcuser');
      $scope.angularForm.default_password.$setViewValue(miqService.storedPasswordPlaceholder);
      $scope.angularForm.default_verify.$setViewValue(miqService.storedPasswordPlaceholder);
    }));

    it('returns true if all the Validation fields are filled in', function() {
      $scope.angularForm.default_password.$setViewValue('abcpassword');
      $scope.angularForm.default_verify.$setViewValue('abcpassword');
      expect($scope.canValidateBasicInfo()).toBe(true);
    });

    it('returns true if password fields are left blank', function() {
      $scope.angularForm.default_password.$setViewValue('');
      $scope.angularForm.default_verify.$setViewValue('');
      expect($scope.canValidateBasicInfo()).toBe(true);
    });

    it('returns true if all the Validation fields are filled in and dirty', function() {
      $scope.angularForm.default_password.$setViewValue('');
      $scope.angularForm.default_verify.$setViewValue('');
      expect($scope.canValidate()).toBe(true);
    });
  });
});
