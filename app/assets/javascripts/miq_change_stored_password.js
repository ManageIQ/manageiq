function changeStoredPassword(password_field, verify_field, url) {
  $('#change_stored_password').css('display', 'none');
  $('#cancel_password_change').css('display', 'block');
  $('#verify_group').css('display', 'block');
  $('#' + password_field).removeAttr('disabled');
  $('#' + verify_field).removeAttr('disabled');
  $('#' + password_field).val('');
  $('#' + verify_field).val('');
  miqJqueryRequest(url + '?' + password_field + '=' + '&' + verify_field + '=');
  $('#' + password_field).focus();
};

function cancelPasswordChange(password_field, verify_field, url) {
  var storedPasswordPlaceholder = '●●●●●●●●'
  $('#cancel_password_change').css('display', 'none');
  $('#change_stored_password').css('display', 'block');
  $('#verify_group').css('display', 'none');
  $('#' + password_field).attr('disabled', 'disabled');
  $('#' + verify_field).attr('disabled', 'disabled');
  $('#' + password_field).val(storedPasswordPlaceholder);
  $('#' + verify_field).val(storedPasswordPlaceholder);
  miqJqueryRequest(url + '?' + password_field + '=' + '&' + verify_field + '=' + '&restore_password=true');
};
