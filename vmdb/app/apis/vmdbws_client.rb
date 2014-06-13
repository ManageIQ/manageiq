class VmdbwsClient < EvmWebservicesClient
  def initialize(host_name)
    super(
      host_name,
      'protocol.http.ssl_config.verify_mode' => 'OpenSSL::SSL::VERIFY_PEER',
      'protocol.http.ssl_config.client_key'  => Rails.root.join("certs/apiclient.key").to_s,
      'protocol.http.ssl_config.client_cert' => Rails.root.join("certs/apiclient.crt").to_s,
      'protocol.http.ssl_config.ca_file'     => Rails.root.join("certs/root.crt").to_s,
    )
  end
end
