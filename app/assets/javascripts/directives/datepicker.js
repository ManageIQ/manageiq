ManageIQ.angularApplication.directive('datepickerInit', function () {
  return {
    require: 'ngModel',
    link: function (scope, elem, attr, ctrl) {
      language = attr.language;
      scope['form_' + ctrl.$name] = elem;

      scope.$watch(attr.ngModel, function() {
        if((ctrl.$modelValue != undefined)) {
          scope['form_' + ctrl.$name].datepicker({autoclose: true,
                                                  format: "mm/dd/yyyy",
                                                  startDate: ctrl.$modelValue,
                                                  weekStart: 0,
                                                  language: language});
          var component = scope['form_' + ctrl.$name].siblings('[data-toggle="datepicker"]');
          if (component.length) {
            component.on('click', function () {
              scope['form_' + ctrl.$name].trigger('focus');
            });
          }
        }
      });
    }
  };
});
