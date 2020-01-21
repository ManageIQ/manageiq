class FileDepotFtpAnonymous < FileDepotFtp
  def login_credentials
    ["anonymous", "anonymous"]
  end

  def self.display_name(number = 1)
    n_('Anonymous FTP', 'Anonymous FTPs', number)
  end
end
