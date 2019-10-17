class FileDepotSupport < FileDepot

  def self.uri_prefix
    "support"
  end

  def self.validate_settings(settings)
    verify_credentials(nil, settings.slice(:username, :password))
  end

  def requires_support_case?
    true
  end

  def upload_file(file)
    super
    with_connection do
      begin
        upload(file.local_file, support_case)
      rescue => err
        msg = "Error '#{err.message.chomp}', uploading to Support site, Username: [#{authentication_userid}]"
        _log.error(msg)
        raise _("Error '%{message}', uploading to Support site, Username: [%{id}]") % {:message => err.message.chomp,
                                                                                      :uri     => uri,
                                                                                      :id      => authentication_userid}
      else
        file.update_attributes(
          :state   => "available",
        )
        file.post_upload_tasks
      end
    end
  end

  def verify_credentials(_auth_type = nil, cred_hash = nil)
    res = with_connection(cred_hash, &:last_response)
    raise _("Depot Settings validation failed") unless res
    res
  end

  def with_connection(cred_hash = nil)
    raise _("no block given") unless block_given?
    _log.info("Connecting through #{self.class.name}: [#{name}]")
    begin
      connection = connect(cred_hash)
      yield connection
    ensure
    end
  end

  def connect(cred_hash = nil)
    begin
      _log.info("Connecting to #{self.class.name}: #{name}")
      creds = cred_hash ? [cred_hash[:username], cred_hash[:password]] : login_credentials
      _log.info("Connected to #{self.class.name}: #{name}")
    rescue SocketError => err
      _log.error("Failed to connect.  #{err.message}")
      raise
    rescue Net::FTPPermError => err
      _log.error("Failed to login.  #{err.message}")
      raise
    else
    end
  end

  def self.display_name(number = 1)
    n_('Support')
  end

  private

  def create_directory_structure(directory_path)
  end

  def upload(source, support_case)
  end

  def login_credentials
    [authentication_userid, authentication_password]
  end
end
