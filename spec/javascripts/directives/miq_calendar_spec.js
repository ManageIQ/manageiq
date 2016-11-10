describe('miq-calendar test', function() {
  var scope, form, element, compile;
  beforeEach(module('ManageIQ'));
  beforeEach(inject(function($compile, $rootScope) {
    scope = $rootScope;
    compile = $compile;
    element = angular.element('<form name="angularForm">' +
      '<input type="text" miq-calendar="true" ng-model="testModel.test_date" name="test_date" ' +
      'data-provide="datepicker" miq-cal-date-from="testModel.start_date" miq-cal-date-to="testModel.end_date" ' +
      'miq-cal-skip-days="testModel.skip_days" ' +
      '/></form>');
    scope.testModel = {
      test_date : new Date(Date.UTC(2015, 7, 30)),
      start_date: new Date(Date.UTC(1970, 0, 1)),
      end_date:   new Date(Date.UTC(2525, 11, 31)),
      skip_days:  [0,6]
    };
    compile(element)(scope);
    scope.$digest();
    form = scope.angularForm;
    spyOn($.fn, 'datepicker');
  }));

  describe('miq-calendar formatter and parser', function() {
    it('should format a date value from model into string value for output', function() {
      expect(form.test_date.$viewValue).toBe('08/30/2015');
    });

    it('should parse a value from input into model value', function() {
      form.test_date.$setViewValue('12/31/1980');
      expect(scope.testModel.test_date).toEqual(new Date(Date.UTC(1980, 11, 31)));
    });

    it('should update datepicker when the model changes', function() {
      scope.testModel.test_date = new Date(Date.UTC(2015, 8, 30));
      scope.$digest();
      expect($.fn.datepicker).toHaveBeenCalledWith('update');
    });

    it('do not call update datepicker when the date is cleared', function() {
      scope.testModel.test_date = null;
      scope.$digest();
      expect($.fn.datepicker).not.toHaveBeenCalled();
    });

    it('should update datepicker when the start date in model changes', function() {
      var d = new Date(Date.UTC(2010, 8, 30));
      scope.testModel.start_date = d;
      scope.$digest();

      expect($.fn.datepicker).toHaveBeenCalledWith('setStartDate', d);
    });

    it('should update datepicker when the end date in model changes', function() {
      var d = new Date(Date.UTC(2525, 10, 30));
      scope.testModel.end_date = d;
      scope.$digest();
      expect($.fn.datepicker).toHaveBeenCalledWith('setEndDate', d);
    });

    it('should update datepicker when skip days in model change', function() {
      var sd = [1,2,3,4,5];
      scope.testModel.skip_days = sd;
      scope.$digest();
      expect($.fn.datepicker).toHaveBeenCalledWith('setDaysOfWeekDisabled', sd);
    });
  });
});
