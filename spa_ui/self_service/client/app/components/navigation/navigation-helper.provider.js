(function() {
  'use strict';

  angular.module('app.components')
    .provider('navigationHelper', NavigationHelperProvider);

  /** @ngInject */
  function NavigationHelperProvider(lodash) {
    var provider = {
      configure: configure,
      $get: NavigationHelper
    };

    var config = {
      glue: '.',
      brandState: 'dashboard',
      items: {
        nav: [],
        sidebar: []
      },
      searches: {
        nav: new NavigationSearch(),
        sidebar: new NavigationSearch()
      }
    };

    return provider;

    function configure(cfg) {
      angular.extend(config, cfg);
    }

    /** @ngInject */
    function NavigationHelper($injector) {
      var service = {
        navItems: lodash.partial(navigationItems, 'nav'),
        navSearch: lodash.partial(navigationSearch, 'nav'),
        removeNavItem: lodash.partial(removeNavigationItem, 'nav'),

        sidebarItems: lodash.partial(navigationItems, 'sidebar'),
        sidebarSearch: lodash.partial(navigationSearch, 'sidebar'),
        removeSidebarItem: lodash.partial(removeNavigationItem, 'sidebar'),

        brandState: brandState
      };

      return service;

      function navigationItems(root, data) {
        var builder = lodash.partial(createItem, root);

        // Get all items
        if (null === data || angular.isUndefined(data)) {
          return getItem(lodash.sortBy(lodash.filter(config.items[root], filterVisible), 'order'));
        }

        // Get single item by path
        if (angular.isString(data)) {
          return lodash.find(config.items[root], 'path', data);
        }

        // Create one or more items
        if (angular.isObject(data)) {
          angular.forEach(data, builder);
        }

        function createItem(root, options, path) {
          config.items[root].push(new NavigationItem(path, options));
        }

        function getItem(scope) {
          var items = getChildren({path: ''});

          function getChildren(item) {
            item.items = lodash.filter(scope, 'parent', item.path);
            lodash.forEach(item.items, getChildren);

            return item;
          }

          return items.items;
        }

        function filterVisible(item) {
          return $injector.invoke(item.isVisible);
        }
      }

      function removeNavigationItem(root, path) {
        var tags = path.split(config.glue);
        var tag = tags.pop();
        var scope;

        if (1 === tags.length) {
          scope = config.items[root];
        } else {
          tag = tags.pop();
          scope = config.items[root].getChild(tag);
        }

        if (scope) {
          scope.removeChild(tag);
        }
      }

      function brandState() {
        return config.brandState;
      }

      function navigationSearch(root) {
        return config.searches[root];
      }
    }

    function NavigationItem(path, options) {
      var self = this;

      self.path = path;
      self.parent = path.split(config.glue).slice(0, -1).join(config.glue);

      init();

      function init() {
        // Visibility
        self.isVisible = isVisible;
        // Set defaults
        self.order = 0;
        self.collapsed = true;
        configure(options || {});
      }

      function configure(options) {
        angular.extend(self, options);
      }

      function isVisible() {
        return true;
      }
    }

    function NavigationSearch(options) {
      var self = this;

      init();

      function init() {
        // Set Defaults
        self.value = null;
        self.visible = false;
        self.icon = 'fa-search';
        self.placeholder = 'search site';
        self.onSubmit = function() {
        };
        configure(options || {});
      }

      function configure(options) {
        angular.extend(self, options);
      }
    }
  }
})();
