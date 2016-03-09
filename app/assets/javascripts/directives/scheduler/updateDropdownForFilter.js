ManageIQ.angular.app.directive('updateDropdownForFilter', ['$timeout', function($timeout) {
  return {
    require: 'ngModel',
    link: function (scope, elem, attr, ctrl) {
      scope['form_' + ctrl.$name] = elem[0]
      scope['form_' + ctrl.$name + '_ngHide'] = attr.filterHide;

      scope['form_' + ctrl.$name + '_dropdownModel'] = attr.dropdownModel;
      scope['form_' + ctrl.$name + '_dropdownList'] = attr.dropdownList;

      if(scope['form_' + ctrl.$name + '_ngHide'] != "") {
        scope.$watch(scope['form_' + ctrl.$name + '_ngHide'], function () {
          if (scope[scope['form_' + ctrl.$name + '_ngHide']] === true) {
            angular.element(scope['form_' + ctrl.$name]).selectpicker('hide');
          }
          else {
            if (scope[scope['form_' + ctrl.$name + '_ngHide']] == "NO-OP" ||
                scope[scope['form_' + ctrl.$name + '_ngHide']] == false) {

              selectListElement(scope, $timeout, ctrl, true);
            }
          }
        });
      }

      scope.$watch(scope['form_' + ctrl.$name + '_dropdownList'], function() {
        selectListElement(scope, $timeout, ctrl, true);
      });

      ctrl.$parsers.push(function(value) {
        if(scope.invalidStyleSet) {
          angular.element(scope['form_' + ctrl.$name]).selectpicker('setStyle', 'btn-red-border', 'remove');
          angular.element(scope['form_' + ctrl.$name]).selectpicker('setStyle', 'btn-default');
        }
        return value;
      });
    }
  }
}]);

var selectListElement = function(scope, timeout, ctrl, refresh) {
  timeout(function(){
    if(refresh) {
      if (scope[scope['form_' + ctrl.$name + '_ngHide']] === true) {
        angular.element(scope['form_' + ctrl.$name]).selectpicker('hide');
      }
      else {
        angular.element(scope['form_' + ctrl.$name]).selectpicker({
          dropupAuto: false
        });
        angular.element(scope['form_' + ctrl.$name]).selectpicker('show');
        angular.element(scope['form_' + ctrl.$name]).selectpicker('refresh');
        angular.element(scope['form_' + ctrl.$name]).addClass('span12').selectpicker('setStyle');
      }
    }

    if (scope[scope['form_' + ctrl.$name + '_dropdownModel']][ctrl.$name] != undefined &&
        scope[scope['form_' + ctrl.$name + '_dropdownModel']][ctrl.$name] != '') {
      angular.element(scope['form_' + ctrl.$name]).selectpicker('val',
        scope[scope['form_' + ctrl.$name + '_dropdownModel']][ctrl.$name]);
      angular.element(scope['form_' + ctrl.$name]).selectpicker('setStyle', 'btn-red-border', 'remove');
      angular.element(scope['form_' + ctrl.$name]).selectpicker('setStyle', 'btn-default');
      scope.invalidStyleSet = false;
    }
    else {
      angular.element(scope['form_' + ctrl.$name]).selectpicker('setStyle', 'btn-default btn-red-border');
      scope.invalidStyleSet = true;
    }
  }, 0);
};

