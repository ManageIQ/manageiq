var msg = "Invalid Single Sign-On credentials"
$('#flash_msg_div').text("");

var outerMost = $("<div id='flash_text_div' onclick=$('#flash_msg_div').text(''); title='Click to remove messages'>");
var txt = $('<strong>' + msg + '</strong>');

var outerBox = $('<div class="alert alert-danger">');
var innerSpan = $('<span class="pficon-layered">');
var icon1 = $('<span class="pficon pficon-error-octagon">');
var icon2 = $('<span class="pficon pficon-warning-exclamation">');

$(innerSpan).append(icon1);
$(innerSpan).append(icon2);

$(outerBox).append(innerSpan);
$(outerBox).append(txt);
$(outerMost).append(outerBox);
$(outerMost).appendTo($("#flash_msg_div"));

$('#flash_msg_div').show()

miqSparkle(false)
miqEnableLoginFields(true);
