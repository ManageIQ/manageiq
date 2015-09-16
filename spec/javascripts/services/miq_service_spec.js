describe('miqService', function() {
  var testService;

  beforeEach(module('ManageIQ.angularApplication'));

  beforeEach(inject(function(miqService) {
    testService = miqService;
    spyOn(window, 'miqButtons');
    spyOn(window, 'miqBuildCalendar');
    spyOn(window, 'miqAjaxButton');
    spyOn(window, 'miqSparkleOn');
    spyOn(window, 'miqSparkleOff');
  }));

  describe('#showButtons', function() {
    it('calls the global buttons function with show', function() {
      testService.showButtons();
      expect(window.miqButtons).toHaveBeenCalledWith('show');
    });
  });

  describe('#hideButtons', function() {
    it('calls the global buttons function with hide', function() {
      testService.hideButtons();
      expect(window.miqButtons).toHaveBeenCalledWith('hide');
    });
  });

  describe('#buildCalendar', function() {
    it('sets up the date from', function() {
      testService.buildCalendar(2014, 2, 3);
      expect(window.ManageIQ.calendar.calDateFrom).toEqual(new Date(2014, 2, 3));
    });

    it('calls the global build calendar function', function() {
      testService.buildCalendar();
      expect(window.miqBuildCalendar).toHaveBeenCalled();
    });
  });

  describe('#miqAjaxButton', function() {
    it('calls the global miqAjaxButton with the correct arguments', function() {
      testService.miqAjaxButton('test_url');
      expect(window.miqAjaxButton).toHaveBeenCalledWith('test_url', undefined);
    });
  });

  describe('#sparkleOn', function() {
    it('calls the global miq sparkle on', function() {
      testService.sparkleOn();
      expect(window.miqSparkleOn).toHaveBeenCalled();
    });
  });

  describe('#sparkleOff', function() {
    it('calls the global miq sparkle off', function() {
      testService.sparkleOff();
      expect(window.miqSparkleOff).toHaveBeenCalled();
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
          expect(testService.saveable(scheduleForm)).toBe(true);
        });
      });

      describe('when the schedule form is not dirty', function() {
        beforeEach(function() {
          scheduleForm.$dirty = false;
        });

        it('returns false', function() {
          expect(testService.saveable(scheduleForm)).toBe(false);
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
          expect(testService.saveable(scheduleForm)).toBe(false);
        });
      });

      describe('when the schedule form is not dirty', function() {
        beforeEach(function() {
          scheduleForm.$dirty = false;
        });

        it('returns false', function() {
          expect(testService.saveable(scheduleForm)).toBe(false);
        });
      });

      describe('when the passed in model contains few attributes with null vaues', function() {
        beforeEach(function() {
          model = {
          depot_name:   'my_nfs_depot',
          uri:          'nfs://nfs_location',
          uri_prefix:   'nfs',
          log_userid:   null,
          log_password: null,
          log_verify:   null,
          log_protocol: 'NFS'
          };
        });

        it('it returns an object with null attributes excluded', function() {
          returnedObj = {
            depot_name:   'my_nfs_depot',
            uri:          'nfs://nfs_location',
            uri_prefix:   'nfs',
            log_protocol: 'NFS'
          };
          expect(testService.serializeModel(model)).toEqual(returnedObj);
        });
      });
    });
  });

  describe('#validateWithREST', function() {
    beforeEach(function() {
      testService.validateWithREST($.Event, "default", '/ems_cloud/create/new?button=validate&type=default', true);
    });

    it('turns the spinner on via the miqService', function() {
      expect(window.miqSparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.miqAjaxButton', function() {
      expect(window.miqAjaxButton).toHaveBeenCalledWith('/ems_cloud/create/new?button=validate&type=default', true);
    });
  });

  describe('#validateWithAjax', function() {
    beforeEach(function() {
      testService.validateWithAjax('/host/create/new?button=validate&type=default');
    });

    it('turns the spinner on via the miqService', function() {
      expect(window.miqSparkleOn).toHaveBeenCalled();
    });

    it('delegates to miqService.miqAjaxButton', function() {
      expect(window.miqAjaxButton).toHaveBeenCalledWith('/host/create/new?button=validate&type=default', true);
    });
  });
});
