ManageIQ.angularApplication.directive('bDatepicker', function () {
  return {
    restrict: 'A',
    link: function (scope, el, attr) {
      el.datepicker({});
      var component = el.siblings('[data-toggle="datepicker"]');
      if (component.length) {
        component.on('click', function () {
          el.trigger('focus');
        });
      }
    }
  };
});
