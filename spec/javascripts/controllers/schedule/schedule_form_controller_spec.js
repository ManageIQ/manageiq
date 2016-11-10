describe('scheduleFormController', function() {
  var $scope, $controller, $httpBackend, miqService, timerOptionService, oneMonthAgo;

  beforeEach(module('ManageIQ'));

  beforeEach(inject(function($rootScope, _$controller_, _$httpBackend_, _miqService_, _timerOptionService_) {
    miqService = _miqService_;
    timerOptionService = _timerOptionService_;
    spyOn(miqService, 'showButtons');
    spyOn(miqService, 'hideButtons');
    spyOn(miqService, 'buildCalendar');
    spyOn(miqService, 'miqAjaxButton');
    spyOn(miqService, 'sparkleOn');
    spyOn(miqService, 'sparkleOff');
    spyOn(timerOptionService, 'getOptions').and.returnValue(['some', 'options']);
    $scope = $rootScope.$new();
    $httpBackend = _$httpBackend_;
    oneMonthAgo = {
      year: 2014,
      month: 5,
      date: 7
    };

    // For the initialization scheduleDate test. This freezes time to 1/2/2014.
    var fakeToday = new Date(2014, 0, 2);
    jasmine.clock().mockDate(fakeToday);

    $httpBackend.whenGET('/ops/schedule_form_fields/new').respond();
    $controller = _$controller_('scheduleFormController', {
      $scope: $scope,
      scheduleFormId: 'new',
      oneMonthAgo: oneMonthAgo,
      miqService: miqService,
      timerOptionService: timerOptionService
    });
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  var sharedBehaviorForInitialization = function() {
    it('sets newRecord to false', function() {
      expect($scope.newRecord).toBe(false);
    });

    it('sets the action type to the type returned from the http request', function() {
      expect($scope.scheduleModel.action_typ).toEqual('actionType');
    });

    it('sets the depot name', function() {
      expect($scope.scheduleModel.depot_name).toEqual('depotName');
    });

    it('sets the logUserid to the log_userid returned from the http request', function() {
      expect($scope.scheduleModel.log_userid).toEqual('logUserId');
    });

    it('sets the logPassword to the log_password returned from the http request', function() {
      expect($scope.scheduleModel.log_password).toEqual(miqService.storedPasswordPlaceholder);
    });

    it('sets the logVerify to the log_verify returned from the http request', function() {
      expect($scope.scheduleModel.log_verify).toEqual(miqService.storedPasswordPlaceholder);
    });

    it('sets the scheduleName to the name returned from the http request', function() {
      expect($scope.scheduleModel.name).toEqual('scheduleName');
    });

    it('sets the scheduleDescription to the description returned from the http request', function() {
      expect($scope.scheduleModel.description).toEqual('scheduleDescription');
    });

    it('sets the scheduleEnabled to the enabled attribute returned from the http request', function() {
      expect($scope.scheduleModel.enabled).toEqual(true);
    });

    it('sets the scheduleTimerType', function() {
      expect($scope.scheduleModel.timer_typ).toEqual('Hourly');
    });

    it('sets the scheduleTimerValue', function() {
      expect($scope.scheduleModel.timer_value).toEqual('8');
    });

    it('sets the scheduleDate', function() {
      expect($scope.scheduleModel.start_date).toEqual(moment('01/01/2015').format('MM/DD/YYYY'));
    });

    it('sets the scheduleStartHour', function() {
      expect($scope.scheduleModel.start_hour).toEqual('12');
    });

    it('sets the scheduleStartMinute', function() {
      expect($scope.scheduleModel.start_min).toEqual('25');
    });

    it('sets the scheduleTimeZone', function() {
      expect($scope.scheduleModel.time_zone).toEqual('UTC');
    });

    it('sets the uri', function() {
      expect($scope.scheduleModel.uri).toEqual('uri');
    });

    it('sets the uriPrefix', function() {
      expect($scope.scheduleModel.uri_prefix).toEqual('uriPrefix');
    });

    it('sets the timer items', function() {
      expect($scope.timer_items).toEqual(["some", "options"]);
    });

    it('sets afterGet', function() {
      expect($scope.afterGet).toBe(true);
    });

    it('turns sparkle on', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('turns sparkle off', function() {
      expect(miqService.sparkleOff).toHaveBeenCalled();
    });
  };

  describe('initialization', function() {
    describe('when the scheduleFormId is new', function() {
      it('sets newRecord to true', function() {
        expect($scope.newRecord).toBe(true);
      });

      it('sets the action type to vm', function() {
        expect($scope.scheduleModel.action_typ).toEqual('vm');
      });

      it('sets the filter type to all', function() {
        expect($scope.scheduleModel.filter_typ).toEqual('all');
      });

      it('sets the filterValuesEmpty to true', function() {
        expect($scope.filterValuesEmpty).toBe(true);
      });

      it('sets the scheduleDate to today', function() {
        expect($scope.scheduleModel.start_date).toEqual(moment("01/02/2014").format('MM/DD/YYYY'));
      });

      it('sets the scheduleTimerType to once', function() {
        expect($scope.scheduleModel.timer_typ).toEqual('Once');
      });

      it('sets the scheduleEnabled to the truthy value', function() {
        expect($scope.scheduleModel.enabled).toEqual(true);
      });

      it('sets the scheduleTimeZone to UTC', function() {
        expect($scope.scheduleModel.time_zone).toEqual('UTC');
      });

      it('sets the scheduleStartHour to 0', function() {
        expect($scope.scheduleModel.start_hour).toEqual('0');
      });

      it('sets the scheduleStartMinute to 0', function() {
        expect($scope.scheduleModel.start_min).toEqual('0');
      });

      it('sets afterGet', function() {
        expect($scope.afterGet).toBe(true);
      });
    });

    describe('when the scheduleFormId is an id', function() {
      var scheduleFormResponse = {
        action_type: 'actionType',
        depot_name: 'depotName',
        filter_type: 'all',
        filtered_item_list: ['lol', 'lol2'],
        filter_value: 'filterValue',
        protocol: 'protocol',
        log_userid: 'logUserId',
        schedule_name: 'scheduleName',
        schedule_description: 'scheduleDescription',
        schedule_enabled: true,
        schedule_timer_type: 'Hourly',
        schedule_timer_value: '8',
        schedule_start_date: '01/01/2015',
        schedule_start_hour: '12',
        schedule_start_min: '25',
        schedule_time_zone: 'UTC',
        uri: 'uri',
        uri_prefix: 'uriPrefix'
      };

      describe('when the filter type is all', function() {
        beforeEach(inject(function(_$controller_) {

          scheduleFormResponse.filter_type = 'all';

          $httpBackend.whenGET('/ops/schedule_form_fields/12345').respond(scheduleFormResponse);

          $scope.filterValuesEmpty = false;

          $controller = _$controller_('scheduleFormController', {$scope: $scope, storageTable: 'Potatostore', scheduleFormId: '12345', oneMonthAgo: oneMonthAgo});
          $httpBackend.flush();
        }));

        sharedBehaviorForInitialization();

        it('sets the filter type to the type returned from the http request', function() {
          expect($scope.scheduleModel.filter_typ).toEqual('all');
        });

        it('sets the filterValuesEmpty to true', function() {
          expect($scope.filterValuesEmpty).toBe(true);
        });
      });

      describe('when the protocol exists', function() {
        beforeEach(inject(function(_$controller_) {
          scheduleFormResponse.procotol = 'protocol';

          $httpBackend.whenGET('/ops/schedule_form_fields/12345').respond(scheduleFormResponse);

          $controller = _$controller_('scheduleFormController', {$scope: $scope, storageTable: 'Potatostore', scheduleFormId: '12345', oneMonthAgo: oneMonthAgo});
          $httpBackend.flush();
        }));

        sharedBehaviorForInitialization();

        it('sets the filterValuesEmpty to true', function() {
          expect($scope.filterValuesEmpty).toBe(true);
        });

        it('sets the log protocol', function() {
          expect($scope.scheduleModel.log_protocol).toBe('protocol')
        });
      });

      describe('when the filter type is not all', function() {
        beforeEach(inject(function(_$controller_) {
          scheduleFormResponse.filter_type = 'filterType';
          scheduleFormResponse.protocol = undefined;

          $httpBackend.whenGET('/ops/schedule_form_fields/12345').respond(scheduleFormResponse);

          $controller = _$controller_('scheduleFormController', {$scope: $scope, scheduleFormId: '12345', oneMonthAgo: oneMonthAgo});
          $httpBackend.flush();
        }));

        sharedBehaviorForInitialization();

        it('sets the filter type to the type returned from the http request', function() {
          expect($scope.scheduleModel.filter_typ).toEqual('filterType');
        });

        it('sets the filter list', function() {
          expect($scope.filterList).toEqual([{text: 'lol', value: 'lol'}, {text: 'lol2', value: 'lol2'}]);
        });

        it('sets the filter value to the value returned from the http request', function() {
          expect($scope.scheduleModel.filter_value).toEqual('filterValue');
        });

        it('sets the filterValuesEmpty to false', function() {
          expect($scope.filterValuesEmpty).toBe(false);
        });
      });
    });

    it('builds a calendar', function() {
      expect(miqService.buildCalendar).toHaveBeenCalledWith(2014, 6, 7);
    });
  });

  describe('#cancelClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){}
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
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/ops/schedule_edit/new?button=cancel');
    });
  });

  describe('#resetClicked', function() {
    beforeEach(function() {
      $scope.angularForm = {
        $setPristine: function (value){},
        $setUntouched: function (value){},
        filter_value: {
          $name:       'filter_value',
          $setViewValue: function (value){}
        },
        action_typ: {},
        filter_typ: {},
        timer_typ: {},
      };
      $scope.resetClicked();
    });

    it('does not turn the spinner on', function() {
      expect(miqService.sparkleOn.calls.count()).toBe(0);
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
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/ops/schedule_edit/new?button=save', true);
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
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/ops/schedule_edit/new?button=save', true);
    });
  });

  describe('#buildLegend', function() {
    describe('when the action type is a vm type', function() {
      beforeEach(function() {
        $scope.actionType = 'vm_potato';
      });

      it('returns VM Selection', function() {
        expect($scope.buildLegend()).toEqual('VM Selection');
      });
    });

    describe('when the action type is a host type', function() {
      beforeEach(function() {
        $scope.scheduleModel.action_typ = 'host_potato';
      });

      it('returns Host Selection', function() {
        expect($scope.buildLegend()).toEqual('Host Selection');
      });
    });

    describe('when the action type is an miq_template type', function() {
      beforeEach(function() {
        $scope.scheduleModel.action_typ = 'miq_template';
      });

      it('returns Template Selection', function() {
        expect($scope.buildLegend()).toEqual('Template Selection');
      });
    });

    describe('when the action type is an emscluster type', function() {
      beforeEach(function() {
        $scope.scheduleModel.action_typ = 'emscluster';
      });

      it('returns Cluster Selection', function() {
        expect($scope.buildLegend()).toEqual('Cluster Selection');
      });
    });

    describe('when the action type is a storage type', function() {
      beforeEach(function() {
        $scope.scheduleModel.action_typ = 'storage';
      });

      it('returns storageTable + Selection', function() {
        expect($scope.buildLegend()).toEqual('Datastore Selection');
      });
    });

    describe('when the action type is a db_backup type', function() {
      beforeEach(function() {
        $scope.scheduleModel.action_typ = 'db_backup';
      });

      it('returns Database Backup Selection', function() {
        expect($scope.buildLegend()).toEqual('Database Backup Selection');
      });
    });

    describe('when the action type is a automation_request type', function() {
      beforeEach(function() {
        $scope.scheduleModel.action_typ = 'automation_request';
      });

      it('returns Auotmate Request Selection', function() {
        expect($scope.buildLegend()).toEqual('Automate Tasks Selection');
      });
    });
  });

  describe('#determineActionType', function() {
    describe('when the action type is a vm type', function() {
      beforeEach(function() {
        $scope.scheduleModel.action_typ = 'vm_potato';
      });

      it('returns vm', function() {
        expect($scope.determineActionType()).toEqual('vm');
      });
    });

    describe('when the action type is a host type', function() {
      beforeEach(function() {
        $scope.scheduleModel.action_typ = 'host_potato';
      });

      it('returns host', function() {
        expect($scope.determineActionType()).toEqual('host');
      });
    });

    describe('when the action type is any other type', function() {
      beforeEach(function() {
        $scope.scheduleModel.action_typ = 'potato';
      });

      it('returns that type', function() {
        expect($scope.determineActionType()).toEqual('potato');
      });
    });
  });

  describe('#filterTypeChanged', function() {
    describe('when the filter type is all', function() {
      beforeEach(function() {
        $scope.scheduleModel.filter_typ = 'all';
        $scope.filterValuesEmpty = false;
        $scope.angularForm = {
          filter_value: {
            $name:       'filter_value',
            $setViewValue: function (value){}
          }
        };
        $scope.filterTypeChanged();
      });

      it('sets filter values empty to true', function() {
        expect($scope.filterValuesEmpty).toBe(true);
      });

      it('sets the filterValue to ""', function() {
        expect($scope.scheduleModel.filter_value).toEqual("");
      });
    });

    describe('when the filter type is not all', function() {
      beforeEach(function() {
        $scope.scheduleModel.filter_typ = 'not_all';
        $scope.angularForm = {
          filter_value: {
            $name:       'filter_value',
            $setViewValue: function (value){}
          }
        };
      });

      describe('when the ajax request returns with success', function() {
        describe('when the item list is a single dimension array', function() {
          beforeEach(function() {
            $httpBackend.whenPOST('/ops/schedule_form_filter_type_field_changed/new').respond(200, {filtered_item_list: ['lol', 'lol2']});
            $scope.filterTypeChanged();
            $httpBackend.flush();
          });

          it('creates a new drop down with the list response', function() {
            expect($scope.filterList).toEqual([{text: 'lol', value: 'lol'}, {text: 'lol2', value: 'lol2'}]);
          });

          it('sets the filterValuesEmpty to false', function() {
            expect($scope.filterValuesEmpty).toBe(false);
          });

          it('turns the sparkle on', function() {
            expect(miqService.sparkleOn).toHaveBeenCalled();
          });

          it('turns the sparkle off', function() {
            expect(miqService.sparkleOff).toHaveBeenCalled();
          });

          it('sets the filterValue to ""', function() {
            expect($scope.scheduleModel.filter_value).toEqual("");
          });
        });

        describe('when the item list is a multi dimension array', function() {
          beforeEach(function() {
            $httpBackend.whenPOST('/ops/schedule_form_filter_type_field_changed/new').respond(200, {filtered_item_list: [['lolvalue', 'loloption'], ['lol2value', 'lol2option']]});
            $scope.filterTypeChanged();
            $httpBackend.flush();
          });

          it('creates a new drop down with the list response', function() {
            expect($scope.filterList).toEqual([{value: 'lolvalue', text: 'loloption'}, {value: 'lol2value', text: 'lol2option'}]);
          });

          it('sets the filterValuesEmpty to false', function() {
            expect($scope.filterValuesEmpty).toBe(false);
          });

          it('turns the sparkle on', function() {
            expect(miqService.sparkleOn).toHaveBeenCalled();
          });

          it('turns the sparkle off', function() {
            expect(miqService.sparkleOff).toHaveBeenCalled();
          });

          it('sets the filterValue to ""', function() {
            expect($scope.scheduleModel.filter_value).toEqual("");
          });
        });
      });
    });
  });

  describe('#logProtocolChanged', function() {
    describe('when the log protocol is samba', function() {
      beforeEach(function() {
        $scope.scheduleModel.log_protocol = 'Samba';
      });

      it('sets the uriPrefix to smb', function() {
        $scope.logProtocolChanged();
        expect($scope.scheduleModel.uri_prefix).toEqual('smb');
      });
    });

    describe('when the log protocol is network file system', function() {
      beforeEach(function() {
        $scope.scheduleModel.log_protocol = 'Network File System';
      });

      it('sets the uriPrefix to nfs', function() {
        $scope.logProtocolChanged();
        expect($scope.scheduleModel.uri_prefix).toEqual('nfs');
      });
    });
  });

  describe('#actionTypeChanged', function() {
    describe('when the action type is db_backup', function() {
      beforeEach(function() {
        $scope.scheduleModel.action_typ = 'db_backup';
        $scope.actionTypeChanged();
      });

      it('sets the log protocol to network file system', function() {
        expect($scope.scheduleModel.log_protocol).toEqual('Network File System');
      });

      it('sets filter values empty to true', function() {
        expect($scope.filterValuesEmpty).toBe(true);
      });
    });

    describe('when the action type is automation_request', function() {
      var data = {
        action_type: 'automation_request',
        starting_object: 'SYSTEM/PROCESS',
        request: 'test_request',
        instance_name: 'TestRequest',
        object_message: 'create',
        object_class: 'test',
        object_id:    '10',
        uri: 'uri',
        uri_prefix: 'uriPrefix'
      };
      beforeEach(function() {
        $httpBackend.whenPOST('/ops/automate_schedules_set_vars/new').respond(200, data);
        $scope.scheduleModel.action_typ = 'automation_request';
        $scope.actionTypeChanged();
        $httpBackend.flush();
      });

      it('sets the scheduleModel with the Automation params', function() {
        expect($scope.scheduleModel.instance_names).toEqual(data.instance_names);
        expect($scope.scheduleModel.starting_object).toEqual(data.starting_object);
        expect($scope.scheduleModel.instance_name).toEqual(data.instance_name);
        expect($scope.scheduleModel.object_message).toEqual(data.object_message);
        expect($scope.scheduleModel.object_request).toEqual(data.request);
        expect($scope.scheduleModel.target_class).toEqual(data.object_class);
        expect($scope.scheduleModel.target_id).toEqual(data.object_id);
      });
    });

    describe('when the action type is not db_backup', function() {
      beforeEach(function() {
        $scope.scheduleModel.action_typ = 'not_db_backup';
        $scope.scheduleModel.filter_typ = 'not_all';
        $scope.filterValuesEmpty = false;
        $scope.actionTypeChanged();
      });

      it('resets the filter type to all', function() {
        expect($scope.scheduleModel.filter_typ).toEqual('all');
      });

      it('sets filter values empty to true', function() {
        expect($scope.filterValuesEmpty).toBe(true);
      });
    });
  });

  describe('#sambaBackup', function() {
    describe('when the action type is db_backup', function() {
      beforeEach(function() {
        $scope.scheduleModel.action_typ = 'db_backup';
      });

      describe('when the log protocol is Samba', function() {
        beforeEach(function() {
          $scope.scheduleModel.log_protocol = 'Samba';
        });

        it('returns true', function() {
          expect($scope.sambaBackup()).toBe(true);
        });
      });

      describe('when the log protocol is not Samba', function() {
        it('returns false', function() {
          expect($scope.sambaBackup()).toBe(false);
        });
      });
    });

    describe('when the action type is not db_backup', function() {
      it('returns false', function() {
        expect($scope.sambaBackup()).toBe(false);
      });
    });
  });

  describe('#scheduleTimerTypeChanged', function() {
    describe('when the timer type is changed to once', function() {
      beforeEach(function() {
        $scope.scheduleModel.timer_typ = 'Once';
        $scope.scheduleModel.timer_value = 'not null';
        $scope.angularForm = {
          timer_value: {
            $name:       'timer_value',
            $setViewValue: function (value){}
          }
        };
        $scope.scheduleTimerTypeChanged();
      });

      it('sets the scheduleTimerValue to zero', function() {
        expect($scope.scheduleModel.timer_value).toEqual(0);
      });

      it('sets timerItems to the return value of the timerOptionService', function() {
        expect($scope.timer_items).toEqual(['some', 'options']);
      });
    });

    describe('when the timer type is changed to anything else', function() {
      beforeEach(function() {
        $scope.scheduleModel.timer_typ = 'Hourly';
        $scope.scheduleModel.timer_value = null;
        $scope.angularForm = {
          timer_value: {
            $name:       'timer_value',
            $setViewValue: function (value){}
          }
        };
        $scope.scheduleTimerTypeChanged();
      });

      it('sets the scheduleTimerValue to 1', function() {
        expect($scope.scheduleModel.timer_value).toEqual(1);
      });

      it('sets timerItems to the return value of the timerOptionService', function() {
        expect($scope.timer_items).toEqual(['some', 'options']);
      });
    });
  });

  describe('#timerNotOnce', function() {
    describe('when the timer type is once', function() {
      beforeEach(function() {
        $scope.scheduleModel.timer_typ = 'Once';
      });

      it('returns false', function() {
        expect($scope.timerNotOnce()).toBe(false);
      });
    });

    describe('when the timer type is not once', function() {
      beforeEach(function() {
        $scope.scheduleModel.timer_typ = 'Hourly';
      });

      it('returns true', function() {
        expect($scope.timerNotOnce()).toBe(true);
      });
    });
  });

  describe('Validates credential fields', function() {
    beforeEach(inject(function($compile, miqService) {
      var angularForm;
      var element = angular.element(
        '<form name="angularForm">' +
        '<input ng-model="scheduleModel.depot_name" name="depot_name" required" text />' +
        '<input ng-model="scheduleModel.uri" name="uri" required text />' +
        '<input ng-model="scheduleModel.log_userid" name="log_userid" required text />' +
        '<input ng-model="scheduleModel.log_password" name="log_password" required text />' +
        '<input ng-model="scheduleModel.log_verify" name="log_verify" required text />' +
        '</form>'
      );

      $compile(element)($scope);
      $scope.$digest();
      angularForm = $scope.angularForm;

      $scope.angularForm.depot_name.$setViewValue('abc');
      $scope.angularForm.uri.$setViewValue('abc');
      $scope.angularForm.log_userid.$setViewValue('abcuser');
      $scope.angularForm.log_password.$setViewValue('abcpassword');
      $scope.angularForm.log_verify.$setViewValue('abcpassword');
    }));

    it('returns true if all the Validation fields are filled in', function() {
      expect($scope.canValidateBasicInfo()).toBe(true);
    });

    it('returns true if all the Validation fields are filled in and dirty', function() {
      expect($scope.canValidate()).toBe(true);
    });
  });
});
