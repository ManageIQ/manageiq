function changeStoredPassword(pfx, url) {
  $('#' + pfx + '_change_stored_password').css('display', 'none');
  $('#' + pfx + '_cancel_password_change').css('display', 'block');
  $('#' + pfx + '_verify_group').css('display', 'block');
  $('#' + pfx + '_password').removeAttr('disabled');
  $('#' + pfx + '_verify').removeAttr('disabled');
  $('#' + pfx + '_password').val('');
  $('#' + pfx + '_verify').val('');
  miqJqueryRequest(url + '?' + pfx + '_password' + '=' + '&' + pfx + '_verify' + '=');
  $('#' + pfx + '_password').focus();
};

function cancelPasswordChange(pfx, url) {
  var storedPasswordPlaceholder = '●●●●●●●●'
  $('#' + pfx + '_cancel_password_change').css('display', 'none');
  $('#' + pfx + '_change_stored_password').css('display', 'block');
  $('#' + pfx + '_verify_group').css('display', 'none');
  $('#' + pfx + '_password').attr('disabled', 'disabled');
  $('#' + pfx + '_verify').attr('disabled', 'disabled');
  $('#' + pfx + '_password').val(storedPasswordPlaceholder);
  $('#' + pfx + '_verify').val(storedPasswordPlaceholder);
  miqJqueryRequest(url + '?' + pfx + '_password' + '=' + '&' + pfx + '_verify' + '=' + '&restore_password=true');
};
