class ApiController
  module Blueprints
    def create_resource_blueprints(_type, _id, data)
      attributes = data.except("bundle")
      blueprint = Blueprint.create!(attributes)
      bundle = data["bundle"]
      create_bundle(blueprint, bundle) if bundle
      blueprint
    end

    private

    def create_bundle(blueprint, bundle)
      service_catalog = ServiceTemplateCatalog.find(parse_id(bundle["service_catalog"], :service_catalogs))
      service_dialog = Dialog.find(parse_id(bundle["service_dialog"], :service_dialogs))
      service_templates = bundle["service_templates"].collect do |st|
        ServiceTemplate.find(parse_id(st, :service_templates))
      end
      automate_entrypoints = bundle["automate_entrypoints"]
      blueprint.create_bundle(service_templates,
                              service_dialog,
                              service_catalog,
                              "entry_points" => automate_entrypoints)
    rescue => e
      raise BadRequestError, "Couldn't create the bundle - #{e}"
    end
  end
end
