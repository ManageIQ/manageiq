//= require import

var Automate = {
  listenForAutomatePostMessages: function() {
    window.addEventListener('message', function(event) {
      miqSparkleOff();
      clearMessages();

      var importFileUploadId = event.data.import_file_upload_id;

      if (importFileUploadId) {
        Automate.getAndRenderAutomateJson(importFileUploadId, event.data.message);
      } else {
        var messageData = JSON.parse(event.data.message);

        if (messageData.level == 'warning') {
          showWarningMessage(messageData.message);
        } else {
          showErrorMessage(messageData.message);
        }
      }
    });
  },

  getAndRenderAutomateJson: function(importFileUploadId, message) {
    $('.hidden-import-file-upload-id').val(importFileUploadId);

    $.getJSON("automate_json?import_file_upload_id=" + importFileUploadId)
      .done(function(rows_json) {
      Automate.addDomainOptions(rows_json.children);
      Automate.setupInitialDynatree(rows_json.children);

      $('.importing-domains').change(function() {
        Automate.importingDomainsChangeHandler(rows_json.children);
      });

      $('#import_file_upload_id').val(importFileUploadId);
      $('.import-data').show();
      $('.import-or-export').hide();
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
    $('.importing-domains').empty();

    $.each(domains, function(index, child) {
      $('.importing-domains').append(
        $('<option>', {
        value: child.title,
        text: child.title
      })
      );
    });
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
      if ($('.importing-domains').val() === child.title) {
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
    $('.import-commit').click(function() {
      miqSparkleOn();
      clearMessages();

      var postData = $('#import-form').serialize();
      postData += '&';
      postData = postData.concat($.param($('.domain-tree').dynatree('getTree').serializeArray()));

      $.post('import_automate_datastore', postData, function(data) {
        var flashMessage = JSON.parse(data).first();
        if (flashMessage.level == 'error') {
          showErrorMessage(flashMessage.message);
        } else {
          showSuccessMessage(flashMessage.message);
        }

        miqSparkleOff();
      });
    });

    $('.import-back').click(function() {
      miqSparkleOn();
      clearMessages();

      $('.domain-tree').dynatree('destroy');

      $.post('cancel_import', $('#import-form').serialize(), function(data) {
        var flashMessage = JSON.parse(data).first();
        showSuccessMessage(flashMessage.message);

        $('.import-or-export').show();
        $('.import-data').hide();
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
