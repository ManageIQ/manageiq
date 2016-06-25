ManageIQ.angular.app.directive('validateTotal', function() {
  return {
    require: 'ngModel',
    link: function(_scope, _elm, attrs, ctrl) {
      var maxvalue = attrs.miqmax;
      ctrl.$validators.integer = function(modelValue, viewValue) {
        if (ctrl.$isEmpty(modelValue)) {
          return false;
        }

        var x = parseInt(viewValue, 10);
        if (x <= parseInt(maxvalue, 10))
          return true;

        return false;
      };
    }
  };
});
