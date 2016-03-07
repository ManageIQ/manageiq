ManageIQ.angular.app.directive('validateTotal', function() {
  return {
    require: 'ngModel',
    link: function(scope, elm, attrs, ctrl) {
      var maxvalue = attrs.miqmax;
      ctrl.$validators.integer = function(modelValue, viewValue) {
        if (ctrl.$isEmpty(modelValue)) {
          return false;
        } else{
          var x = parseInt(viewValue, 10);
          if(x <= parseInt(maxvalue))
            return true;
        }
        return false;
      };
    }
  };
});
