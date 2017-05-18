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

    def auth_identity
      user  = User.current_user
      group = user.current_group
      {
        :userid     => user.userid,
        :name       => user.name,
        :user_href  => "#{@req.api_prefix}/users/#{user.id}",
        :group      => group.description,
        :group_href => "#{@req.api_prefix}/groups/#{group.id}",
        :role       => group.miq_user_role_name,
        :role_href  => "#{@req.api_prefix}/roles/#{group.miq_user_role.id}",
        :tenant     => group.tenant.name,
        :groups     => user.miq_groups.pluck(:description),
      }
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
        :version     => Vmdb::Appliance.VERSION,
        :build       => Vmdb::Appliance.BUILD,
        :appliance   => MiqServer.my_server.name,
        :server_href => "#{@req.api_prefix}/servers/#{MiqServer.my_server.id}",
        :zone_href   => "#{@req.api_prefix}/zones/#{MiqServer.my_server.zone.id}",
        :region_href => "#{@req.api_prefix}/regions/#{MiqRegion.my_region.id}"
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

    def auth_authorization
      user  = User.current_user
      group = user.current_group
      {
        :product_features => product_features(group.miq_user_role)
      }
    end

    def product_features(role)
      pf_result = {}
      role.feature_identifiers.each { |ident| add_product_feature(pf_result, ident) }
      pf_result
    end

    def add_product_feature(pf_result, ident)
      details  = MiqProductFeature.features[ident.to_s][:details]
      children = MiqProductFeature.feature_children(ident)
      add_product_feature_details(pf_result, ident, details, children)
      children.each { |child_ident| add_product_feature(pf_result, child_ident) }
    end

    def add_product_feature_details(pf_result, ident, details, children)
      ident_str = ident.to_s
      res = {
        "name"        => details[:name],
        "description" => details[:description]
      }
      collection, method, action = collection_config.what_refers_to_feature(ident_str)
      collections = collection_config.names_for_feature(ident_str)
      res["href"] = "#{@req.api_prefix}/#{collections.first}" if collections.one?
      res["action"] = api_action_details(collection, method, action) if collection.present?
      res["children"] = children if children.present?
      pf_result[ident_str] = res
    end

    def api_action_details(collection, method, action)
      {
        "name"   => action[:name],
        "method" => method,
        "href"   => "#{@req.api_prefix}/#{collection}"
      }
    end
  end
end
