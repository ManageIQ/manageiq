class FirmwareRegistry::RestApiDepot < FirmwareRegistry
  def sync_fw_binaries_raw
    remote_binaries.each do |binary_hash|
      binary = FirmwareBinary.find_or_create_by(:firmware_registry => self, :external_ref => binary_hash['id'])
      _log.info("Updating FirmwareBinary [#{binary.id} | #{binary.name}]...")

      binary.name = binary_hash['filename'] || binary_hash['id']
      binary.description = binary_hash['description']
      binary.version = binary_hash['version']
      binary.save!

      unless binary.urls.sort == binary_hash['urls'].sort
        _log.info("Updating FirmwareBinary [#{binary.id} | #{binary.name}] endpoints...")
        endpoints_by_url = binary.endpoints.index_by(&:url)
        urls_to_delete = binary.urls - binary_hash['urls']
        urls_to_delete.each { |url| endpoints_by_url[url].destroy }
        urls_to_create = binary_hash['urls'] - binary.urls
        urls_to_create.each { |url| binary.endpoints.create!(:url => url) }
      end

      currents = binary.firmware_targets.map(&:to_hash)
      remotes = binary_hash['compatible_server_models'].map { |r| r.symbolize_keys.slice(*FirmwareTarget::MATCH_ATTRIBUTES) }
      unless currents.map(&:to_a).sort == remotes.map(&:to_a).sort
        _log.info("Updating FirmwareBinary [#{binary.id} | #{binary.name}] targets...")
        binary.firmware_targets = remotes.map do |remote|
          FirmwareTarget.find_compatible_with(remote, :create => true)
        end
      end

      _log.info("Updating FirmwareBinary [#{binary.id} | #{binary.name}]... completed.")
    end
  end

  def self.do_create_firmware_registry(options)
    transaction do
      create!(:name => options[:name]).tap do |registry|
        registry.authentication = Authentication.create!(
          :userid   => options[:userid],
          :password => ManageIQ::Password.try_decrypt(options[:password])
        )
        registry.endpoint = Endpoint.create!(:url => options[:url])
      end
    end
  end

  def self.validate_options(options)
    %i[name userid password url].each do |opt|
      raise MiqException::Error, "#{opt} is required" if options[opt].blank?
    end
    options
  end

  private

  def remote_binaries
    self.class.fetch_from_remote(
      endpoint.url,
      authentication.userid,
      authentication.password,
      :verify_ssl => endpoint.security_protocol
    )
  end

  def self.fetch_from_remote(url, username, password, verify_ssl: OpenSSL::SSL::VERIFY_PEER)
    uri = URI.parse(url)
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request.basic_auth(username, password)
    response = Net::HTTP.new(uri.host, uri.port).tap do |http|
      http.open_timeout = 5.seconds
      http.use_ssl = url.start_with?('https')
      http.verify_mode = verify_ssl
    end.request(request)

    raise MiqException::Error, "Bad status returned: #{response.code}" if response.code.to_i != 200

    JSON.parse(response.body)
  rescue SocketError => e
    raise MiqException::Error, e
  rescue JSON::ParserError => e
    raise MiqException::Error, e
  end
end
