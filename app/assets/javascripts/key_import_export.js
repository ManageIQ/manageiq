//= require import

var listenForKeyPostMessages = function() {
  window.addEventListener('message', function(event) {
    miqSparkleOff();
    clearMessages();

    var sshKeypairPassword = event.data.ssh_keypair_password;
    if (sshKeypairPassword) {
      $('.hidden-ssh_keypair_password').val(sshKeypairPassword);
    }
  });
};
