module Api
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
        if bundle.key?("service_catalog")
          options[:service_catalog] = service_catalog_options(bundle)
        end
        if bundle.key?("service_dialog")
          options[:service_dialog] = service_dialog_options(bundle)
        end
        options[:service_templates] = bundle.fetch("service_templates", []).collect do |st|
          ServiceTemplate.find(parse_id(st, :service_templates))
        end
        options[:entry_points] = bundle["automate_entrypoints"] if bundle["automate_entrypoints"]
        options
      end

      def service_catalog_options(bundle)
        if bundle["service_catalog"]
          ServiceTemplateCatalog.find(parse_id(bundle["service_catalog"], :service_catalogs))
        end
      end

      def service_dialog_options(bundle)
        Dialog.find(parse_id(bundle["service_dialog"], :service_dialogs)) if bundle["service_catalog"]
      end
    end
  end
end
