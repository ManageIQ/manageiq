
function miqWizardButtonDirective(action) {
  angular.module('miq.wizard')
    .directive(action, function() {
      return {
        restrict: 'A',
        replace: false,
        require: '^miq-wizard',
        scope: {
          callback: "=?"
        },
        link: function($scope, $element, $attrs, wizard) {
          $element.on("click", function(e) {
            e.preventDefault();
            $scope.$apply(function() {
              $scope.$eval($attrs[action]);
              wizard[action.replace("miqWiz", "").toLowerCase()]($scope.callback);
            });
          });
        }
      };
    });
}

miqWizardButtonDirective('miqWizNext');
miqWizardButtonDirective('miqWizPrevious');
miqWizardButtonDirective('miqWizFinish');
miqWizardButtonDirective('miqWizCancel');
miqWizardButtonDirective('miqWizReset');
