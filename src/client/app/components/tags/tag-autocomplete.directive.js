(function() {
  'use strict';

  angular.module('app.components')
    .directive('tagAutocomplete', TagAutocompleteDirective);

  /** @ngInject */
  function TagAutocompleteDirective(logger, lodash, $q, KEYS, DirectiveOptions) {
    var directive = {
      restrict: 'AE',
      require: '^tagField',
      scope: {
        source: '&'
      },
      link: link,
      templateUrl: 'app/components/tags/tag-autocomplete.html',
      controller: TagAutocompleteController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function scrollToElement(root, index) {
      var element = root.find('li').eq(index);
      var parent = element.parent();
      var elementTop = element.prop('offsetTop');
      var elementHeight = element.prop('offsetHeight');
      var parentHeight = parent.prop('clientHeight');
      var parentScrollTop = parent.prop('scrollTop');

      if (elementTop < parentScrollTop) {
        parent.prop('scrollTop', elementTop);
      } else if (elementTop + elementHeight > parentHeight + parentScrollTop) {
        parent.prop('scrollTop', elementTop + elementHeight - parentHeight);
      }
    }

    function link(scope, element, attrs, tagField, transclude) {
      var vm = scope.vm;
      var hotkeys = [KEYS.enter, KEYS.tab, KEYS.escape, KEYS.up, KEYS.down];

      DirectiveOptions.load(vm, attrs, {
        debounceDelay: [Number, 275]
      });

      vm.activate(tagField);

      tagField.events
        .on('tag-added tag-invalid input-blur', vm.suggestionList.reset)
        .on('input-change', inputChanged)
        .on('input-focus', inputFocused)
        .on('input-keydown', inputKeydown);

      vm.events
        .on('suggestion-selected', suggestionSelected);

      function inputChanged(value) {
        if (shouldLoadSuggestions(value)) {
          vm.suggestionList.load(value);
        } else {
          vm.suggestionList.reset();
        }
      }

      function inputFocused() {
        var value = tagField.newTag;

        if (shouldLoadSuggestions(value)) {
          vm.suggestionList.load(value);
        }
      }

      function inputKeydown(event) {
        var key = event.keyCode;
        var handled = false;

        if (-1 === hotkeys.indexOf(key)) {
          return;
        }

        if (vm.suggestionList.visible) {
          // Visible
          if (key === KEYS.down) {
            vm.suggestionList.selectNext();
            handled = true;
          } else if (key === KEYS.up) {
            vm.suggestionList.selectPrevious();
            handled = true;
          } else if (key === KEYS.escape) {
            vm.suggestionList.reset();
            handled = true;
          } else if (key === KEYS.enter || key === KEYS.tab) {
            handled = vm.addSuggestion();
          }
        } else {
          // Not visible
          if (key === KEYS.down) {
            vm.suggestionList.load(tagField.newTag);
            handled = true;
          }
        }

        if (handled) {
          event.preventDefault();
          event.stopImmediatePropagation();

          return false;
        }
      }

      function suggestionSelected(index) {
        scrollToElement(element, index);
      }

      // Private

      function shouldLoadSuggestions(value) {
        return !!(value && value.length >= tagField.options.minLength);
      }
    }

    /** @ngInject */
    function TagAutocompleteController(PubSub) {
      var vm = this;

      vm.activate = activate;
      vm.addSuggestion = addSuggestion;
      vm.addSuggestionByIndex = addSuggestionByIndex;

      function activate(tagField) {
        vm.mode = tagField.mode;
        vm.events = PubSub.events();
        vm.tagField = tagField;
        vm.suggestionList = new SuggestionList(vm.source, vm.options, vm.events);
      }

      function addSuggestion() {
        var added = false;

        if (vm.suggestionList.selected) {
          vm.tagField.addTag(angular.copy(vm.suggestionList.selected));
          vm.suggestionList.reset();
          vm.tagField.focusInput();
          added = true;
        }

        return added;
      }

      function addSuggestionByIndex(index) {
        vm.suggestionList.select(index);
        addSuggestion();
      }
    }

    function SuggestionList(loadFn, options, events) {
      var self = this;

      var lastPromise = null;

      self.items = [];
      self.visible = false;
      self.index = -1;
      self.selected = null;
      self.query = null;

      self.reset = reset;
      self.show = show;
      self.load = lodash.debounce(load, options.debounceDelay);
      self.select = select;
      self.selectNext = selectNext;
      self.selectPrevious = selectPrevious;

      function reset() {
        lastPromise = null;
        self.items.length = 0;
        self.visible = false;
        self.index = -1;
        self.selected = null;
        self.query = null;
      }

      function show() {
        select(0);
        self.visible = true;
      }

      function load(query) {
        self.query = query;

        var promise = $q.when(loadFn({query: query}));

        lastPromise = promise;
        promise.then(onResults);

        function onResults(items) {
          if (promise !== lastPromise) {
            return;
          }

          self.items = items;
          if (self.items.length > 0) {
            self.show();
          } else {
            self.reset();
          }
        }
      }

      function select(index) {
        if (index < 0) {
          index = self.items.length - 1;
        } else if (index >= self.items.length) {
          index = 0;
        }
        self.index = index;
        self.selected = self.items[index];
        events.trigger('suggestion-selected', index);
      }

      function selectNext() {
        select(++self.index);
      }

      function selectPrevious() {
        select(--self.index);
      }
    }
  }
})();
