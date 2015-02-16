describe('timerOptionService', function() {
  var testService;

  beforeEach(module('cfmeAngularApplication'));

  beforeEach(inject(function(timerOptionService) {
    testService = timerOptionService;
  }));

  describe('#getOptions', function() {
    describe('when the timer type passed in is "Once"', function() {
      it('returns an empty array', function() {
        expect(testService.getOptions('Once')).toEqual([]);
      });
    });

    describe('when the timer type passed in is "Hourly"', function() {
      it('returns an array of hourly options', function() {
        expect(testService.getOptions('Hourly')).toEqual([
          {text: "Hour",     value: 1},
          {text: "2 Hours",  value: 2},
          {text: "3 Hours",  value: 3},
          {text: "4 Hours",  value: 4},
          {text: "6 Hours",  value: 6},
          {text: "8 Hours",  value: 8},
          {text: "12 Hours", value: 12}
        ]);
      });
    });

    describe('when the timer type passed in is "Daily"', function() {
      it('returns an array of daily options', function() {
        expect(testService.getOptions('Daily')).toEqual([
          {text: "Day",    value: 1},
          {text: "2 Days", value: 2},
          {text: "3 Days", value: 3},
          {text: "4 Days", value: 4},
          {text: "5 Days", value: 5},
          {text: "6 Days", value: 6}
        ]);
      });
    });

    describe('when the timer type passed in is "Weekly"', function() {
      it('returns an array of weekly options', function() {
        expect(testService.getOptions('Weekly')).toEqual([
          {text: "Week",    value: 1},
          {text: "2 Weeks", value: 2},
          {text: "3 Weeks", value: 3},
          {text: "4 Weeks", value: 4}
        ]);
      });
    });

    describe('when the timer type passed in is "Monthly"', function() {
      it('returns an array of monthly options', function() {
        expect(testService.getOptions('Monthly')).toEqual([
          {text: "Month",    value: 1},
          {text: "2 Months", value: 2},
          {text: "3 Months", value: 3},
          {text: "4 Months", value: 4},
          {text: "5 Months", value: 5},
          {text: "6 Months", value: 6}
        ]);
      });
    });
  });
});
