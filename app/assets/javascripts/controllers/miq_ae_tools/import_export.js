//= require import
// ^^ TODO: still needed?

var MAGIC = {};

(function() {
  "use strict";

  ManageIQ.angular.app
    .directive('miqAeToolsImportExport', MiqAeToolsImportExport);


  MiqAeToolsImportExport.$inject = [];

  function MiqAeToolsImportExport() {
    return {
      restrict: 'E',
      scope: {},
      controller: ImportExportCtrl,
      controllerAs: 'vm',
      bindToController: true,
      link: function(scope, elem, attrs, ctrl) {
        ctrl.init();
      },
      // template
    };
  }


  ImportExportCtrl.$inject = ['$http', 'miqService'];

  function ImportExportCtrl($http, miqService) {
    var vm = this;

    vm.import_uploaded = false;
    vm.init = function() {
      AutomateImportSetup.listenForPostMessages(Automate.getAndRenderAutomateJson);
      Automate.setUpAutomateImportClickHandlers();
    };

    MAGIC.vm = vm;
  }

})();





var AutomateImportSetup = {
  listenForPostMessages: function(getAndRenderJsonCallback) {
    window.addEventListener('message', function(event) {
      AutomateImportSetup.respondToPostMessages(event, getAndRenderJsonCallback);
    });
  },

  respondToPostMessages: function(event, getAndRenderJsonCallback) {
    miqSparkleOff();
    clearMessages();

    var importFileUploadId = event.data.import_file_upload_id;

    if (importFileUploadId) {
      getAndRenderJsonCallback(importFileUploadId, event.data.message);
    } else {
      var unencodedMessage = event.data.message.replace(/&quot;/g, '"');
      var messageData = JSON.parse(unencodedMessage);

      if (messageData.level == 'warning') {
        showWarningMessage(messageData.message);
      } else {
        showErrorMessage(messageData.message);
      }
    }
  }
};

var Automate = {
  getAndRenderAutomateJson: function(importFileUploadId, message) {
    $('.hidden-import-file-upload-id').val(importFileUploadId);

    $.getJSON("automate_json?import_file_upload_id=" + importFileUploadId)
      .done(function(rows_json) {
      Automate.addDomainOptions(rows_json.children);
      Automate.setupInitialDynatree(rows_json.children);

      $('select.importing-domains').change(function() {
        Automate.importingDomainsChangeHandler(rows_json.children);
      });

      $('#import_file_upload_id').val(importFileUploadId);
      MAGIC.vm.import_uploaded = true;

      showSuccessMessage(JSON.parse(message).message);
    })
    .fail(function(failedMessage) {
      var messageData = JSON.parse(failedMessage.responseText);

      if (messageData.level == 'warning') {
        showWarningMessage(messageData.message);
      } else {
        showErrorMessage(messageData.message);
      }
    });

  },

  addDomainOptions: function(domains) {
    $('select.importing-domains').empty();

    $.each(domains, function(index, child) {
      $('select.importing-domains').append(
        $('<option>', {
          value: child.title,
          text: child.title
        })
      );
    });

    $('select.importing-domains').selectpicker('refresh');
  },

  setupInitialDynatree: function(domains) {
    $('.domain-tree').dynatree({
      checkbox: true,
      children: domains[0].children,
      selectMode: 3
    });
  },

  importingDomainsChangeHandler: function(domains) {
    $.each(domains, function(index, child) {
      if ($('select.importing-domains').val() === child.title) {
        $('.domain-tree').dynatree({
          checkbox: true,
          children: child.children,
          selectMode: 3
        });
        $('.domain-tree').dynatree('getTree').reload();
      }
    });

    $('#toggle-all').prop('checked', false);
  },

  setUpAutomateImportClickHandlers: function() {
    $('.import-commit').click(function(event) {
      event.preventDefault();
      miqSparkleOn();
      clearMessages();

      var postData = $('#import-form').serialize();
      postData += '&';
      postData = postData.concat($.param($('.domain-tree').dynatree('getTree').serializeArray()));

      $.post('import_automate_datastore', postData, function(data) {
        var flashMessage = JSON.parse(data)[0];
        if (flashMessage.level == 'error') {
          showErrorMessage(flashMessage.message);
        } else {
          showSuccessMessage(flashMessage.message);
        }

        miqSparkleOff();
      });
    });

    $('.import-back').click(function(event) {
      event.preventDefault();
      miqSparkleOn();
      clearMessages();

      $('.domain-tree').dynatree('destroy');

      $.post('cancel_import', $('#import-form').serialize(), function(data) {
        var flashMessage = JSON.parse(data)[0];
        showSuccessMessage(flashMessage.message);

        MAGIC.vm.import_uploaded = false;
        miqSparkleOff();
      });
    });

    $('#toggle-all').click(function() {
      $('.domain-tree').dynatree('getRoot').visit(function(node) {
        node.select($('#toggle-all').prop('checked'));
      });
    });
  }
};
