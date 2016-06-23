class ApiController
  module Entrypoint
    #
    # Action Methods
    #

    def show_entrypoint
      res = {
        :name        => @name,
        :description => @description,
        :version     => @version,
        :versions    => entrypoint_versions,
        :settings    => user_settings,
        :identity    => auth_identity
      }
      res[:authorization] = auth_authorization if attribute_selection.include?("authorization")
      res[:collections]   = entrypoint_collections
      render_resource :entrypoint, res
    end

    def entrypoint_versions
      version_config[:definitions].select(&:ident).collect do |version_specification|
        {
          :name => version_specification[:name],
          :href => "#{@req.api_prefix}/#{version_specification[:ident]}"
        }
      end
    end

    def entrypoint_collections
      collection_config.sort.collect do |collection_name, collection_specification|
        if collection_specification[:options].include?(:collection)
          {
            :name        => collection_name,
            :href        => collection_name,
            :description => collection_specification[:description]
          }
        end
      end.compact
    end
  end
end
