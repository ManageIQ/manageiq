module Api
  class BlueprintsController < BaseController
    include Subcollections::Tags

    before_action :set_additional_attributes, :only => [:show]

    def create_resource(_type, _id, data)
      attributes = data.except("bundle")
      blueprint = Blueprint.new(attributes)
      bundle = data["bundle"]
      create_bundle(blueprint, bundle) if bundle
      blueprint.save!
      blueprint
    end

    def edit_resource(type, id, data)
      attributes = data.except("bundle")
      blueprint = resource_search(id, type, Blueprint)
      blueprint.update!(attributes)
      bundle = data["bundle"]
      update_bundle(blueprint, bundle) if bundle
      blueprint
    end

    def publish_resource(type, id, data)
      blueprint = resource_search(id, type, Blueprint)
      blueprint.publish(data['bundle_name'])
      blueprint
    end

    private

    def set_additional_attributes
      @additional_attributes = %w(content)
    end

    def create_bundle(blueprint, bundle)
      blueprint.create_bundle(deserialize_bundle(bundle))
    rescue => e
      raise BadRequestError, "Couldn't create the bundle - #{e}"
    end

    def update_bundle(blueprint, bundle)
      blueprint.update_bundle(deserialize_bundle(bundle))
    rescue => e
      raise BadRequestError, "Couldn't update the bundle - #{e}"
    end

    def deserialize_bundle(bundle)
      options = {}
      if bundle.key?("service_catalog")
        options[:service_catalog] = service_catalog_options(bundle)
      end
      if bundle.key?("service_dialog")
        options[:service_dialog] = service_dialog_options(bundle)
      end
      options[:service_templates] = bundle.fetch("service_templates", []).collect do |st|
        resource_search(parse_id(st, :service_templates), :service_templates, ServiceTemplate)
      end
      options[:entry_points] = bundle["automate_entrypoints"] if bundle["automate_entrypoints"]
      options
    end

    def service_catalog_options(bundle)
      if bundle["service_catalog"]
        resource_search(parse_id(bundle["service_catalog"], :service_catalogs),
                        :service_catalogs, ServiceTemplateCatalog)
      end
    end

    def service_dialog_options(bundle)
      if bundle["service_dialog"]
        resource_search(parse_id(bundle["service_dialog"], :service_dialogs), :service_dialogs, Dialog)
      end
    end
  end
end
