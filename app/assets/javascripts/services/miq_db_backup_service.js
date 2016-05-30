ManageIQ.angular.app.service('miqDBBackupService', function() {
  this.knownProtocolsList = ["Anonymous FTP", "FTP", "NFS", "Samba"];

  this.logProtocolNotSelected = function(model) {
    return model.log_protocol == '' || model.log_protocol == undefined;
  };

  this.logProtocolSelected = function(model) {
    return model.log_protocol != '' && model.log_protocol != undefined;
  };

  this.logProtocolChanged = function(model) {
    this.resetAll(model);
    if(model.log_protocol == 'Network File System' || model.log_protocol == 'NFS') {
      model.uri_prefix = 'nfs';
    }
    else if(model.log_protocol == 'Samba') {
      model.uri_prefix = 'smb';
    }
    else if(model.log_protocol == 'Anonymous FTP' || model.log_protocol == 'FTP') {
      model.uri_prefix = 'ftp';
    }
  };

  this.sambaBackup = function(model) {
    if(model.log_protocol == 'Samba')
      return true;
    else
      return false;
  };

  this.credsProtocol = function(model) {
    if(model.log_protocol == 'Samba' || model.log_protocol == 'FTP')
      return true;
    else
      return false;
  };

  this.dbRequired = function(model, value) {
    return this.logProtocolSelected(model) &&
           (this.isModelValueNil(value));
  };

  this.sambaRequired = function(model, value) {
    return this.sambaBackup(model) &&
           (this.isModelValueNil(value));
  };

  this.credsRequired = function(model, value) {
    return this.credsProtocol(model) &&
           (this.isModelValueNil(value));
  };

  this.isModelValueNil = function(value) {
    return value == null || value == '';
  };

  this.resetAll = function(model) {
    model.log_userid = null;
    model.log_password = null;
    model.log_verify = null;
    model.uri_prefix = null;
    model.depot_name = null;
    model.uri = null;
  }
});
