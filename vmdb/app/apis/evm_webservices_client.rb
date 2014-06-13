require 'actionwebservice'

class EvmWebservicesClient < ActionWebService::Client::Soap
  def self.api
    @api ||= "#{self.name[0..-7]}Api".constantize
  end

  def self.endpoint_name
    @endpoint_name ||= self.name[0..-7].underscore
  end

  def self.endpoint_url(host_name, protocol = "https")
    "#{protocol}://#{host_name}/#{self.endpoint_name}/api"
  end

  def initialize(host_name, protocol = "https", options = {})
    driver_options = {
      'protocol.http.ssl_config.verify_mode'     => 'OpenSSL::SSL::VERIFY_NONE',
      'protocol.http.ssl_config.verify_callback' => method(:verify_callback).to_proc,
    }.merge(options)

    super(self.class.api, self.class.endpoint_url(host_name, protocol), :driver_options => driver_options)

    enable_wiredump if $DEBUG
  end

  # Default callback for SSL verification: only dumps error.
  def verify_callback(is_ok, ctx)
    if $DEBUG
      puts "#{is_ok ? 'ok' : 'ng'}: #{ctx.current_cert.subject}"
      STDERR.puts "at depth #{ctx.error_depth} - #{ctx.error}: #{ctx.error_string}" unless is_ok
    end
    is_ok
  end

  def enable_wiredump
    @wd_file = File.new("wire_dump_#{self.class.endpoint_name}.out", "w")
    @wd_file.sync = true
    self.driver.wiredump_dev = @wd_file
  end

  def add_http_basic_auth(user, pass, host_name, protocol = "https")
    self.driver.options['protocol.http.basic_auth'] << [self.class.endpoint_url(host_name, protocol), user, pass]
  end
end
