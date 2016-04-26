require 'openstack/openstack_handle/pagination/marker'
require 'openstack/openstack_handle/pagination/page_number'
require 'openstack/openstack_handle/pagination/none'

require 'openstack/openstack_handle/multi_tenancy/loop'

module OpenstackHandle
  module HandledList
    def handled_list(collection_type, options = {})
      # Will automatically handle multi-tenancy and pagination of all Fog list methods, so we always get all openstack
      # entities back. The exceptions of each service and collection type will be solved in <service_name>)_delegate
      # classes by defining multi_tenancy_type and pagination_type methods base on collection_type
      # Example of call in refresh code
      # @compute_service.handled_list(:servers)
      # @orchestration_service.handled_list(:resources, :stack => stack)
      # By default, it calls :all method on the Fog collection, that has unified interface in all list methods in Fog
      # and always returns detailed list.
      multi_tenancy_class.new(self, @os_handle, self.class::SERVICE_NAME, collection_type, options,
                              :all).list
    rescue Excon::Errors::Forbidden => err
      # It can happen user doesn't have rights to read some tenant, in that case log warning but continue refresh
      _log.warn "Forbidden to read the project: #{@os_handle.project_name}, for collection type: #{collection_type}, "\
                "in provider: #{@os_handle.address}. Message=#{err.message}"
      _log.warn err.backtrace.join("\n")
      []
    rescue Excon::Errors::NotFound => err
      # It can happen that some data do not exist anymore, in that case log warning but continue refresh
      _log.warn "Data not found in project: #{@os_handle.project_name}, for collection type: #{collection_type}, "\
                "in provider: #{@os_handle.address}. Message=#{err.message}"
      _log.warn err.backtrace.join("\n")
      []
    rescue => err
      # Show any list related exception in a nice format.
      openstack_service_name = Handle::SERVICE_NAME_MAP[self.class::SERVICE_NAME]

      _log.error "Unable to obtain collection: '#{collection_type}' in service: '#{openstack_service_name}' "\
                 "using project scope: '#{@os_handle.project_name}' in provider: '#{@os_handle.address}'. "\
                 "Message=#{err.message}"
      _log.error err.backtrace.join("\n")

      raise MiqException::MiqOpenstackApiRequestError,
            "Unable to obtain a collection: '#{collection_type}' in a service: '#{openstack_service_name}' through "\
            " API. Please, fix your OpenStack installation and run refresh again."
    end

    def pagination_handle(collection_type, options = {}, method = :all)
      pagination_class.new(self, @os_handle, collection_type, options, method)
    end

    ###################################################################################################################
    # Override below methods to get special behaviour per service and collection. Unfortunately OpenStack does't handle
    # pagination and multitenancy the same for all services, nor for all API calls obtaining collections under one
    # service

    def default_pagination_limit
      1000
    end

    def more_pages?(_objects_on_page)
      # Different per OpenStack service, objects_on_page.response can contain metadata marking if there is a next page.
      # Already supported by some of the Fog::Collection
      true
    end

    def pagination_class
      # Using method, so we can e.g set pagination type per method name, e.g. when some collection doesn't support
      # pagination, like Heat resources, but others do
      # Allowed values OpenstackHandle::Pagination::Marker, OpenstackHandle::Pagination::PageNumber,
      # OpenstackHandle::Pagination::None
      OpenstackHandle::Pagination::Marker
    end

    def multi_tenancy_class
      # Using method, so we can e.g set multi_tenancy_type type per method name, e.g. when attribute all_tenants is
      # broken on some collections, so it's better to rather sent API request per tenant
      # Allowed values  OpenstackHandle::MultiTenancy::Loop,  OpenstackHandle::MultiTenancy::Option,
      # OpenstackHandle::MultiTenancy::None
      OpenstackHandle::MultiTenancy::Loop
    end
  end
end
