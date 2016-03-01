class FileDepotFtpAnonymous < FileDepotFtp
  def login_credentials
    ["anonymous", "anonymous"]
  end
end
