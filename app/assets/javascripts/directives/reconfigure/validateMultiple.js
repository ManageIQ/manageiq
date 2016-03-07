ManageIQ.angular.app.directive('validateMultiple', function(){
  return {
    require: 'ngModel',
    link: function(scope, elm, attrs, ctrl) {
      function multipleValidator(modelValue) {
        var memtype = attrs.memtype;
        var multiple = attrs.validateMultiple;
        var minvalue = attrs.miqmin;
        var maxvalue = attrs.miqmax;
        var x = parseInt(modelValue, 10);
        if(memtype == "GB")
          x *= 1024;
        if (x >= parseInt(minvalue) && x <= parseInt(maxvalue)) {
          ctrl.$setValidity('inrange', true);
        } else {
          ctrl.$setValidity('inrange', false);
        }
        if (x % parseInt(multiple, 10) == 0){
          ctrl.$setValidity('notmultiple', true);
        } else {
          ctrl.$setValidity('notmultiple', false);
        }
        return modelValue;
      }
      ctrl.$parsers.push(multipleValidator);
    }
  };
});
