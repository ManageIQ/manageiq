ManageIQ.angularApplication.directive('updateDropdownForFilter', ['$timeout', function($timeout) {
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
            $(scope['form_' + ctrl.$name]).selectpicker('hide');
          }
          else {
            if (scope[scope['form_' + ctrl.$name + '_ngHide']] == "NO-OP" ||
                scope[scope['form_' + ctrl.$name + '_ngHide']] == false) {

              $timeout(function(){
                $(scope['form_' + ctrl.$name]).selectpicker('render');
              }, 0);
            }
          }
        });
      }

      scope.$watch(scope['form_' + ctrl.$name + '_dropdownList'], function() {
        selectListElement(scope, $timeout, ctrl, true);
      });

      ctrl.$parsers.push(function(value) {
        if(scope.invalidStyleSet) {
          $(scope['form_' + ctrl.$name]).selectpicker('setStyle', 'btn-red-border', 'remove');
          $(scope['form_' + ctrl.$name]).selectpicker('setStyle', 'btn-default');
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
        $(scope['form_' + ctrl.$name]).selectpicker('hide');
      }
      else {
        $(scope['form_' + ctrl.$name]).selectpicker({
          dropupAuto: false
        });
        $(scope['form_' + ctrl.$name]).selectpicker('show');
        $(scope['form_' + ctrl.$name]).selectpicker('refresh');
        $(scope['form_' + ctrl.$name]).addClass('span12').selectpicker('setStyle');
      }
    }

    if (scope[scope['form_' + ctrl.$name + '_dropdownModel']][ctrl.$name] != undefined &&
        scope[scope['form_' + ctrl.$name + '_dropdownModel']][ctrl.$name] != '') {
      index = findIndexByKeyValue(scope[scope['form_' + ctrl.$name + '_dropdownList']], "value", scope[scope['form_' + ctrl.$name + '_dropdownModel']][ctrl.$name]);
      $(scope['form_' + ctrl.$name]).selectpicker('val', index);

      if(index == null) {
        $(scope['form_' + ctrl.$name]).selectpicker('setStyle', ' btn-default btn-red-border');
        scope.invalidStyleSet = true;
      }
      else {
        $(scope['form_' + ctrl.$name]).selectpicker('setStyle', 'btn-red-border', 'remove');
        $(scope['form_' + ctrl.$name]).selectpicker('setStyle', 'btn-default');
        scope.invalidStyleSet = false;
      }

    }
    else {
      $(scope['form_' + ctrl.$name]).selectpicker('setStyle', 'btn-default btn-red-border');
      scope.invalidStyleSet = true;
    }

  }, 0);
};

var findIndexByKeyValue = function(arraytosearch, key, valuetosearch) {
  for (var i = 0; i < arraytosearch.length; i++) {
    if (arraytosearch[i][key] == valuetosearch) {
      return i;
    }
  }
  return null;
};
