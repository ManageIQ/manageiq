# Assumes this in run in a :with_ftp_server context so an FTP server on
# localhost is available.
#
# See spec/support/with_ftp_server.rb for more info.
RSpec::Matchers.define :have_size_on_ftp_server_of do |expected|
  match do |filepath|
    size = size_on_ftp(filepath)
    size == expected
  end

  def with_connection
    Net::FTP.open("localhost") do |ftp|
      ftp.login("ftpuser", "ftppass")
      yield ftp
    end
  end

  # Do searches with Net::FTP instead of normal directory scan (even though we
  # could) just so we are exercising the FTP interface as expected.
  def size_on_ftp(file_or_dir)
    path = file_or_dir.try(:path) || URI.split(file_or_dir.to_s)[5]
    with_connection do |ftp|
      begin
        ftp.size(path)
      rescue Net::FTPPermError
        0
      end
    end
  end
end
