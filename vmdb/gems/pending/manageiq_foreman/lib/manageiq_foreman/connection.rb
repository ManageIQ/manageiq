module ManageiqForeman
  class Connection
    include ManageiqForeman::Logging
    # some foreman servers don't have locations or organizations, just return nil
    ALLOW_404 = [:locations, :organizations]
    attr_accessor :connection_attrs

    def initialize(attrs)
      self.connection_attrs = attrs.dup
      connection_attrs[:uri] = connection_attrs.delete(:base_url)
      connection_attrs[:api_version] ||= 2
      connection_attrs[:apidoc_cache_dir] ||= tmpdir
      options = {:verify_ssl => connection_attrs.delete(:verify_ssl)}
      @api = ApipieBindings::API.new(connection_attrs, options)
    end

    def verify?
      results = Array(fetch(:home).try(:results)).first
      results.respond_to?(:key?) && results.key?("links")
    end

    def all(resource, filter = {})
      page = 0
      all = []

      loop do
        page_params = {:page => (page += 1), :per_page => 50}.merge(filter)
        small = fetch(resource, :index, page_params)
        return if small.nil? # 404
        all += small.to_a
        break if small.empty? || all.size >= small.total
      end
      PagedResponse.new(all)
    end

    # ala n+1
    def all_with_details(resource, filter = {})
      load_details(all(resource, filter), resource)
    end

    def load_details(resources, resource)
      resources.map! { |os| fetch(resource, :show, "id" => os["id"]).first } if resources
    end

    # filter: "page" => 2, "per_page" => 50, "search" => "field=value", "value"
    def fetch(resource, action = :index, filter = {})
      action, filter = :index, action if action.kind_of?(Hash)
      logger.info("#{self.class.name}##{__method__} Calling Apipie Resource: #{resource.inspect} Action: #{action.inspect} Params: #{dump_hash(filter)}")
      PagedResponse.new(@api.resource(resource).action(action).call(filter))
    rescue RestClient::ResourceNotFound
      raise unless ALLOW_404.include?(resource)
      nil
    end

    def host(manager_ref)
      ::ManageiqForeman::Host.new(self, manager_ref)
    end

    def inventory
      Inventory.new(self)
    end

    # used for tests to manually invoke loading api from server
    # this keeps http calls consistent

    def api_cached?
      File.exist?(@api.apidoc_cache_file)
    end

    def ensure_api_cached
      @api.apidoc
    end

    private

    def tmpdir
      if defined?(Rails)
        Rails.root.join("tmp/foreman").to_s
      else
        require 'tmpdir'
        "#{Dir.tmpdir}/foreman"
      end
    end
  end
end
