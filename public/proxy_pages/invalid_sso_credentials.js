throw "error";
$('#invalid_sso_credentials_flash').click(function() {
  $(this).hide();
});
$('#invalid_sso_credentials_flash').show();
miqSparkle(false);
miqEnableLoginFields(true);
