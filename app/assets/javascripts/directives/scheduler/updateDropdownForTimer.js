ManageIQ.angularApplication.directive('updateDropdownForTimer', function($timeout) {
  return {
    require: 'ngModel',
      link: function (scope, elem, attr, ctrl) {
        scope['form_' + ctrl.$name] = elem[0];
        scope['form_' + ctrl.$name + '_timerHide'] = attr.timerHide;

        scope.$watch(attr.ngModel, function() {
          selectPickerShow(ctrl.$name);
        });

        scope.$watch("timer_items", function() {
          if (!scope[scope['form_' + ctrl.$name + '_timerHide']]) {
            $timeout(function () {
              selectPickerShow(ctrl.$name);
            }, 0);
          }
          else {
            hideTimerValue(scope, ctrl);
          }
        });

        var selectPickerShow = function(name) {
          if(scope.timer_items != undefined && scope.timer_items.length > 0) {
            $(scope['form_' + ctrl.$name]).selectpicker({
              dropupAuto: false
            });
            $(scope['form_' + name]).selectpicker('show');
            $(scope['form_' + name]).selectpicker('refresh');
            $(scope['form_' + name]).addClass('span12').selectpicker('setStyle');
          }
        };

        var hideTimerValue = function(scope, ctrl) {
          if(scope.timer_items == undefined || scope.timer_items.length == 0) {
            $(scope['form_' + ctrl.$name]).selectpicker('hide');
          }
        };
      }
    }
});
