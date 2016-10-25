module Api
  class ApiController < Api::BaseController
    def options
      head(:ok)
    end

    def index
      res = {
        :name         => ApiConfig.base.name,
        :description  => ApiConfig.base.description,
        :version      => ApiConfig.base.version,
        :versions     => entrypoint_versions,
        :settings     => user_settings,
        :identity     => auth_identity,
        :server_info  => server_info,
        :product_info => product_info
      }
      res[:authorization] = auth_authorization if attribute_selection.include?("authorization")
      res[:collections]   = entrypoint_collections
      render_resource :entrypoint, res
    end

    private

    def entrypoint_versions
      ApiConfig.version.definitions.select(&:ident).collect do |version_specification|
        {
          :name => version_specification[:name],
          :href => "#{@req.api_prefix}/#{version_specification[:ident]}"
        }
      end
    end

    def entrypoint_collections
      collection_config.collections_with_description.sort.collect do |collection_name, description|
        {
          :name        => collection_name,
          :href        => collection_name,
          :description => description
        }
      end
    end

    def server_info
      {
        :version   => vmdb_build_info(:version),
        :build     => vmdb_build_info(:build),
        :appliance => appliance_name,
      }
    end

    def product_info
      {
        :name                 => I18n.t("product.name"),
        :name_full            => I18n.t("product.name_full"),
        :copyright            => I18n.t("product.copyright"),
        :support_website      => I18n.t("product.support_website"),
        :support_website_text => I18n.t("product.support_website_text"),
      }
    end
  end
end
