(function() {
  'use strict';

  angular.module('blocks.recursion')
    .factory('RecursionHelper', RecursionHelperFactory);

  /** @ngInject */
  function RecursionHelperFactory($compile) {
    var service = {
      compile: compile
    };

    return service;

    /**
     * Manually compiles the element, fixing the recursion loop.
     * @param element
     * @param [link] A post-link function, or an object with function(s) registered via pre and post properties.
     * @returns object An object containing the linking functions.
     */
    function compile(element, link) {
      // Break the recursion loop by removing the contents
      var contents = element.contents().remove();
      var compiledContents;

      // Normalize the link parameter
      if (angular.isFunction(link)) {
        link = {post: link};
      }

      return {
        pre: (link && link.pre) ? link.pre : null,
        post: post
      };

      /**
       * Compiles and re-adds the contents
       */
      function post(scope, element) {
        // Compile the contents
        if (!compiledContents) {
          compiledContents = $compile(contents);
        }
        // Re-add the compiled contents to the element
        compiledContents(scope, function(clone) {
          element.append(clone);
        });

        // Call the post-linking function, if any
        if (link && link.post) {
          link.post.apply(null, arguments);
        }
      }
    }
  }
})();
