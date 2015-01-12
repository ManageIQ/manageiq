// MIQ unobtrusive javascript bindings run when document is fully loaded

$j(document).ready(function(){

	// Bind call to prompt if leaving an active edit
	$j('a[data-miq_check_for_changes]').live('ajax:beforeSend', function() {
			return miqCheckForChanges();
	})

	// Bind call to check/display text area max length on keyup
	$j('textarea[data-miq_check_max_length]').live('keyup', function() {
			miqCheckMaxLength(this);
	})

	// Bind the MIQ spinning Q to configured links
	$j('a[data-miq_sparkle_on]').live('ajax:beforeSend', function() {
			miqSparkleOn();	// Call to miqSparkleOn since miqSparkle(true) checks XHR count, which is 0 before send
	})
	$j('a[data-miq_login_error]').live('ajax:error', function(xhr, status, error) {
	  js_mimetypes = ["text/javascript", "application/javascript"]
	  if(status.status == 401 && js_mimetypes.indexOf(status.getResponseHeader("Content-Type")) > -1 && status.responseText.length > 0) {
	    $j.globalEval(status.responseText)
	  }
	})
	$j('a[data-miq_sparkle_off]').live('ajax:complete', function() {
			miqSparkle(false);
	})

	// Bind in the observe support. If interval is configured, use the observe_field function
	$j('[data-miq_observe]').live('focus', function() {
		var parms = $j.parseJSON(this.getAttribute('data-miq_observe'));
		var interval = parms.interval;
		var url = parms.url;
		var submit = parms.submit;
		if (typeof interval == "undefined") {	// No interval passed, use event observer
      this.stopObserving(); // Use prototype to stop observing this element, prevents multi ajax transactions
      var el = $j(this);
      el.unbind('change')
      el.change(function() {
        miqJqueryRequest(url, {beforeSend: true,
          complete: true,
          data: el.attr('id') + '=' + encodeURIComponent(el.prop('value')),
          no_encoding: true
        });
			})
		} else {
      $j(this).off(); // Use jQuery to turn off observe_field, prevents multi ajax transactions
      var el = $j(this);
      el.observe_field(interval, function(){
				var oneTrans = this.getAttribute('data-miq_send_one_trans');	// Grab one trans URL, if present
				if (typeof submit != "undefined"){										// If submit element passed in
          miqJqueryRequest(url, {beforeSend: true, complete: true, data: Form.serialize(submit)});
				} else if (oneTrans) {
					miqSendOneTrans(url);
				} else {
          var urlstring = url + "?" + el.attr('id') + "=" + encodeURIComponent(el.prop('value'));	//  tack on the id and value to the URL
          miqJqueryRequest(urlstring, {no_encoding: true});
        }
			});
		}
	});

	// Bind click support for checkboxes, seems only click event works in FF/IE/Chrome
	// TODO: This binding is commented out because it doesn't work under dhtmlx tabs, may use later
//	$j('[data-miq_observe_checkbox]').live('click', function() {
//		var parms = $j.parseJSON(this.getAttribute('data-miq_observe_checkbox'));
//		var url = parms.url;
//		var sparkleOn = this.getAttribute('data-miq_sparkle_on');	// Grab miq_sparkle settings
//		var sparkleOff = this.getAttribute('data-miq_sparkle_off');
//		new $j.ajax(url,
//										{
//											dataType: 'script',
//											beforeSend: function() {if (sparkleOn) miqSparkle(true);},
//											complete: function() {if (sparkleOff) miqSparkle(false);},
//											parameters:this.id + '=' + encodeURIComponent(this.checked ? this.value : 'null')
//										}
//		);
//	});

// Following example code from http://www.alfajango.com/blog/rails-3-remote-links-and-forms/
//
//  $('#create_comment_form')
//    .bind("ajax:beforeSend", function(evt, xhr, settings){
//      var $submitButton = $(this).find('input[name="commit"]');
//
//      // Update the text of the submit button to let the user know stuff is happening.
//      // But first, store the original text of the submit button, so it can be restored when the request is finished.
//      $submitButton.data( 'origText', $(this).text() );
//      $submitButton.text( "Submitting..." );
//
//    })
//    .bind("ajax:success", function(evt, data, status, xhr){
//      var $form = $(this);
//
//      // Reset fields and any validation errors, so form can be used again, but leave hidden_field values intact.
//      $form.find('textarea,input[type="text"],input[type="file"]').val("");
//      $form.find('div.validation-error').empty();
//
//      // Insert response partial into page below the form.
//      $('#comments').append(xhr.responseText);
//
//    })
//    .bind('ajax:complete', function(evt, xhr, status){
//      var $submitButton = $(this).find('input[name="commit"]');
//
//      // Restore the original submit button text
//      $submitButton.text( $(this).data('origText') );
//    })
//    .bind("ajax:error", function(evt, xhr, status, error){
//      var $form = $(this),
//          errors,
//          errorText;
//
//      try {
//        // Populate errorText with the comment errors
//        errors = $.parseJSON(xhr.responseText);
//      } catch(err) {
//        // If the responseText is not valid JSON (like if a 500 exception was thrown), populate errors with a generic error message.
//        errors = {message: "Please reload the page and try again"};
//      }
//
//      // Build an unordered list from the list of errors
//      errorText = "There were errors with the submission: \n<ul>";
//
//      for ( error in errors ) {
//        errorText += "<li>" + error + ': ' + errors[error] + "</li> ";
//      }
//
//      errorText += "</ul>";
//
//      // Insert error list into form
//      $form.find('div.validation-error').html(errorText);
//    });

	// Run this last to be sure all other UJS bindings have been run in case the focus field is observed
	$j('[data-miq_focus]').each(function(index) {
		this.focus();
	})

});
