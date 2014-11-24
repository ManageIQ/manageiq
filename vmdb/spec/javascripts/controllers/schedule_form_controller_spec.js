describe('scheduleFormController', function() {
  var $scope, $controller, $httpBackend, miqService, timerOptionService, oneMonthAgo;

  beforeEach(module('cfmeAngularApplication'));

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
      month: 2,
      date: 3
    };

    // For the initialization scheduleDate test. This freezes time to 1/2/2014.
    var fakeToday = new Date(2014, 0, 2);
    jasmine.clock().mockDate(fakeToday);

    $httpBackend.whenGET('/ops/schedule_form_fields/new').respond();
    $controller = _$controller_('scheduleFormController', {
      $scope: $scope,
      storageTable: 'Potatostore',
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
    it('sets newSchedule to false', function() {
      expect($scope.newSchedule).toBe(false);
    });

    it('sets the action type to the type returned from the http request', function() {
      expect($scope.actionType).toEqual('actionType');
    });

    it('sets the depot name', function() {
      expect($scope.depotName).toEqual('depotName');
    });

    it('sets the logUserid to the log_userid returned from the http request', function() {
      expect($scope.logUserid).toEqual('logUserId');
    });

    it('sets the logPassword to the log_password returned from the http request', function() {
      expect($scope.logPassword).toEqual('logPassword');
    });

    it('sets the logVerify to the log_verify returned from the http request', function() {
      expect($scope.logVerify).toEqual('logVerify');
    });

    it('sets the scheduleName to the name returned from the http request', function() {
      expect($scope.scheduleName).toEqual('scheduleName');
    });

    it('sets the scheduleDescription to the description returned from the http request', function() {
      expect($scope.scheduleDescription).toEqual('scheduleDescription');
    });

    it('sets the scheduleEnabled to the enabled attribute returned from the http request', function() {
      expect($scope.scheduleEnabled).toEqual('1');
    });

    it('sets the scheduleTimerType', function() {
      expect($scope.scheduleTimerType).toEqual('Hourly');
    });

    it('sets the scheduleTimerValue', function() {
      expect($scope.scheduleTimerValue).toEqual('8');
    });

    it('sets the scheduleDate', function() {
      expect($scope.scheduleDate).toEqual('now');
    });

    it('sets the scheduleStartHour', function() {
      expect($scope.scheduleStartHour).toEqual('12');
    });

    it('sets the scheduleStartMinute', function() {
      expect($scope.scheduleStartMinute).toEqual('25');
    });

    it('sets the scheduleTimeZone', function() {
      expect($scope.scheduleTimeZone).toEqual('UTC');
    });

    it('sets the uri', function() {
      expect($scope.uri).toEqual('uri');
    });

    it('sets the uriPrefix', function() {
      expect($scope.uriPrefix).toEqual('uriPrefix');
    });

    it('sets the timer items', function() {
      expect($scope.timerItems).toEqual(["some", "options"]);
    });

    it('sets finishedLoading', function() {
      expect($scope.finishedLoading).toBe(true);
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
      it('sets newSchedule to true', function() {
        expect($scope.newSchedule).toBe(true);
      });

      it('sets the action type to vm', function() {
        expect($scope.actionType).toEqual('vm');
      });

      it('sets the filter type to all', function() {
        expect($scope.filterType).toEqual('all');
      });

      it('sets the filterValuesEmpty to true', function() {
        expect($scope.filterValuesEmpty).toBe(true);
      });

      it('sets the scheduleDate to today', function() {
        expect($scope.scheduleDate).toEqual("1/2/2014");
      });

      it('sets the scheduleTimerType to once', function() {
        expect($scope.scheduleTimerType).toEqual('Once');
      });

      it('sets the scheduleEnabled to the truthy value', function() {
        expect($scope.scheduleEnabled).toEqual('1');
      });

      it('sets the scheduleTimeZone to UTC', function() {
        expect($scope.scheduleTimeZone).toEqual('UTC');
      });

      it('sets the scheduleStartHour to 0', function() {
        expect($scope.scheduleStartHour).toEqual('0');
      });

      it('sets the scheduleStartMinute to 0', function() {
        expect($scope.scheduleStartMinute).toEqual('0');
      });

      it('sets finishedLoading', function() {
        expect($scope.finishedLoading).toBe(true);
      });
    });

    describe('when the scheduleFormId is an id', function() {
      var scheduleFormResponse = {
        action_type: 'actionType',
        depot_name: 'depotName',
        filter_type: 'all',
        filtered_item_list: ['lol', 'lol2'],
        filter_value: 'filterValue',
        log_userid: 'logUserId',
        log_password: 'logPassword',
        log_verify: 'logVerify',
        schedule_name: 'scheduleName',
        schedule_description: 'scheduleDescription',
        schedule_enabled: '1',
        schedule_timer_type: 'Hourly',
        schedule_timer_value: '8',
        schedule_start_date: 'now',
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
          expect($scope.filterType).toEqual('all');
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
          $scope.logProtocol = 'protocol';
        });
      });

      describe('when the filter type is not all', function() {
        beforeEach(inject(function(_$controller_) {
          scheduleFormResponse.filter_type = 'filterType';

          $httpBackend.whenGET('/ops/schedule_form_fields/12345').respond(scheduleFormResponse);

          $controller = _$controller_('scheduleFormController', {$scope: $scope, storageTable: 'Potatostore', scheduleFormId: '12345', oneMonthAgo: oneMonthAgo});
          $httpBackend.flush();
        }));

        sharedBehaviorForInitialization();

        it('sets the filter type to the type returned from the http request', function() {
          expect($scope.filterType).toEqual('filterType');
        });

        it('sets the filter list', function() {
          expect($scope.filterList).toEqual([{text: 'lol', value: 'lol'}, {text: 'lol2', value: 'lol2'}]);
        });

        it('sets the filter value to the value returned from the http request', function() {
          expect($scope.filterValue).toEqual('filterValue');
        });

        it('sets the filterValuesEmpty to false', function() {
          expect($scope.filterValuesEmpty).toBe(false);
        });
      });
    });

    it('builds a calendar', function() {
      expect(miqService.buildCalendar).toHaveBeenCalledWith(2014, 2, 3);
    });
  });

  describe('#cancelClicked', function() {
    beforeEach(function() {
      $scope.cancelClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.miqAjaxButton', function() {
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/ops/schedule_edit/new?button=cancel');
    });
  });

  describe('#resetClicked', function() {
    beforeEach(function() {
      $scope.resetClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.miqAjaxButton', function() {
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/ops/schedule_edit/new?button=reset');
    });
  });

  describe('#saveClicked', function() {
    beforeEach(function() {
      $scope.saveClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.miqAjaxButton', function() {
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/ops/schedule_edit/new?button=save', true);
    });
  });

  describe('#addClicked', function() {
    beforeEach(function() {
      $scope.addClicked();
    });

    it('turns the spinner on via the miqService', function() {
      expect(miqService.sparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.miqAjaxButton', function() {
      expect(miqService.miqAjaxButton).toHaveBeenCalledWith('/ops/schedule_edit/new?button=add', true);
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
        $scope.actionType = 'host_potato';
      });

      it('returns Host Selection', function() {
        expect($scope.buildLegend()).toEqual('Host Selection');
      });
    });

    describe('when the action type is an miq_template type', function() {
      beforeEach(function() {
        $scope.actionType = 'miq_template';
      });

      it('returns Template Selection', function() {
        expect($scope.buildLegend()).toEqual('Template Selection');
      });
    });

    describe('when the action type is an emscluster type', function() {
      beforeEach(function() {
        $scope.actionType = 'emscluster';
      });

      it('returns Cluster Selection', function() {
        expect($scope.buildLegend()).toEqual('Cluster Selection');
      });
    });

    describe('when the action type is a storage type', function() {
      beforeEach(function() {
        $scope.actionType = 'storage';
      });

      it('returns storageTable + Selection', function() {
        expect($scope.buildLegend()).toEqual('Potatostore Selection');
      });
    });

    describe('when the action type is a db_backup type', function() {
      beforeEach(function() {
        $scope.actionType = 'db_backup';
      });

      it('returns Database Backup Selection', function() {
        expect($scope.buildLegend()).toEqual('Database Backup Selection');
      });
    });
  });

  describe('#determineActionType', function() {
    describe('when the action type is a vm type', function() {
      beforeEach(function() {
        $scope.actionType = 'vm_potato';
      });

      it('returns vm', function() {
        expect($scope.determineActionType()).toEqual('vm');
      });
    });

    describe('when the action type is a host type', function() {
      beforeEach(function() {
        $scope.actionType = 'host_potato';
      });

      it('returns host', function() {
        expect($scope.determineActionType()).toEqual('host');
      });
    });

    describe('when the action type is any other type', function() {
      beforeEach(function() {
        $scope.actionType = 'potato';
      });

      it('returns that type', function() {
        expect($scope.determineActionType()).toEqual('potato');
      });
    });
  });

  describe('#filterTypeChanged', function() {
    describe('when the filter type is all', function() {
      beforeEach(function() {
        $scope.filterType = 'all';
        $scope.filterValuesEmpty = false;
        $scope.filterTypeChanged();
      });

      it('sets filter values empty to true', function() {
        expect($scope.filterValuesEmpty).toBe(true);
      });

      it('sets the filterValue to null', function() {
        expect($scope.filterValue).toEqual(null);
      });
    });

    describe('when the filter type is not all', function() {
      beforeEach(function() {
        $scope.filterType = 'not_all';
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

          it('sets the filterValue to null', function() {
            expect($scope.filterValue).toEqual(null);
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

          it('sets the filterValue to null', function() {
            expect($scope.filterValue).toEqual(null);
          });
        });
      });
    });
  });

  describe('#logProtocolChanged', function() {
    describe('when the log protocol is samba', function() {
      beforeEach(function() {
        $scope.logProtocol = 'Samba';
      });

      it('sets the uriPrefix to smb', function() {
        $scope.logProtocolChanged();
        expect($scope.uriPrefix).toEqual('smb');
      });
    });

    describe('when the log protocol is network file system', function() {
      beforeEach(function() {
        $scope.logProtocol = 'Network File System';
      });

      it('sets the uriPrefix to nfs', function() {
        $scope.logProtocolChanged();
        expect($scope.uriPrefix).toEqual('nfs');
      });
    });
  });

  describe('#filterValueChanged', function() {
    describe('when the form has been altered', function() {
      beforeEach(function() {
        $scope.formAltered = true;
      });

      it('shows the buttons', function() {
        $scope.filterValueChanged();
        expect(miqService.showButtons).toHaveBeenCalled();
      });
    });

    describe('when the form has not been altered', function() {
      beforeEach(function() {
        $scope.formAltered = false;
      });

      it('hides the buttons', function() {
        $scope.filterValueChanged();
        expect(miqService.hideButtons).toHaveBeenCalled();
      });
    });
  });

  describe('#actionTypeChanged', function() {
    describe('when the action type is db_backup', function() {
      beforeEach(function() {
        $scope.actionType = 'db_backup';
        $scope.actionTypeChanged();
      });

      it('sets the log protocol to network file system', function() {
        expect($scope.logProtocol).toEqual('Network File System');
      });

      it('sets filter values empty to true', function() {
        expect($scope.filterValuesEmpty).toBe(true);
      });
    });

    describe('when the action type is not db_backup', function() {
      beforeEach(function() {
        $scope.actionType = 'not_db_backup';
        $scope.filterType = 'not_all';
        $scope.filterValuesEmpty = false;
        $scope.actionTypeChanged();
      });

      it('resets the filter type to all', function() {
        expect($scope.filterType).toEqual('all');
      });

      it('sets filter values empty to true', function() {
        expect($scope.filterValuesEmpty).toBe(true);
      });
    });
  });

  describe('#sambaBackup', function() {
    describe('when the action type is db_backup', function() {
      beforeEach(function() {
        $scope.actionType = 'db_backup';
      });

      describe('when the log protocol is Samba', function() {
        beforeEach(function() {
          $scope.logProtocol = 'Samba';
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
        $scope.scheduleTimerType = 'Once';
        $scope.scheduleTimerValue = 'not null';
        $scope.scheduleTimerTypeChanged();
      });

      it('sets the scheduleTimerValue to null', function() {
        expect($scope.scheduleTimerValue).toBeNull();
      });

      it('sets timerItems to the return value of the timerOptionService', function() {
        expect($scope.timerItems).toEqual(['some', 'options']);
      });
    });

    describe('when the timer type is changed to anything else', function() {
      beforeEach(function() {
        $scope.scheduleTimerType = 'Hourly';
        $scope.scheduleTimerValue = null;
        $scope.scheduleTimerTypeChanged();
      });

      it('sets the scheduleTimerValue to 1', function() {
        expect($scope.scheduleTimerValue).toEqual('1');
      });

      it('sets timerItems to the return value of the timerOptionService', function() {
        expect($scope.timerItems).toEqual(['some', 'options']);
      });
    });
  });

  describe('#timerNotOnce', function() {
    describe('when the timer type is once', function() {
      beforeEach(function() {
        $scope.scheduleTimerType = 'Once';
      });

      it('returns false', function() {
        expect($scope.timerNotOnce()).toBe(false);
      });
    });

    describe('when the timer type is not once', function() {
      beforeEach(function() {
        $scope.scheduleTimerType = 'Hourly';
      });

      it('returns true', function() {
        expect($scope.timerNotOnce()).toBe(true);
      });
    });
  });

  describe('#saveable', function() {
    var scheduleForm = {};

    describe('when the schedule form is valid', function() {
      beforeEach(function() {
        scheduleForm.$valid = true;
      });

      describe('when the schedule form is dirty', function() {
        beforeEach(function() {
          scheduleForm.$dirty = true;
        });

        it('returns true', function() {
          expect($scope.saveable(scheduleForm)).toBe(true);
        });
      });

      describe('when the schedule form is not dirty', function() {
        beforeEach(function() {
          scheduleForm.$dirty = false;
        });

        it('returns false', function() {
          expect($scope.saveable(scheduleForm)).toBe(false);
        });
      });
    });

    describe('when the schedule form is not valid', function() {
      beforeEach(function() {
        scheduleForm.$valid = false;
      });

      describe('when the schedule form is dirty', function() {
        beforeEach(function() {
          scheduleForm.$dirty = true;
        });

        it('returns false', function() {
          expect($scope.saveable(scheduleForm)).toBe(false);
        });
      });

      describe('when the schedule form is not dirty', function() {
        beforeEach(function() {
          scheduleForm.$dirty = false;
        });

        it('returns false', function() {
          expect($scope.saveable(scheduleForm)).toBe(false);
        });
      });
    });
  });
});
