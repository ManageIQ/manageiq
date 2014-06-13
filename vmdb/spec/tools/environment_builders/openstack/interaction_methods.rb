module InteractionMethods
  def connect(service = "Compute")
    auth_url = EmsOpenstack.auth_url(settings[:connection][:ems_ip], settings[:connection][:ems_port])
    EmsOpenstack.raw_connect(
      settings[:connection][:ems_username],
      settings[:connection][:ems_password],
      auth_url,
      service
    )
  end

  def find_all(collection, lookup_pairs)
    puts "Finding #{lookup_pairs} in #{collection.class.name}"
    collection.select do |i|
      lookup_pairs.all? do |k, v|
        if i.kind_of?(Hash)
          i[k.to_s] == v
        else
          if v.kind_of?(Hash)
            h = i.send(k)
            v.each { |key, value| h[key] == value }
          else
            i.send(k) == v
          end
        end
      end
    end
  end

  def fog
    @fog ||= connect
  end

  def fog_volume
    @fog_volume ||= connect("Volume")
  end

  def find(collection, lookup_pairs)
    find_all(collection, lookup_pairs).first
  end

  def create(collection, attributes, method = :create)
    puts "Creating #{attributes} against #{collection.class.name}"
    case attributes
    when Hash   then collection.send(method, attributes)
    when Array  then collection.send(method, *attributes)
    end
  end

  def find_or_create(collection, attributes)
    obj = find(collection, attributes.slice(:name))
    obj || begin
      new_obj = create(collection, attributes)
      yield new_obj if block_given?
      new_obj
    end
  end

  def find_or_create_server(collection, attributes)
    find_or_create(collection, attributes) do |server|
      wait_for_server_to_start(server)
    end
  end

  def volume_types(volume_service)
    # volume types are not available via the Fog API directly
    volume_service.request(:expects => 200, :method => "GET", :path => "types").body["volume_types"]
  end

  private

  def wait_for_server_to_start(server)
    print "Waiting for server to start..."

    loop do
      case server.reload.state
      when "ACTIVE"
        break
      when "ERROR"
        puts "Error creating server"
        exit 1
      else
        print "."
        sleep 1
      end
    end
    puts
  end
end
