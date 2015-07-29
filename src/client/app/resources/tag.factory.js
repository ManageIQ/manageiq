(function() {
  'use strict';

  angular.module('app.resources')
    .factory('Tag', TagFactory);

  /** @ngInject */
  function TagFactory($resource) {
    var Tag = $resource('/api/v1/tags/:id', {id: '@id'}, {});

    // Instead of making an api call we'll call query and group the tags ourselves.
    Tag.grouped = grouped;

    function grouped() {
      return Tag.query().$promise.then(groupTags);

      function groupTags(tags) {
        var list = {};
        var re = /[A-Z]/;

        tags.forEach(processTag);

        return list;

        function processTag(tag) {
          var firstChar = tag.name.substring(0, 1).toUpperCase();

          if (!re.test(firstChar)) {
            firstChar = '#';
          }

          if (angular.isUndefined(list[firstChar])) {
            list[firstChar] = [];
          }

          // Trim the data to only the data points we care about.
          list[firstChar].push(new Tag({
            id: tag.id,
            name: tag.name,
            count: tag.count
          }));
        }
      }
    }

    return Tag;
  }
})();
