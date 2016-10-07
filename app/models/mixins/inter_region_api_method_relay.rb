module InterRegionApiMethodRelay
  def self.extended(klass)
    unless klass.const_defined?("InstanceMethodRelay")
      instance_relay = klass.const_set("InstanceMethodRelay", Module.new)
      klass.prepend(instance_relay)
    end

    unless klass.const_defined?("ClassMethodRelay")
      class_relay = klass.const_set("ClassMethodRelay", Module.new)
      klass.singleton_class.prepend(class_relay)
    end
  end

  def api_relay_method(method, action = method)
    relay = const_get("InstanceMethodRelay")
    collection_name = collection_for_class

    relay.class_eval do
      define_method(method) do |*meth_args, &meth_block|
        api_args = block_given? ? yield(*meth_args) : {}

        if in_current_region?
          super(*meth_args, &meth_block)
        else
          api_client = InterRegionApiMethodRelay.api_client_connection_for_region(region_number)
          collection = api_client.public_send(collection_name)
          obj = collection.find(id)
          obj.public_send(action, api_args)
        end
      end
    end
  end

  def api_relay_class_method(method, action = method)
    relay = const_get("ClassMethodRelay")
    collection_name = collection_for_class
    raise ArgumentError, "A block is required to determine target object region and API arguments" unless block_given?

    relay.class_eval do
      define_method(method) do |*meth_args, &meth_block|
        record_id, api_args = yield(*meth_args)

        if id_in_current_region?(record_id)
          super(*meth_args, &meth_block)
        else
          api_client = InterRegionApiMethodRelay.api_client_connection_for_region(id_to_region(record_id))
          collection = api_client.public_send(collection_name)
          collection.public_send(action, api_args || {})
        end
      end
    end
  end

  def self.api_client_connection_for_region(region)
    hostname = MiqRegion.find_by_region(region).remote_ws_address
    if hostname.nil?
      _log.error("The remote region [#{region}] does not have a web service address.")
      raise "Failed to establish API connection to region #{region}"
    end

    require 'manageiq-api-client'

    ManageIQ::API::Client.new(
      :url      => "https://#{hostname}",
      :miqtoken => MiqRegion.api_system_auth_token_for_region(region, User.current_userid),
      :ssl      => {:verify => false}
    )
  end

  private

  def collection_for_class
    collection_name = Api::CollectionConfig.new.name_for_klass(self)
    unless collection_name
      _log.error("No API endpoint found for class #{name}")
      raise NotImplementedError, "No API endpoint found for class #{name}"
    end
    collection_name
  end
end
