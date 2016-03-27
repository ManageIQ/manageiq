angular.module('miq.dialogs').directive('miqModal', function () {
  'use strict';
  return {
    restrict: 'A',
    transclude: true,
    replace: true,
    scope: {
      visible: '=',
      modalTitle: '@',
      modalSize: '@',
      onShow: '&',
      onHide: '&',
      onCancel: '&'
    },
    templateUrl: '/static/modal-dialog.html',
    link: function (scope, element) {
      scope.$watch('visible', function(value) {
        if (value == true) {
          $(element).modal('show');
        } else {
          $(element).modal('hide');
        }
      });

      $(element).on('shown.bs.modal', function() {
        if (scope.onShow) {
          scope.$apply(function () {
            scope.onShow();
          });
        }
      });

      $(element).on('hidden.bs.modal', function() {
        if (scope.onHide) {
          scope.$apply(function () {
            scope.onHide();
          });
        }
      });
    }
  };
});
