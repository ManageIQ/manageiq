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
        api_args = yield(*meth_args) if block_given?

        if in_current_region?
          super(*meth_args, &meth_block)
        else
          InterRegionApiMethodRelay.exec_api_call(region_number, collection_name, action, api_args) do
            [{:id => id}]
          end
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

        if record_id.nil? || id_in_current_region?(record_id)
          super(*meth_args, &meth_block)
        else
          InterRegionApiMethodRelay.exec_api_call(id_to_region(record_id), collection_name, action, api_args)
        end
      end
    end
  end

  def self.api_client_connection_for_region(region_number)
    region = MiqRegion.find_by(:region => region_number)

    unless region.auth_key_configured?
      _log.error("Region #{region_number} is not configured for central administration")
      raise "Region #{region_number} is not configured for central administration"
    end

    url = region.remote_ws_url
    if url.nil?
      _log.error("The remote region [#{region_number}] does not have a web service address.")
      raise "Failed to establish API connection to region #{region_number}"
    end

    require 'manageiq-api-client'

    ManageIQ::API::Client.new(
      :url      => url,
      :miqtoken => region.api_system_auth_token(User.current_userid),
      :ssl      => {:verify => false}
    )
  end

  def self.exec_api_call(region, collection_name, action, api_args = nil, &resource_block)
    api_args ||= {}
    collection = api_client_connection_for_region(region).public_send(collection_name)
    if resource_block
      collection.public_send(action, api_args, &resource_block)
    else
      collection.public_send(action, api_args)
    end
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
