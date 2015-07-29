(function() {
  'use strict';

  angular.module('app.resources')
    .factory('WizardQuestion', WizardQuestionFactory);

  /** @ngInject */
  function WizardQuestionFactory($resource) {
    var vm = this;
    var WizardQuestion = $resource('/api/v1/wizard_questions/:id', {
      id: '@id',
      'includes[]': ['wizard_answers']
    }, {
      update: {
        method: 'PUT',
        isArray: false
      }
    });

    WizardQuestion.defaults = {
      text: ''
    };

    WizardQuestion.answerDefaults = {
      text: '',
      tags_to_add: [],
      tags_to_remove: []
    };

    WizardQuestion.new = newQuestion;

    WizardQuestion.prototype.next = function() {
      if (this.next_question_id) {
        return WizardQuestion
          .get({id: this.next_question_id})
          .$promise;
      }
    };

    function newQuestion() {
      return new WizardQuestion(angular.copy(WizardQuestion.defaults));
    }

    return WizardQuestion;
  }
})();
