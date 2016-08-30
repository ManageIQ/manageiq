module ManageIQ
  module API
    class BaseController
      module Blueprints
        def show_blueprints
          @additional_attributes = %w(content)
          show_generic
        end

        def create_resource_blueprints(_type, _id, data)
          attributes = data.except("bundle")
          blueprint = Blueprint.new(attributes)
          bundle = data["bundle"]
          create_bundle(blueprint, bundle) if bundle
          blueprint.save!
          blueprint
        end

        def edit_resource_blueprints(_type, id, data)
          attributes = data.except("bundle")
          blueprint = Blueprint.find(id)
          blueprint.update!(attributes)
          bundle = data["bundle"]
          update_bundle(blueprint, bundle) if bundle
          blueprint
        end

        private

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
          options[:service_catalog] = if bundle["service_catalog"]
                                        ServiceTemplateCatalog.find(
                                          parse_id(bundle["service_catalog"], :service_catalogs))
                                      end
          options[:service_dialog] = if bundle["service_dialog"]
                                       Dialog.find(parse_id(bundle["service_dialog"], :service_dialogs))
                                     end
          options[:service_templates] = bundle.fetch("service_templates", []).collect do |st|
            ServiceTemplate.find(parse_id(st, :service_templates))
          end
          options[:entry_points] = bundle["automate_entrypoints"] if bundle["automate_entrypoints"]
          options
        end
      end
    end
  end
end
