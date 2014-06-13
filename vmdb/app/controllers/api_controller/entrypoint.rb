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
        :collections => entrypoint_collections
      }
      render_resource :entrypoint, res
    end

    def entrypoint_versions
      version_config[:definitions].collect do |version_specification|
        if version_specification.key?(:ident)
          {
            :name => version_specification[:name],
            :href => "#{@req[:base]}#{@prefix}/#{version_specification[:ident]}"
          }
        end
      end.compact
    end

    def entrypoint_collections
      collection_config.each.collect do |collection_name, collection_specification|
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
