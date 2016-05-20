//= require import

/* global miqSparkleOn miqSparkleOff showSuccessMessage showErrorMessage showWarningMessage clearMessages */

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

  renderGitImport: function(branchesAndTags, gitRepoId, messages) {
    if (JSON.parse(messages).level === "error") {
      showErrorMessage(JSON.parse(message).message);
    } else {
      $('.hidden-git-repo-id').val(gitRepoId);
      $('.git-import-data').show();
      $('.import-or-export').hide();
      showSuccessMessage(JSON.parse(messages).message);

      $.each(JSON.parse(branchesAndTags), function(index, child) {
        $('select.git-branches-and-tags').append(
          $('<option>', {
          value: child,
          text: child
        })
        );
      });

      $('select.git-branches-and-tags').selectpicker('refresh');
    }
  },

  addDomainOptions: function(domains) {
    $('select.importing-domains').empty();

    $.each(domains, function(_index, child) {
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
    $.each(domains, function(_index, child) {
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

    $('.git-import-submit').click(function(event) {
      event.preventDefault();
      miqSparkleOn();
      clearMessages();

      $.post('import_via_git', $('#git-branch-tag-form').serialize(), function(data) {
        var flashMessage = data[0];
        if (flashMessage.level == 'error') {
          showErrorMessage(flashMessage.message);
        } else {
          showSuccessMessage(flashMessage.message);
        }

        $('.import-or-export').show();
        $('.git-import-data').hide();
        $('#git-url-import').prop('disabled', null);

        miqSparkleOff();
      }, 'json');
    });

    $('.import-back').click(function(event) {
      event.preventDefault();
      miqSparkleOn();
      clearMessages();

      $('.domain-tree').dynatree('destroy');

      $.post('cancel_import', $('#import-form').serialize(), function(data) {
        var flashMessage = JSON.parse(data)[0];
        showSuccessMessage(flashMessage.message);

        $('.import-or-export').show();
        $('.import-data').hide();
        miqSparkleOff();
      });
    });

    $('.git-import-cancel').click(function() {
      clearMessages();
      $('.import-or-export').show();
      $('.import-data').hide();
      showSuccessMessage('Import cancelled');
    });

    $('#toggle-all').click(function() {
      $('.domain-tree').dynatree('getRoot').visit(function(node) {
        node.select($('#toggle-all').prop('checked'));
      });
    });
  }
};
