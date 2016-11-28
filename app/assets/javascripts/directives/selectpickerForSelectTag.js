ManageIQ.angular.app.directive('selectpickerForSelectTag', function() {
  return {
    require: 'ngModel',
    link: function (scope, elem, attr, ctrl) {
      scope['form_' + ctrl.$name] = elem[0];

      scope.$watch(attr.ngModel, function() {
        angular.element(scope['form_' + ctrl.$name]).selectpicker({
          dropupAuto: false,
        });
        angular.element(scope['form_' + ctrl.$name]).selectpicker('show');
        angular.element(scope['form_' + ctrl.$name]).selectpicker('refresh');
        angular.element(scope['form_' + ctrl.$name]).addClass('span12').selectpicker('setStyle');
      });
      scope.$watch('loaded.bs.select', function() {
        angular.element('.bootstrap-select button').removeAttr('title');
      });

      scope.$on('$destroy', function () {
        elem.selectpicker('destroy');
      });
    }
  }
});
