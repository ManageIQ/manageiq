ManageIQ.angular.app.component('buttonGroup', {
  bindings: {
    visible: '=',
    submit: '&',
    disabled: '=',
    label: '@',
    titleOn: '@',
    titleOff: '@',
    btnClass: '@',
  },
  controller: ['miqService', '$scope', function(miqService, $scope){
    console.log($scope.$parent);
    this.saveable = miqService.saveable;
  }],
  link: function(scope, elem, attrs, ctrl) {
    ctrl.angularForm = scope.$parent.angularForm;
  },
  controllerAs: 'buttonGroup',
  templateUrl: '/static/_form_buttons_angular.html.haml',
});
