//= require import

var listenForAutomatePostMessages = function() {
  window.addEventListener('message', function(event) {
    miqSparkleOff();
    clearMessages();

    var importFileUploadId = event.data.import_file_upload_id;

    if (importFileUploadId) {
      getAndRenderAutomateJson(importFileUploadId, event.data.message);
    } else {
      var messageData = JSON.parse(event.data.message);

      if (messageData.level == 'warning') {
        showWarningMessage(messageData.message);
      } else {
        showErrorMessage(messageData.message);
      }
    }
  });
};

var getAndRenderAutomateJson = function(importFileUploadId, message) {
  $j('.hidden-import-file-upload-id').val(importFileUploadId);

  $j.getJSON("automate_json?import_file_upload_id=" + importFileUploadId, function(rows_json) {
    addDomainOptions(rows_json.children);
    setupInitialDynatree(rows_json.children);

    $j('.importing-domains').change(function() {
      importingDomainsChangeHandler(rows_json.children);
    });

    $j('#import_file_upload_id').val(importFileUploadId);
    $j('.import-data').show();
    $j('.import-or-export').hide();
  });

  showSuccessMessage(JSON.parse(message).message);
};

var addDomainOptions = function(domains) {
  $j.each(domains, function(index, child) {
    $j('.importing-domains').append(
      $j('<option>', {
        value: child.title,
        text: child.title
      })
    );
  });
};

var setupInitialDynatree = function(domains) {
  $j('.domain-tree').dynatree({
    checkbox: true,
    children: domains[0].children,
    selectMode: 3
  });
};

var importingDomainsChangeHandler = function(domains) {
  $j.each(domains, function(index, child) {
    if ($j('.importing-domains').val() === child.title) {
      $j('.domain-tree').dynatree({
        checkbox: true,
        children: child.children,
        selectMode: 3
      });
      $j('.domain-tree').dynatree('getTree').reload();
    }
  });
};

var setUpAutomateImportClickHandlers = function() {
  $j('.import-commit').click(function() {
    miqSparkleOn();
    clearMessages();

    var postData = $j('#import-form').serialize();
    postData += '&';
    postData = postData.concat($j.param($j('.domain-tree').dynatree('getTree').serializeArray()));

    $j.post('import_automate_datastore', postData, function(data) {
      var flashMessage = JSON.parse(data).first();
      if (flashMessage.level == 'error') {
        showErrorMessage(flashMessage.message);
      } else {
        showSuccessMessage(flashMessage.message);
      }

      miqSparkleOff();
    });
  });

  $j('.import-back').click(function() {
    miqSparkleOn();
    clearMessages();

    $j.post('cancel_import', $j('#import-form').serialize(), function(data) {
      var flashMessage = JSON.parse(data).first();
      showSuccessMessage(flashMessage.message);

      $j('.import-or-export').show();
      $j('.import-data').hide();
      miqSparkleOff();
    });
  });
};
