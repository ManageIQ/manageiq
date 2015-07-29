(function() {
  'use strict';

  angular.module('blocks.multi-transclude')
    .factory('MultiTransclude', MultiTranscludeFactory);

  /** @ngInject */
  function MultiTranscludeFactory() {
    var service = {
      transclude: transclude
    };

    return service;

    function transclude(element, transcludeFn, removeEmptyTranscludeTargets) {
      transcludeFn(transcluder);

      if (!!removeEmptyTranscludeTargets) {
        removeEmptyTargets();
      }

      function transcluder(clone) {
        angular.forEach(clone, cloner);
      }

      /**
       * Transclude in content from transclude-to sources to transclude-id targets
       *
       * @param cloneEl
       */
      function cloner(cloneEl) {
        var $cloneEl = angular.element(cloneEl);
        var transcludeId = $cloneEl.attr('transclude-to');
        var selector = '[transclude-id="' + transcludeId + '"]';
        var target = element.find(selector);

        if (!transcludeId) {
          return;
        }
        if (target.length) {
          target.append($cloneEl);
        } else {
          $cloneEl.remove();
          throw new Error('`transclude-to="' + transcludeId + '"` target not found.');
        }
      }

      /**
       * Locate all transclude targets and check for children.
       */
      function removeEmptyTargets() {
        var targets = element.find('[transclude-id]');

        angular.forEach(targets, removeIfEmpty);
      }

      /**
       * Removes transclude targets that have no child elements or text.
       *
       * @param target Transclude target with transclude-id attribute
       */
      function removeIfEmpty(target) {
        var $target = angular.element(target);

        if (0 === $target.children().length) {
          $target.remove();
        }
      }
    }
  }
})();
