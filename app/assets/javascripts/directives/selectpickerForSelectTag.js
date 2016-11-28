ManageIQ.angular.app.directive('selectpickerForSelectTag', function() {
  return {
    require: 'ngModel',
    link: function (scope, elem, attr, ctrl) {
      scope['form_' + ctrl.$name] = elem[0];

      scope.$watch(attr.ngModel, function() {
        $(scope['form_' + ctrl.$name]).selectpicker({
          dropupAuto: false
        });
        $(scope['form_' + ctrl.$name]).selectpicker('show');
        $(scope['form_' + ctrl.$name]).selectpicker('refresh');
        $(scope['form_' + ctrl.$name]).addClass('span12').selectpicker('setStyle');
      });
      scope.$watch('loaded.bs.select', function() {
        $('.bootstrap-select button').removeAttr('title');
      });

      scope.$on('$destroy', function () {
        elem.selectpicker('destroy');
      });
    }
  }
});
