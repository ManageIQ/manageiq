class ApiController
  module Parser
    def parse_api_request
      @req = {}
      @req[:method]        = request.request_method.downcase.to_sym     # :get, :patch, ...
      @req[:fullpath]      = request.original_fullpath     # /api/...&param=value...
      @req[:url]           = request.original_url          # http://target/api/...
      @req[:base]          = @req[:url].partition(@req[:fullpath])[0]   # http://target
      @req[:path]          = URI.parse(@req[:url]).path.sub(/\/*$/, '') # /api/...

      path_split = @req[:path].split('/')
      @req[:prefix]        = "/#{path_split[1]}"           # /api
      @req[:version]       = @version                      # Default API Version
      if params[:version]
        ver = params[:version]
        if ver.match(version_config[:regex])               # v#.# version signature
          @req[:version]   = ver[1..-1]                    # Switching API Version
          @req[:prefix]    = "#{@req[:prefix]}/#{ver}"     # /api/v#.#
        end
      end
      @req[:api_prefix]    = "#{@req[:base]}#{@req[:prefix]}"

      @req[:collection]    = params[:collection]
      @req[:c_id]          = params[:c_id]
      @req[:subcollection] = params[:subcollection]
      @req[:s_id]          = params[:s_id]
    end

    def validate_api_request
      validate_optional_collection_classes

      # API Version Validation
      if @req[:version]
        vname = @req[:version]
        unless version_config[:definitions].collect { |vent| vent[:name] }.include?(vname)
          raise BadRequestError, "Unsupported API Version #{vname} specified"
        end
      end

      cname, ctype = validate_api_request_collection
      cname, ctype = validate_api_request_subcollection(cname, ctype)

      # Method Validation for the collection or sub-collection specified
      if cname && ctype
        mname = @req[:method]
        cent  = collection_config[cname.to_sym]  # For Sub-Collection
        unless Array(cent[:methods]).include?(mname)
          raise BadRequestError, "Unsupported HTTP Method #{mname} for the #{ctype} #{cname} specified"
        end
      end

      validate_api_parameters
    end

    def validate_optional_collection_classes
      @collection_klasses = {}  # Default all to config classes
      param = params['provider_class']
      return unless param.present?

      raise BadRequestError, "Unsupported provider_class #{param} specified" if param != "provider"
      %w(tags policies policy_profiles).each do |cname|
        if @req[:subcollection] == cname || expand?(cname)
          raise BadRequestError, "Management of #{cname} is unsupported for the Provider class"
        end
      end
      @collection_klasses[:providers] = "Provider"
    end

    def validate_api_action
      return unless @req[:collection]
      send("validate_#{@req[:method]}_method")
    end

    def validate_api_parameters
      return unless params['sqlfilter']

      raise BadRequestError, "The sqlfilter parameter is no longer supported, please use the filter parameter instead"
    end

    #
    # Given an HREF, return the related collection,id pair
    # or subcollection,id pair if it represents a subcollection.
    #   [http://.../api[/v#.#]]/<collection>/<c_id>
    #   [http://.../api[/v#.#]]/collection/c_id/<subcollection>/<s_id>
    #
    #   [/api/v#.#]/<collection>/<c_id>
    #   [/api/v#.#]/collection/c_id/<subcollection>/<s_id>
    #
    #   <collection>/<c_id>
    #   collection/c_id/<subcollection>/<s_id>
    #
    def parse_href(href)
      if href
        path = href.match(/^http/) ? URI.parse(href).path.sub(/\/*$/, '') : href
        path = "#{@prefix}/#{path}" unless path.match(@prefix)
        path = path.sub(/\/*$/, '')
        return href_collection_id(path)
      end
      [nil, nil]
    end

    def href_collection_id(path)
      path_array = path.split('/')
      cidx = path_array[2] && path_array[2].match(version_config[:regex]) ? 3 : 2

      collection, c_id    = path_array[cidx..cidx + 1]
      subcollection, s_id = path_array[cidx + 2..cidx + 3]

      subcollection ? [subcollection.to_sym, s_id] : [collection.to_sym, c_id]
    end

    def parse_id(resource, collection)
      return nil if resource.blank?

      href = resource["href"]
      return href.match(%r{^.*/#{collection}/([0-9]+)$}) && Regexp.last_match(1) if href.present?

      resource["id"].kind_of?(Integer) ? resource["id"] : nil
    end

    def resource_can_have_custom_actions(type, cspec = nil)
      cspec ||= collection_config[type.to_sym] if collection_config.key?(type.to_sym)
      cspec && cspec[:options].include?(:custom_actions)
    end

    def parse_by_attr(resource, type, attr_list)
      klass = collection_class(type)
      objs = attr_list.map { |attr| klass.send("find_by_#{attr}", resource[attr]) if resource[attr] }.compact
      objs.collect(&:id).first
    end

    def parse_owner(resource)
      return nil if resource.blank?
      owner_id = parse_id(resource, :users)
      owner_id ? owner_id : parse_by_attr(resource, :users, %w(name userid))
    end

    def parse_group(resource)
      return nil if resource.blank?
      group_id = parse_id(resource, :groups)
      group_id ? group_id : parse_by_attr(resource, :groups, %w(description))
    end

    def parse_role(resource)
      return nil if resource.blank?
      role_id = parse_id(resource, :roles)
      role_id ? role_id : parse_by_attr(resource, :roles, %w(name))
    end

    def parse_tenant(resource)
      parse_id(resource, :tenants) unless resource.blank?
    end

    def parse_ownership(data)
      {
        :owner => collection_class(:users).find_by_id(parse_owner(data["owner"])),
        :group => collection_class(:groups).find_by_id(parse_group(data["group"]))
      }.compact if data.present?
    end

    # RBAC Aware type specific resource fetches

    def parse_fetch_group(data)
      if data
        group_id = parse_group(data)
        raise BadRequestError, "Missing Group identifier href, id or description" if group_id.nil?
        resource_search(group_id, :groups, collection_class(:groups))
      end
    end

    def parse_fetch_role(data)
      if data
        role_id = parse_role(data)
        raise BadRequestError, "Missing Role identifier href, id or name" if role_id.nil?
        resource_search(role_id, :roles, collection_class(:roles))
      end
    end

    def parse_fetch_tenant(data)
      if data
        tenant_id = parse_tenant(data)
        raise BadRequestError, "Missing Tenant identifier href or id" if tenant_id.nil?
        resource_search(tenant_id, :tenants, collection_class(:tenants))
      end
    end

    private

    #
    # For Posts we need to support actions, let's validate those
    #
    def validate_post_method
      cname = @req[:subcollection] || @req[:collection]
      cspec = collection_config[cname.to_sym]
      type, target = request_type_target
      validate_post_api_action(cname, @req[:method], cspec, type, target)
    end

    #
    # For Get, Delete, Patch and Put, we need to make sure we're entitled for them.
    #
    def validate_get_method
      validate_method_action(:get, "read")
    end

    def validate_patch_method
      validate_method_action(:post, "edit")
    end

    def validate_put_method
      validate_method_action(:post, "edit")
    end

    def validate_delete_method
      validate_method_action(:delete, "delete")
    end

    def validate_method_action(method_name, action_name)
      cname = @req[:subcollection] || @req[:collection]
      cspec = collection_config[cname.to_sym]
      target = request_type_target.last
      aspec = cspec["#{target}_actions".to_sym]
      return if method_name == :get && aspec.nil?
      action_hash = fetch_action_hash(aspec, method_name, action_name)
      raise BadRequestError, "Disabled action #{action_name}" if action_hash[:disabled]
      unless api_user_role_allows?(action_hash[:identifier])
        raise Forbidden, "Use of the #{action_name} action is forbidden"
      end
    end

    def request_type_target
      if @req[:subcollection]
        @req[:s_id] ? [:resource, :subresource] : [:collection, :subcollection]
      else
        @req[:c_id] ? [:resource, :resource] : [:collection, :collection]
      end
    end

    def parse_action_name
      # for basic HTTP POST, default action is "create" with data being the POST body
      @req[:action] = @req[:method] == :put ? "edit" : (json_body["action"] || "create")
    end

    def validate_post_api_action(cname, mname, cspec, type, target)
      aname = parse_action_name

      aspecnames = "#{target}_actions"
      raise BadRequestError, "No actions are supported for #{cname} #{type}" unless cspec.key?(aspecnames.to_sym)

      aspec = cspec[aspecnames.to_sym]
      action_hash = fetch_action_hash(aspec, mname, aname)
      if action_hash.blank?
        unless type == :resource && resource_can_have_custom_actions(cname, cspec)
          raise BadRequestError, "Unsupported Action #{aname} for the #{cname} #{type} specified"
        end
      end

      if action_hash.present?
        raise BadRequestError, "Disabled Action #{aname} for the #{cname} #{type} specified" if action_hash[:disabled]
        raise Forbidden, "Use of Action #{aname} is forbidden" unless api_user_role_allows?(action_hash[:identifier])
      end

      validate_post_api_action_as_subcollection(cname, mname, aname)
    end

    def validate_api_request_collection
      # Collection Validation
      if @req[:collection]
        cname = @req[:collection]
        ctype = "Collection"
        raise BadRequestError, "Unsupported #{ctype} #{cname} specified" unless collection_config.key?(cname.to_sym)
        cspec = collection_config[cname.to_sym]
        if cspec[:options].include?(:primary)
          if "#{@req[:c_id]}#{@req[:subcollection]}#{@req[:s_id]}".present?
            raise BadRequestError, "Invalid request for #{ctype} #{cname} specified"
          end
        else
          raise BadRequestError, "Unsupported #{ctype} #{cname} specified" unless cspec[:options].include?(:collection)
        end
        [cname, ctype]
      end
    end

    def validate_api_request_subcollection(cname, ctype)
      # Sub-Collection Validation for the specified Collection
      if cname && @req[:subcollection]
        cent  = collection_config[cname.to_sym]  # For Collection
        cname = @req[:subcollection]
        ctype = "Sub-Collection"
        unless Array(cent[:subcollections]).include?(cname.to_sym)
          raise BadRequestError, "Unsupported #{ctype} #{cname} specified"
        end
      end
      [cname, ctype]
    end

    def validate_post_api_action_as_subcollection(cname, mname, aname)
      return if cname == @req[:collection]

      cspec = collection_config[@req[:collection].to_sym]
      return if cspec[:subcollections] && !cspec[:subcollections].include?(cname.to_sym)

      aspec = cspec["#{cname}_subcollection_actions".to_sym]
      return unless aspec

      action_hash = fetch_action_hash(aspec, mname, aname)
      raise BadRequestError, "Unsupported Action #{aname} for the #{cname} sub-collection" if action_hash.blank?
      raise BadRequestError, "Disabled Action #{aname} for the #{cname} sub-collection" if action_hash[:disabled]
      unless api_user_role_allows?(action_hash[:identifier])
        raise Forbidden, "Use of Action #{aname} for the #{cname} sub-collection is forbidden"
      end
    end

    def fetch_action_hash(aspec, method_name, action_name)
      Array(aspec[method_name]).detect { |h| h[:name] == action_name } || {}
    end
  end
end
