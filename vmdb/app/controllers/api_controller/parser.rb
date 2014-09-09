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
      cidx                 = 2                             # collection starts @ index 2
      if path_split[2]
        ver = path_split[2]
        if ver.match(version_config[:regex])               # v#.# version signature
          @req[:version]   = ver[1..-1]                    # Switching API Version
          @req[:prefix]    = "#{@req[:prefix]}/#{ver}"     # /api/v#.#
          cidx            += 1
        end
      end

      @req[:collection],    @req[:c_id] = path_split[cidx..cidx + 1]
      @req[:subcollection], @req[:s_id] = path_split[cidx + 2..cidx + 3]

      log_api_request
    end

    def log_api_request
      api_log_info("\n#{@name} Request URL: #{@req[:url]}")
      if api_log_debug?
        msg  = "\n#{@name} Request Details"
        @req.each { |k, v| msg << "\n  #{k[0..14].ljust(14, ' ')}: #{v}" if v.present? }
        if params.size > 0
          msg << "\n\n  Parameters:"
          params.each { |k, v| msg << "\n    #{k[0..12].ljust(12, ' ')}: #{v}" }
        end
        api_log_debug(msg)
      end
    end

    def validate_api_request
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
    end

    def validate_api_action
      return unless @req[:collection]
      send("validate_#{@req[:method]}_method")    #ie. validate_patch_method
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

    private

    #
    # For Posts we need to support actions, let's validate those
    #
    def validate_post_method
      cname = @req[:subcollection] || @req[:collection]
      cspec = collection_config[cname.to_sym]
      type, target = request_type_target
      is_method_allowed(target, cspec)
      validate_post_api_action(cname, @req[:method], cspec, type, target)
    end

    #
    # For Delete, Patch and Put, we need to make sure we're entitled for them.
    #
    def validate_patch_method
      validate_method_action(:patch, "edit")
    end

    def validate_put_method
      validate_method_action(:put, "edit")
    end

    def validate_delete_method
      validate_method_action(:delete, "delete")
    end

    def validate_method_action(method_name, action_name)
      cname = @req[:subcollection] || @req[:collection]
      cspec = collection_config[cname.to_sym]
      target = request_type_target.last
      aspec = cspec["#{target}_actions".to_sym]
      if aspec.nil?
        opts = {:attempted_method => @req[:method]}
        raise MethodNotAllowedError.new(opts)
      end

      action_hash, temp = fetch_action_hash(aspec, method_name, action_name)

      if action_hash.nil?
        is_method_allowed(target, cspec)
      end

      unless api_user_role_allows?(action_hash[:identifier])
        raise Forbidden, "Use of the '#{action_name}' action is forbidden"
      end
    end

    def is_method_allowed(target, cspec)
      opts = {
        :msg => "HTTP method '#{@req[:method].upcase}' is not allowed.",
        :allowed_methods => [] 
      }

      aspec = cspec["#{target}_actions".to_sym]
      unless aspec.nil?
        opts[:allowed_methods] = aspec.keys.map { |k| k.to_s.upcase }
      end

      raise MethodNotAllowedError.new(opts)
    end

    def request_type_target
      if @req[:subcollection]
        @req[:s_id] ? [:resource, :subresource] : [:collection, :subcollection]
      else
        @req[:c_id] ? [:resource, :resource] : [:collection, :collection]
      end
    end

    def validate_post_api_action(cname, mname, cspec, type, target)
      # for basic HTTP POST, default action is "create" with data being the POST body
      aname = @req[:action] = json_body["action"] || "create"

      aspecnames = "#{target}_actions"
      raise BadRequestError, "No actions are supported for #{cname} #{type}" unless cspec.key?(aspecnames.to_sym)

      aspec = cspec[aspecnames.to_sym]
      
      # hack around the default 'create' action
      action_hash, @req[:action] = fetch_action_hash(aspec, mname, aname)
      aname = @req[:action]

      raise BadRequestError, "Unsupported Action #{aname} for the #{cname} #{type} specified" if action_hash.blank?
      raise Forbidden, "Use of Action #{aname} is forbidden" unless api_user_role_allows?(action_hash[:identifier])

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

      action_hash, temp = fetch_action_hash(aspec, mname, aname)

      unless api_user_role_allows?(action_hash[:identifier])
        raise Forbidden, "Use of Action #{aname} for the #{cname} sub-collection is forbidden"
      end
    end

    def fetch_action_hash(aspec, method_name, action_name)

      unless method_name.to_s == 'post'
        return Array(aspec[method_name]).detect { |h| h[:name] == action_name }, action_name
      end

      # There should only be one 'action' per 'post' method.
      #
      # This should make it easier to remove the 'action name' from the api.yml
      # config in the future. 
      return aspec[:post][0], aspec[:post][0][:name]
    end
  end
end
