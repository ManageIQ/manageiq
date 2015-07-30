(function() {
  'use strict';

  angular.module('app.components')
    .directive('tagField', TagFieldDirective);

  /** @ngInject */
  function TagFieldDirective($document, $timeout, $window, KEYS, lodash, DirectiveOptions) {
    var directive = {
      restrict: 'AE',
      require: 'ngModel',
      scope: {
        tags: '=ngModel',
        onTagAdding: '&?',
        onTagAdded: '&?',
        onTagRemoving: '&?',
        onTagRemoved: '&?',
        onTagsCleared: '&?',
        onInvalidTag: '&?',
        mode: '@?tagMode'
      },
      transclude: true,
      link: link,
      templateUrl: templateUrl,
      controller: TagFieldController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function templateUrl(element, attrs) {
      var mode = attrs.tagMode || 'field';
      var url;

      if ('search' === mode) {
        url = 'app/components/tags/tag-search.html';
      } else {
        url = 'app/components/tags/tag-field.html';
      }

      return url;
    }

    function link(scope, element, attrs, ngModelCtrl, transclude) {
      var vm = scope.vm;
      var input = element.find('input');
      var hotKeys = [KEYS.enter, KEYS.comma, KEYS.space, KEYS.backspace, KEYS.delete, KEYS.left, KEYS.right];
      var addKey = {};
      var removeKey = {};
      var selectKey = {};

      activate();

      function activate() {
        var api = {
          inputChange: inputChange,
          inputKeydown: inputKeydown,
          inputFocus: inputFocus,
          inputBlur: inputBlur,
          inputPaste: inputPaste,
          hostClick: hostClick,
          focusInput: focusInput
        };

        addKey[KEYS.enter] = true;
        addKey[KEYS.comma] = true;
        addKey[KEYS.space] = true;

        removeKey[KEYS.backspace] = true;
        removeKey[KEYS.delete] = true;

        selectKey[KEYS.backspace] = true;
        selectKey[KEYS.left] = true;
        selectKey[KEYS.right] = true;

        attrs.$observe('disabled', setDisabled);

        ngModelCtrl.$isEmpty = isEmpty;

        scope.$watch('vm.tags.length', function() {
          setElementValidity();
          ngModelCtrl.$validate();
        });

        vm.events
          .on('tag-added', lodash.flow(vm.onTagAdded || angular.noop, returnTrueIfUndefined))
          .on('tag-added', clearNewTag)
          .on('invalid-tag', lodash.flow(vm.onInvalidTag || angular.noop, returnTrueIfUndefined))
          .on('invalid-tag', setInvalid)
          .on('tag-removed', lodash.flow(vm.onTagRemoved || angular.noop, returnTrueIfUndefined))
          .on('tags-cleared', lodash.flow(vm.onTagsCleared || angular.noop, returnTrueIfUndefined))
          .on('tag-added tag-removed', setDirty)
          .on('input-change', changed)
          .on('input-focus', focused)
          .on('input-blur', blurred)
          .on('input-keydown', keydown)
          .on('input-paste', paste);

        DirectiveOptions.load(vm, attrs, {
          minTags: [Number, 0],
          maxTags: [Number, 99],
          minLength: [Number, 1],
          maxLength: [Number, 255],
          addFromAutocompleteOnly: [Boolean, false],
          addOnPaste: [Boolean, true],
          pasteSplitPattern: [RegExp, /,/],
          placeholder: [String, 'Add a tag']
        });

        vm.activate(api);
      }

      function setDisabled(value) {
        vm.disabled = value;
      }

      function inputChange(text) {
        vm.events.trigger('input-change', text);
      }

      function inputKeydown($event) {
        vm.events.trigger('input-keydown', $event);
      }

      function inputFocus() {
        if (vm.hasFocus) {
          return;
        }

        vm.hasFocus = true;
        vm.events.trigger('input-focus');
      }

      function inputBlur() {
        $timeout(onBlur);

        function onBlur() {
          var activeElement = $document.prop('activeElement');
          var lostFocusToBrowserWindow = activeElement === input[0];
          var lostFocusToChildElement = element[0].contains(activeElement);

          if (lostFocusToBrowserWindow || !lostFocusToChildElement) {
            vm.hasFocus = false;
            vm.events.trigger('input-blur');
          }
        }
      }

      function inputPaste($event) {
        $event.getTextData = function() {
          var clipboardData = $event.clipboardData || ($event.originalEvent && $event.originalEvent.clipboardData);

          return clipboardData ? clipboardData.getData('text/plain') : $window.clipboardData.getData('Text');
        };
        vm.events.trigger('input-paste', $event);
      }

      function hostClick() {
        if (vm.disabled) {
          return;
        }
        focusInput();
      }

      function focusInput() {
        input[0].focus();
      }

      function setElementValidity() {
        ngModelCtrl.$setValidity('maxTags', vm.tags.length <= vm.options.maxTags);
        ngModelCtrl.$setValidity('minTags', vm.tags.length >= vm.options.minTags);
      }

      function isEmpty(value) {
        return !value || !value.length;
      }

      function clearNewTag() {
        vm.newTag = '';
      }

      function setInvalid() {
        vm.invalid = true;
      }

      function setDirty() {
        ngModelCtrl.$setDirty();
      }

      function changed() {
        vm.tagList.clearSelection();
        vm.invalid = null;
      }

      function focused() {
        element.triggerHandler('focus');
      }

      function blurred() {
        element.triggerHandler('blur');
        setElementValidity();
      }

      function keydown(event) {
        var key = event.keyCode;
        var isModifier = event.shiftKey || event.altKey || event.ctrlKey || event.metaKey;
        var shouldAdd;
        var shouldRemove;
        var shouldSelect;

        if (isModifier || -1 === hotKeys.indexOf(key)) {
          return;
        }

        shouldAdd = !vm.options.addFromAutocompleteOnly && addKey[key];
        shouldRemove = vm.tagList.selected && removeKey[key];
        shouldSelect = vm.newTag.length === 0 && selectKey[key];

        if (shouldAdd || shouldSelect || shouldRemove) {
          handleAction();
        }

        function handleAction() {
          if (shouldAdd) {
            vm.tagList.add(vm.newTag);
          } else if (shouldRemove) {
            vm.tagList.removeSelected();
          } else {
            if (key === KEYS.left || key === KEYS.backspace) {
              vm.tagList.selectPrevious();
            } else {
              vm.tagList.selectNext();
            }
          }

          event.preventDefault();
        }
      }

      function paste(event) {
        if (vm.options.addOnPaste) {
          var data = event.getTextData();
          var tags = data.split(vm.options.pasteSplitPattern);

          if (tags.length > 1) {
            tags.forEach(function(tag) {
              vm.tagList.add(tag);
            });
            event.preventDefault();
          }
        }
      }
    }

    /** @ngInject */
    function TagFieldController(PubSub) {
      var vm = this;

      vm.newTag = '';
      vm.placeholder = '';
      vm.events = PubSub.events();
      vm.tagList = null;
      vm.hasFocus = false;
      vm.invalid = false;
      vm.disabled = false;

      vm.activate = activate;
      vm.clearTags = clearTags;
      vm.removeTag = removeTag;
      vm.addTag = addTag;

      function activate(api) {
        angular.extend(vm, api);
        vm.tags = vm.tags || [];
        vm.onTagAdding = lodash.flow(vm.onTagAdding || angular.noop, returnTrueIfUndefined);
        vm.onTagRemoving = lodash.flow(vm.onTagRemoving || angular.noop, returnTrueIfUndefined);
        vm.tagList = new TagList(vm.options, vm.events, vm.onTagAdding, vm.onTagRemoving);
        vm.tagList.tags = vm.tags;
        vm.mode = angular.isDefined(vm.mode) ? vm.mode : 'field';
      }

      function removeTag(index) {
        if (vm.disabled) {
          return;
        }
        vm.tagList.remove(index);
      }

      function addTag(tag) {
        vm.tagList.add(tag.name);
      }

      function clearTags() {
        if (vm.disabled) {
          return;
        }
        vm.tagList.clear();
      }
    }
  }

  function TagList(options, events, onTagAdding, onTagRemoving) {
    var self = this;

    self.tags = [];
    self.index = -1;
    self.selected = null;

    self.tagInList = tagInList;
    self.add = add;
    self.remove = remove;
    self.clear = clear;
    self.select = select;
    self.selectPrevious = selectPrevious;
    self.selectNext = selectNext;
    self.removeSelected = removeSelected;
    self.clearSelection = clearSelection;

    function add(tag) {
      if (tagIsValid(tag)) {
        self.tags.push(tag);
        events.trigger('tag-added', tag);

        return tag;
      }
      events.trigger('invalid-tag', tag);

      return false;
    }

    function remove(index) {
      var tag = self.tags[index];

      if ((onTagRemoving || angular.identity)(tag)) {
        self.tags.splice(index, 1);
        self.clearSelection();
        events.trigger('tag-removed', tag);

        return tag;
      }

      return false;
    }

    function clear() {
      self.tags.length = 0;
      self.clearSelection();
      events.trigger('tags-cleared');
    }

    function select(index) {
      if (index < 0) {
        index = self.tags.length - 1;
      } else if (index >= self.tags.length) {
        index = 0;
      }

      self.index = index;
      self.selected = self.tags[index];
    }

    function selectPrevious() {
      return select(--self.index);
    }

    function selectNext() {
      return select(++self.index);
    }

    function removeSelected() {
      return remove(self.index);
    }

    function clearSelection() {
      self.index = -1;
      self.selected = null;
    }

    function tagInList(tag) {
      return self.tags.indexOf(tag) !== -1;
    }

    // Private

    function tagIsValid(tag) {
      return tag.length >= options.minLength
        && tag.length <= options.maxLength
        && !tagInList(tag)
        && onTagAdding(tag);
    }
  }

  function returnTrueIfUndefined(result) {
    return angular.isUndefined(result) ? true : result;
  }
})();
