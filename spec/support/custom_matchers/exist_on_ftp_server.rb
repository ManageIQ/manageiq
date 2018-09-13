# Assumes this in run in a :with_ftp_server context so an FTP server on
# localhost is available.
#
# See spec/support/with_ftp_server.rb for more info.
RSpec::Matchers.define :exist_on_ftp_server do
  match do |actual|
    !list_in_ftp(actual).empty?
  end

  failure_message do |actual|
    fail_msg(actual)
  end

  failure_message_when_negated do |actual|
    fail_msg(actual, :negated => true)
  end

  def with_connection
    Net::FTP.open("localhost") do |ftp|
      ftp.login("ftpuser", "ftppass")
      yield ftp
    end
  end

  # Do searches with Net::FTP instead of normal directory scan (even though we
  # could) just so we are exercising the FTP interface as expected.
  def list_in_ftp(file_or_dir)
    with_connection do |ftp|
      begin
        ftp.nlst(to_path_string(file_or_dir))
      rescue Net::FTPPermError
        []
      end
    end
  end

  def fail_msg(actual, negated: false)
    dir     = File.dirname(actual)
    entries = list_in_ftp(dir)
    exist   = negated ? "not exist" : "exist"
    <<~MSG
      expected: #{to_path_string(actual)} to #{exist} in ftp directory"

      Entries for #{dir}:
      #{entries.empty? ? "  []" : entries.map { |e| "  #{e}" }.join("\n")}
    MSG
  end

  def to_path_string(path)
    path.try(:path) || URI.split(path.to_s)[5]
  end
end
