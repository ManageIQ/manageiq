(function() {
  'use strict';

  angular.module('app.components')
    .directive('tagShowModal', TagShowModalDirective);

  /** @ngInject */
  function TagShowModalDirective() {
    var directive = {
      restrict: 'AE',
      require: '^tagField',
      scope: {},
      link: link,
      transclude: true,
      templateUrl: 'app/components/tags/tag-show-modal.html',
      controller: TagShowModalController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, tagField, transclude) {
      var vm = scope.vm;

      vm.activate(tagField);
    }

    /** @ngInject */
    function TagShowModalController(Tag, $modal) {
      var vm = this;

      var modalOptions = {};

      vm.activate = activate;
      vm.showModal = showModal;

      function activate(tagField) {
        vm.mode = tagField.mode;
        vm.tagField = tagField;
        modalOptions = {
          templateUrl: 'app/components/tags/tag-modal.html',
          controller: TagModalController,
          controllerAs: 'vm',
          resolve: {
            tagList: resolveTagList,
            tagCommands: resolveTagCommands,
            tags: resolveTags,
            mode: resolveMode
          },
          windowTemplateUrl: 'app/components/tags/tag-modal-window.html'
        };
      }

      function showModal() {
        var modal = $modal.open(modalOptions);

        modal.result.then();
      }

      // Private

      function resolveTagList() {
        return vm.tagField.tagList;
      }

      function resolveTagCommands() {
        return {
          add: vm.tagField.addTag,
          remove: vm.tagField.removeTag,
          clear: vm.tagField.clearTags
        };
      }

      function resolveTags() {
        return Tag.grouped();
      }

      function resolveMode() {
        return vm.mode;
      }
    }

    /** @ngInject */
    function TagModalController(tagList, tagCommands, tags, mode, $location, $timeout) {
      var vm = this;

      vm.tagList = tagList;
      vm.addTag = tagCommands.add;
      vm.removeTag = tagCommands.remove;
      vm.clearTags = tagCommands.clear;
      vm.tags = tags;

      vm.shortcuts = '#ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');

      vm.tagsExistForLetter = tagsExistForLetter;
      vm.tagInUse = tagInUse;
      vm.tagUnavailable = tagUnavailable;
      vm.gotoHash = gotoHash;

      function tagsExistForLetter(letter) {
        return angular.isDefined(vm.tags[letter]);
      }

      function tagInUse(tag) {
        return vm.tagList.tagInList(tag);
      }

      function tagUnavailable(tag) {
        if ('search' === mode) {
          return tagInUse(tag.name) || 0 === tag.results;
        } else {
          return tagInUse(tag.name);
        }
      }

      // Remove the hash fragment from the URL which can cause the $digest to infinitely loop
      // TODO: Use a method that doesn't alter $location
      function gotoHash(letter) {
        $location.hash(letter);
        $timeout(function() {
          $location.hash('');
        });
      }
    }
  }
})();
