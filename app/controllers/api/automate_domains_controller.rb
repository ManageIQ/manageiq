module Api
  class AutomateDomainsController < BaseController
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

    def resource_search(id, type, klass)
      if cid?(id)
        super
      else
        begin
          domain = collection_class(:automate_domains).find_by!(:name => id)
        rescue
          raise NotFoundError, "Couldn't find #{klass} with 'name'=#{id}"
        end
        super(domain.id, type, klass)
      end
    end

    def current_tenant
      @auth_user_obj.current_tenant || Tenant.default_tenant
    end
  end
end
