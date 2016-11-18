//= require import

/* global miqSparkleOn miqSparkleOff showSuccessMessage showErrorMessage showWarningMessage clearMessages */

var Automate = {
  getAndRenderAutomateJson: function(importFileUploadId, message) {
    $('.hidden-import-file-upload-id').val(importFileUploadId);

    $.getJSON('automate_json?import_file_upload_id=' + importFileUploadId)
      .done(function(rows_json) {
        Automate.addDomainOptions(rows_json);
        Automate.setupInitialTree(rows_json);

        $('select.importing-domains').change(function() {
          Automate.importingDomainsChangeHandler(rows_json);
        });

        $('#import_file_upload_id').val(importFileUploadId);
        $('.import-data').show();
        $('.import-or-export').hide();
        showSuccessMessage(JSON.parse(message).message);
      })
      .fail(function(failedMessage) {
        var messageData = JSON.parse(failedMessage.responseText);

        if (messageData.level === 'warning') {
          showWarningMessage(messageData.message);
        } else {
          showErrorMessage(messageData.message);
        }
      });
  },

  renderGitImport: function(branches, tags, gitRepoId, messages) {
    clearMessages();
    var message = JSON.parse(messages).message;
    var messageLevel = JSON.parse(messages).level;

    if (messageLevel === 'error') {
      showErrorMessage(message);
    } else {
      $('.hidden-git-repo-id').val(gitRepoId);
      $('.git-import-data').show();
      $('.import-or-export').hide();
      if (messageLevel === 'warning') {
        showWarningMessage(message);
      } else {
        showSuccessMessage(message);
      }

      var addToDropDown = function(identifier, child) {
        $('select.git-' + identifier).append(
          $('<option>', {
            value: child,
            text: child,
          })
        );
      };

      $.each(JSON.parse(branches), function(_index, child) {
        addToDropDown('branches', child);
      });
      $.each(JSON.parse(tags), function(_index, child) {
        addToDropDown('tags', child);
      });

      Automate.selectDefaultBranch();

      $('select.git-branches').selectpicker('refresh');
      $('select.git-tags').selectpicker('refresh');
    }

    miqSparkleOff();
  },

  selectDefaultBranch: function() {
    if ($('select.git-branches').find('option[value="origin/master"]').length === 0) {
      $('select.git-branches').prop('selectedIndex', 0);
    } else {
      $('select.git-branches').val('origin/master');
    }

    $('.git-branch-or-tag').val($('select.git-branches').val());
    $('.git-import-submit').prop('disabled', false);
  },

  addDomainOptions: function(domains) {
    $('select.importing-domains').empty();

    $.each(domains, function(_index, child) {
      $('select.importing-domains').append(
        $('<option>', {
          value: child.key,
          text:  child.text,
        })
      );
    });

    $('select.importing-domains').selectpicker('refresh');
  },

  setupInitialTree: function(domains) {
    $('.domain-tree').treeview({
      data:              domains[0].nodes,
      levels:            1,
      showCheckbox:      true,
      showImage:         true,
      hierarchicalCheck: true,
      expandIcon:        'fa fa-fw fa-chevron-right',
      collapseIcon:      'fa fa-fw fa-chevron-down',
    });
  },

  importingDomainsChangeHandler: function(domains) {
    $.each(domains, function(_index, child) {
      if ($('select.importing-domains').val() === child.key) {
        $('.domain-tree').treeview({
          data:              child.nodes,
          levels:            1,
          showCheckbox:      true,
          showImage:         true,
          hierarchicalCheck: true,
          expandIcon:        'fa fa-fw fa-chevron-right',
          collapseIcon:      'fa fa-fw fa-chevron-down',
        });
      }
    });

    $('#toggle-all').prop('checked', false);
  },

  setUpAutomateImportClickHandlers: function() {
    var tearDownGitImportOptions = function() {
      $('select.git-branches').find('option').remove().end();
      $('select.git-tags').find('option').remove().end();
      $('select.git-branches').selectpicker('refresh');
      $('select.git-tags').selectpicker('refresh');

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

      var treeName = $('.domain-tree').attr('name');
      var serialized = $.param($('.domain-tree').treeview(true).getChecked().map(function(node) {
        return {name: treeName, value: node.key};
      }));
      postData = postData.concat(serialized);

      $.post('import_automate_datastore', postData, function(data) {
        var flashMessage = JSON.parse(data)[0];
        if (flashMessage.level === 'error') {
          showErrorMessage(flashMessage.message);
        } else {
          showSuccessMessage(flashMessage.message);
        }

        miqSparkleOff();
      });
    });

    Automate.setUpGitRefreshClickHandlers();

    $('.git-retreive-datastore').click(function() {
      miqSparkleOn();
    });

    $('.git-import-submit').click(function(event) {
      event.preventDefault();
      miqSparkleOn();
      clearMessages();

      $.post('import_via_git', $('#git-branch-tag-form').serialize(), function(data) {
        var flashMessage = data[0];
        if (flashMessage.level === 'error') {
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

      $('.domain-tree').empty();

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

    $('#toggle-all').on('change', function() {
      $('#toggle-all').prop('checked') ? $('.domain-tree').treeview(true).checkAll() : $('.domain-tree').treeview(true).uncheckAll();
    });
  },

  setUpDefaultGitBranchOrTagValue: function() {
    $('.git-branch-or-tag').val($('select.git-branches').val());
  },

  setUpGitRefreshClickHandlers: function() {
    var toggleSubmitButton = function() {
      var branchOrTagSelected = $('.git-branch-or-tag').val() === '';
      $('.git-import-submit').prop('disabled', branchOrTagSelected);
    };

    $('.git-branch-or-tag-select').on('change', function(event) {
      event.preventDefault();
      if ($(event.currentTarget).val() === 'Branch') {
        $('.git-branch-group').show();
        $('.git-tag-group').hide();
        $('.git-branch-or-tag').val($('select.git-branches').val());
      } else if ($(event.currentTarget).val() === 'Tag') {
        $('.git-branch-group').hide();
        $('.git-tag-group').show();
        $('.git-branch-or-tag').val($('select.git-tags').val());
      }
      toggleSubmitButton();
    });

    $('select.git-branches').on('change', function(_event) {
      $('.git-branch-or-tag').val($('select.git-branches').val());
      toggleSubmitButton();
    });

    $('select.git-tags').on('change', function(_event) {
      $('.git-branch-or-tag').val($('select.git-tags').val());
      toggleSubmitButton();
    });
  },
};
