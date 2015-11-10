describe('miqDBBackupService', function() {
  var testService;

  beforeEach(module('ManageIQ.angularApplication'));

  beforeEach(inject(function(miqDBBackupService) {
    testService = miqDBBackupService;
  }));

  describe('#logProtocolChanged', function() {
    it('it sets the model values for nfs when log protocol selected is NFS', function() {
      logCollectionModel = {
        depot_name:   'mysmbdepot',
        uri:          'smburi',
        uri_prefix:   'smb',
        log_userid:   'aa',
        log_password: 'bb',
        log_verify:   'bb',
        log_protocol: 'NFS'
      };
      testService.logProtocolChanged(logCollectionModel);
      expect(logCollectionModel.uri_prefix).toEqual('nfs');
      expect(logCollectionModel.log_userid).toBeNull();
      expect(logCollectionModel.log_password).toBeNull();
      expect(logCollectionModel.log_verify).toBeNull();
      expect(logCollectionModel.depot_name).toBeNull();
      expect(logCollectionModel.uri).toBeNull();
    });

    it('it sets the model values for Anonymous FTP when log protocol selected is Anonymous FTP', function() {
      logCollectionModel = {
        depot_name:   'mysmbdepot',
        uri:          'smburi',
        uri_prefix:   'smb',
        log_userid:   'aa',
        log_password: 'bb',
        log_verify:   'bb',
        log_protocol: 'Anonymous FTP'
      };
      testService.logProtocolChanged(logCollectionModel);
      expect(logCollectionModel.uri_prefix).toEqual('ftp');
      expect(logCollectionModel.log_userid).toBeNull();
      expect(logCollectionModel.log_password).toBeNull();
      expect(logCollectionModel.log_verify).toBeNull();
      expect(logCollectionModel.depot_name).toBeNull();
      expect(logCollectionModel.uri).toBeNull();
    });

    it('it sets the model values for No Depot when log protocol selected is No Depot', function() {
      logCollectionModel = {
        depot_name:   'mysmbdepot',
        uri:          'smburi',
        uri_prefix:   'smb',
        log_userid:   'aa',
        log_password: 'bb',
        log_verify:   'bb',
        log_protocol: ''
      };
      testService.logProtocolChanged(logCollectionModel);
      expect(logCollectionModel.uri_prefix).toBeNull();
      expect(logCollectionModel.log_userid).toBeNull();
      expect(logCollectionModel.log_password).toBeNull();
      expect(logCollectionModel.log_verify).toBeNull();
      expect(logCollectionModel.depot_name).toBeNull();
      expect(logCollectionModel.uri).toBeNull();
    });
  });
});
