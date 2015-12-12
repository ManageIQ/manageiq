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
  controllerAs: 'buttonGroup',
  templateUrl: '/static/_form_buttons_angular.html.haml',
});
