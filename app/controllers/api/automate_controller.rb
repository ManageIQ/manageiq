module Api
  class AutomateController < BaseController
    def show
      ae_browser = MiqAeBrowser.new(@auth_user_obj)
      begin
        resources = ae_browser.search(search_start(@req.c_suffix), ae_search_options)
      rescue => err
        raise BadRequestError, err.to_s
      end
      automate_klass = collection_class(:automate).name
      attributes = params['attributes'] ? %w(fqname) | params['attributes'].to_s.split(',') : nil
      resources = resources.collect do |resource|
        post_process_resource(:automate, automate_klass, resource, attributes)
      end
      render_resource :automate, :name => "automate", :subcount => resources.count, :resources => resources
    end

    def refresh_from_source_resource(type, id = nil, data = nil)
      raise BadRequestError, "Must specify an id for refreshing a #{type} resource from source" unless id

      api_action(type, id) do |klass|
        domain = resource_search(id, type, klass)
        api_log_info("Refreshing #{automate_domain_ident(domain)}")

        begin
          unless GitBasedDomainImportService.available?
            raise "Git owner role is not enabled to be able to import git repositories"
          end
          raise "#{automate_domain_ident(domain)} did not originate from git repository" unless domain.git_repository
          ref = data["ref"] || domain.ref
          ref_type = data["ref_type"] || domain.ref_type

          description = "Refreshing #{automate_domain_ident(domain)} from git repository"
          task_id = GitBasedDomainImportService.new.queue_refresh_and_import(domain.git_repository.url,
                                                                             ref,
                                                                             ref_type,
                                                                             current_tenant.id)
          action_result(true, description, :task_id => task_id)
        rescue => err
          action_result(false, err.to_s)
        end
      end
    end

    private

    def automate_domain_ident(domain)
      "Automate Domain id:#{domain.id} name:'#{domain.name}'"
    end

    def search_start(c_suffix)
      start = c_suffix
      start = resource_search(start, :automate, collection_class(:automate)).name if cid?(start)
      start
    end

    def resource_search(id, type, klass)
      if cid?(id)
        super
      else
        begin
          domain = MiqAeBrowser.new(@auth_user_obj).search(id, :depth => 0).first
        rescue => err
          raise NotFoundError, err.to_s
        end
        super(domain.id, type, klass)
      end
    end

    def ae_search_options
      # For /api/automate (discovering domains, scope is 1 if unspecified)
      # Otherwise, we default depth to 0 (current object), use -1 for unlimited depth search
      depth = if params[:depth]
                params[:depth] == "-1" ? nil : params[:depth].to_i
              else
                @req.c_suffix.blank? ? 1 : 0
              end
      search_options = {:depth => depth, :serialize => true}
      search_options[:state_machines] = true if search_option?(:state_machines)
      search_options
    end

    def post_process_resource(type, automate_klass, resource, attributes)
      resource_klass = resource["klass"]
      resource = resource.slice(*attributes) if attributes.present?
      if attributes.blank? || attributes.include?("actions")
        if resource_klass == automate_klass
          href = "#{@req.api_prefix}/#{type}/#{resource['id']}"
          aspecs = gen_action_spec_for_resources(collection_config[type], false, href, resource)
          resource["actions"] = aspecs
        end
      end
      resource
    end

    def current_tenant
      @auth_user_obj.current_tenant || Tenant.default_tenant
    end
  end
end
