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

  renderGitImport: function(branches, tags, gitRepoId, messages) {
    clearMessages();
    message = JSON.parse(messages).message;
    messageLevel = JSON.parse(messages).level;

    if (messageLevel === "error") {
      showErrorMessage(message);
    } else {
      $('.hidden-git-repo-id').val(gitRepoId);
      $('.git-import-data').show();
      $('.import-or-export').hide();
      if (messageLevel === "warning") {
        showWarningMessage(message);
      } else {
        showSuccessMessage(message);
      }

      var addToDropDown = function(identifier, child) {
        $('select.git-' + identifier).append(
          $('<option>', {
            value: child,
            text: child
          })
        );
      };

      $.each(JSON.parse(branches), function(index, child) {
        addToDropDown('branches', child);
      });
      $.each(JSON.parse(tags), function(index, child) {
        addToDropDown('tags', child);
      });

      $('select.git-branches').selectpicker('refresh');
      $('select.git-tags').selectpicker('refresh');
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
    var tearDownGitImportOptions = function() {
      $('.git-branches').find('option').remove().end();
      $('.git-tags').find('option').remove().end();
      $('.git-branches').selectpicker('refresh');
      $('.git-tags').selectpicker('refresh');

      $('.import-or-export').show();
      $('.git-import-data').hide();
      $('#git-url-import').prop('disabled', null);
    };

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

    Automate.setUpGitRefreshClickHandlers();

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

        tearDownGitImportOptions();

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

    $('.git-import-cancel').click(function(event) {
      event.preventDefault();
      clearMessages();
      tearDownGitImportOptions();
      showSuccessMessage('Import cancelled');
    });

    $('#toggle-all').click(function() {
      $('.domain-tree').dynatree('getRoot').visit(function(node) {
        node.select($('#toggle-all').prop('checked'));
      });
    });
  },

  setUpGitRefreshClickHandlers: function() {
    $('.git-branch-or-tag-select').on('change', function(event) {
      event.preventDefault();
      if ($(event.currentTarget).val() === "Branch") {
        $('.git-branch-group').show();
        $('.git-tag-group').hide();
        $('.git-branch-or-tag').val($('.git-branches').val());
      } else {
        $('.git-branch-group').hide();
        $('.git-tag-group').show();
        $('.git-branch-or-tag').val($('.git-tags').val());
      }
    });

    $('.git-branches').on('change', function(event) {
      $('.git-branch-or-tag').val($(event.currentTarget).val());
    });

    $('.git-tags').on('change', function(event) {
      $('.git-branch-or-tag').val($(event.currentTarget).val());
    });
  }
};
