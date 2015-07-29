(function() {
  'use strict';

  angular.module('app.components')
    .filter('tags', TagsFilter);

  /** @ngInject */
  function TagsFilter(lodash) {
    return filter;

    function filter(items, tagList, allMatch) {
      var filtered = [];

      tagList = tagList || [];
      allMatch = !!allMatch;

      if (0 === tagList.length) {
        return items;
      }

      filtered = lodash.filter(items, checkTags);

      return filtered;

      function checkTags(item) {
        var matches = lodash.intersection(tagList, item.tags).length;

        if (allMatch) {
          return tagList.length === matches;
        } else {
          return 0 < matches;
        }
      }
    }
  }
})();
