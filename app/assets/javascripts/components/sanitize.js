angular.module('miq.helpers')
  .component('miqSanitize', {
    bindings: {
      value: '@',
    },
    template: '<span ng-bind-html="$ctrl.value"></span>',
  });
