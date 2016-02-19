class FileDepotFtpAnonymous < FileDepotFtp
  def self.requires_credentials?
    true
  end

  def requires_support_case?
    false
  end

  def login_credentials
    ["anonymous", "anonymous"]
  end
end
