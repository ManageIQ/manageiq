ManageIQ.angular.app.directive('validateMultiple', function() {
  return {
    require: 'ngModel',
    link: function(scope, elm, attrs, ctrl) {
      var memtype = attrs.memtype;
      var multiple = attrs.validateMultiple;
      var minvalue = attrs.miqmin;
      var maxvalue = attrs.miqmax;

      ctrl.$validators.integer = function(modelValue, viewValue) {
        if (ctrl.$isEmpty(modelValue)) {
          return false;
        } else{
          var x = parseInt(viewValue, 10)
          if(memtype == "GB")
            x *= 1024;
          if(x >= parseInt(minvalue, 10) && x <= parseInt(maxvalue, 10) && x % parseInt(multiple, 10) == 0) {
            return true;
          }
        }
        return false;
      };
    }
  };
});
