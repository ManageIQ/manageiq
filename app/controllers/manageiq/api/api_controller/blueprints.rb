module ManageIQ
  module API
    class ApiController
      module Blueprints
        def create_resource_blueprints(_type, _id, data)
          attributes = data.except("bundle")
          blueprint = Blueprint.new(attributes)
          bundle = data["bundle"]
          create_bundle(blueprint, bundle) if bundle
          blueprint.save!
          blueprint
        end

        private

        def create_bundle(blueprint, bundle)
          options = {}
          if bundle["service_catalog"]
            options[:service_catalog] = ServiceTemplateCatalog.find(parse_id(bundle["service_catalog"], :service_catalogs))
          end
          if bundle["service_dialog"]
            options[:service_dialog] = Dialog.find(parse_id(bundle["service_dialog"], :service_dialogs))
          end
          options[:service_templates] = bundle.fetch("service_templates", []).collect do |st|
            ServiceTemplate.find(parse_id(st, :service_templates))
          end
          options[:entry_points] = bundle["automate_entrypoints"] if bundle["automate_entrypoints"]
          blueprint.create_bundle(options)
        rescue => e
          raise BadRequestError, "Couldn't create the bundle - #{e}"
        end
      end
    end
  end
end
