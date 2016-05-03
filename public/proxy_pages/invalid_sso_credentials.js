$('#invalid_sso_credentials_flash').click(function() {
  $(this).text('');
});
$('#invalid_sso_credentials_flash').show()
miqSparkle(false)
miqEnableLoginFields(true);
