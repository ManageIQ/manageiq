
function wizardButtonDirective(action) {
  angular.module('miq.wizard')
    .directive(action, function() {
      return {
        restrict: 'A',
        replace: false,
        require: '^miq-wizard',
        link: function($scope, $element, $attrs, wizard) {

          $element.on("click", function(e) {
            e.preventDefault();
            $scope.$apply(function() {
              $scope.$eval($attrs[action]);
              wizard[action.replace("miqWiz", "").toLowerCase()]();
            });
          });
        }
      };
    });
}

wizardButtonDirective('miqWizNext');
wizardButtonDirective('miqWizPrevious');
wizardButtonDirective('miqWizFinish');
wizardButtonDirective('miqWizCancel');
wizardButtonDirective('miqWizReset');
