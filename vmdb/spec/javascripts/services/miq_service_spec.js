describe('miqService', function() {
  var testService;

  beforeEach(module('cfmeAngularApplication'));

  beforeEach(inject(function(miqService) {
    testService = miqService;
    spyOn(window, 'miqButtons');
    spyOn(window, 'miqBuildCalendar');
    spyOn(window, 'miqSparkle');
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
      expect(window.miq_cal_dateFrom).toEqual(new Date(2014, 2, 3));
    });

    it('calls the global build calendar function', function() {
      testService.buildCalendar();
      expect(window.miqBuildCalendar).toHaveBeenCalled();
    });
  });

  describe('#sparkleOn', function() {
    it('calls the global miq sparkle with true', function() {
      testService.sparkleOn();
      expect(window.miqSparkle).toHaveBeenCalledWith(true);
    });
  });

  describe('#sparkleOff', function() {
    it('calls the global miq sparkle with false', function() {
      testService.sparkleOff();
      expect(window.miqSparkle).toHaveBeenCalledWith(false);
    });
  });
});
