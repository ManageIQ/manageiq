require 'manageiq-api-client'

module InterRegionApiMethodRelay
  class InterRegionApiMethodRelayError < RuntimeError; end

  INITIAL_INSTANCE_WAIT = 1.second
  MAX_INSTANCE_WAIT     = 1.minute

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
          InterRegionApiMethodRelay.exec_api_call(region_number, collection_name, action, api_args, id)
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

  def self.api_client_connection_for_region(region_number, user = User.current_userid)
    region = MiqRegion.find_by(:region => region_number)

    url = region.remote_ws_url
    if url.nil?
      _log.error("The remote region [#{region_number}] does not have a web service address.")
      raise "Failed to establish API connection to region #{region_number}"
    end

    ManageIQ::API::Client.new(
      :url      => url,
      :miqtoken => region.api_system_auth_token(user),
      :ssl      => {:verify => false}
    )
  end

  def self.exec_api_call(region, collection_name, action, api_args = nil, id = nil)
    api_args ||= {}
    collection = api_client_connection_for_region(region).public_send(collection_name)
    collection_or_instance = id ? collection.find(id) : collection
    result = collection_or_instance.public_send(action, api_args)
    case result
    when ManageIQ::API::Client::ActionResult
      raise InterRegionApiMethodRelayError, result.message if result.failed?
      result.attributes
    when ManageIQ::API::Client::Resource
      instance_for_resource(result)
    when Hash
      # Some of API invocation returning Hash object
      # Example: retire_resource for Service
      _log.warn("remote API invocation returned Hash object")
      result
    else
      raise InterRegionApiMethodRelayError, "Got unexpected API result object #{result.class}"
    end
  end

  def self.instance_for_resource(resource)
    klass = Api::CollectionConfig.new.klass(resource.collection.name)
    wait = INITIAL_INSTANCE_WAIT

    while wait < MAX_INSTANCE_WAIT
      instance = klass.find_by(:id => resource.id)
      return instance if instance
      sleep(wait)
      wait *= 2
    end

    raise InterRegionApiMethodRelayError, "Failed to retrieve #{klass} instance with id #{resource.id}"
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
