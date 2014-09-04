class VmdbwsClient < EvmWebservicesClient
  def initialize(host_name)
    driver_options = {}
    protocol = nil
    if File.exist?(Rails.root.join("certs/apiclient.crt"))
      driver_options = {
        'protocol.http.ssl_config.verify_mode' => 'OpenSSL::SSL::VERIFY_PEER',
        'protocol.http.ssl_config.client_key'  => Rails.root.join("certs/apiclient.key").to_s,
        'protocol.http.ssl_config.client_cert' => Rails.root.join("certs/apiclient.crt").to_s,
        'protocol.http.ssl_config.ca_file'     => Rails.root.join("certs/root.crt").to_s,
      }
      protocol = "https"
    end
    super(host_name, protocol, VmdbwsSupport::SYSTEM_USER, VmdbwsSupport.system_password, driver_options)
  end
end
