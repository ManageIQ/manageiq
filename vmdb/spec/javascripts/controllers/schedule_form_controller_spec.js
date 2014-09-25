describe('scheduleFormController', function() {
  var $scope, $controller;

  beforeEach(module('cfmeAngularApplication'));

  beforeEach(inject(function($rootScope, _$controller_, _$httpBackend_) {
    $scope = $rootScope.$new();
    $httpBackend = _$httpBackend_;
    $controller = _$controller_('scheduleFormController', {$scope: $scope, storageTable: 'Potatostore'});
  }));

  afterEach(function() {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('initialization', function() {
    it('sets the action type to vm', function() {
      expect($scope.action_type).toEqual('vm');
    });

    it('sets the filter type to all', function() {
      expect($scope.filter_type).toEqual('all');
    });

    it('sets the filterValuesEmpty to true', function() {
      expect($scope.filterValuesEmpty).toBe(true);
    });
  });

  describe('#buildLegend', function() {
    describe('when the action type is a vm type', function() {
      beforeEach(function() {
        $scope.action_type = 'vm_potato';
      });

      it('returns VM Selection', function() {
        expect($scope.buildLegend()).toEqual('VM Selection');
      });
    });

    describe('when the action type is a host type', function() {
      beforeEach(function() {
        $scope.action_type = 'host_potato';
      });

      it('returns Host Selection', function() {
        expect($scope.buildLegend()).toEqual('Host Selection');
      });
    });

    describe('when the action type is an miq_template type', function() {
      beforeEach(function() {
        $scope.action_type = 'miq_template';
      });

      it('returns Template Selection', function() {
        expect($scope.buildLegend()).toEqual('Template Selection');
      });
    });

    describe('when the action type is an emscluster type', function() {
      beforeEach(function() {
        $scope.action_type = 'emscluster';
      });

      it('returns Cluster Selection', function() {
        expect($scope.buildLegend()).toEqual('Cluster Selection');
      });
    });

    describe('when the action type is a storage type', function() {
      beforeEach(function() {
        $scope.action_type = 'storage';
      });

      it('returns storageTable + Selection', function() {
        expect($scope.buildLegend()).toEqual('Potatostore Selection');
      });
    });

    describe('when the action type is a db_backup type', function() {
      beforeEach(function() {
        $scope.action_type = 'db_backup';
      });

      it('returns Database Backup Selection', function() {
        expect($scope.buildLegend()).toEqual('Database Backup Selection');
      });
    });
  });

  describe('#determineActionType', function() {
    describe('when the action type is a vm type', function() {
      beforeEach(function() {
        $scope.action_type = 'vm_potato';
      });

      it('returns vm', function() {
        expect($scope.determineActionType()).toEqual('vm');
      });
    });

    describe('when the action type is a host type', function() {
      beforeEach(function() {
        $scope.action_type = 'host_potato';
      });

      it('returns host', function() {
        expect($scope.determineActionType()).toEqual('host');
      });
    });

    describe('when the action type is any other type', function() {
      beforeEach(function() {
        $scope.action_type = 'potato';
      });

      it('returns that type', function() {
        expect($scope.determineActionType()).toEqual('potato');
      });
    });
  });

  describe('#filterTypeChanged', function() {
    describe('when the filter type is all', function() {
      beforeEach(function() {
        $scope.filter_type = 'all';
        $scope.filterValuesEmpty = false;
        $scope.filterTypeChanged();
      });

      it('sets filter values empty to true', function() {
        expect($scope.filterValuesEmpty).toBe(true)
      });
    });

    describe('when the filter type is not all', function() {
      beforeEach(function() {
        $scope.filter_type = 'not_all';
      });

      describe('when the ajax request returns with success', function() {
        describe('when the item list is a single dimension array', function() {
          beforeEach(function() {
            $httpBackend.whenPUT('/ops/schedule_form_field_change').respond(200, {filtered_item_list: ['lol', 'lol2']});
            $scope.filterTypeChanged();
            $httpBackend.flush();
          });

          it('creates a new drop down with the list response', function() {
            expect($scope.filterList).toEqual([['lol', 'lol'], ['lol2', 'lol2']]);
          });

          it('sets the filterValuesEmpty to false', function() {
            expect($scope.filterValuesEmpty).toBe(false);
          });
        });

        describe('when the item list is a multi dimension array', function() {
          beforeEach(function() {
            $httpBackend.whenPUT('/ops/schedule_form_field_change').respond(200, {filtered_item_list: [['lolvalue', 'loloption'], ['lol2value', 'lol2option']]});
            $scope.filterTypeChanged();
            $httpBackend.flush();
          });

          it('creates a new drop down with the list response', function() {
            expect($scope.filterList).toEqual([['lolvalue', 'loloption'], ['lol2value', 'lol2option']]);
          });

          it('sets the filterValuesEmpty to false', function() {
            expect($scope.filterValuesEmpty).toBe(false);
          });
        });
      });

      describe('when the ajax request returns with failure', function() {
        beforeEach(function() {
          $httpBackend.whenPUT('/ops/schedule_form_field_change').respond(400, '');
          $scope.filterTypeChanged();
          $httpBackend.flush();
        });

        it('does some stuff', function() {
        });
      });
    });
  });

  describe('#actionTypeChanged', function() {
    describe('when the action type is db_backup', function() {
      beforeEach(function() {
        $scope.action_type = 'db_backup';
        $scope.actionTypeChanged();
      });

      it('sets the log protocol to network file system', function() {
        expect($scope.log_protocol).toEqual('Network File System');
      });
    });

    describe('when the action type is not db_backup', function() {
      beforeEach(function() {
        $scope.action_type = 'not_db_backup';
        $scope.filter_type = 'not_all';
        $scope.filterValuesEmpty = false;
        $scope.actionTypeChanged();
      });

      it('resets the filter type to all', function() {
        expect($scope.filter_type).toEqual('all');
      });

      it('sets filter values empty to true', function() {
        expect($scope.filterValuesEmpty).toBe(true);
      });
    });
  });

  describe('#sambaBackup', function() {
    describe('when the action type is db_backup', function() {
      beforeEach(function() {
        $scope.action_type = 'db_backup';
      });

      describe('when the log protocol is Samba', function() {
        beforeEach(function() {
          $scope.log_protocol = 'Samba';
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
});
