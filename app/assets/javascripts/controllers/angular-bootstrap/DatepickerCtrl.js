miqAngularApplication.controller('DatepickerCtrl', function ($scope) {
  if($scope.$parent.formId == "new")
    $scope.minDate = new Date();

  $scope.open = function($event) {
    $event.preventDefault();
    $event.stopPropagation();

    $scope.opened = true;
  };
});