miqAngularApplication.service('miqDBBackupService', function() {

  this.logProtocolNotSelected = function(model) {
    if(model.log_protocol == '')
      return true;
    else
      return false;
    };

  this.logProtocolSelected = function(model) {
    if(model.log_protocol != '')
      return true;
    else
      return false;
  };

  this.logProtocolChanged = function(model, scope) {
    if(model.log_protocol == 'Network File System' || model.log_protocol == 'NFS') {
      this.resetAll(model);
      model.uri_prefix = 'nfs';
    }
    else if(model.log_protocol == 'Samba') {
      this.resetAll(model);
      model.uri_prefix = 'smb';
    }
    else if(model.log_protocol == 'Anonymous FTP') {
      this.resetAll(model);
      model.uri_prefix = 'ftp';
    }
    else if (model.log_protocol == 'FTP') {
      this.resetAll(model);
      model.uri_prefix = 'ftp';
    }
    else if (model.log_protocol == 'Red Hat Dropbox') {
      this.resetAll(model);
      model.uri_prefix = 'ftp';
      model.depot_name = model.rh_dropbox_depot_name;
      model.uri = model.rh_dropbox_uri;
    }
    else {
      this.resetAll(model);
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
