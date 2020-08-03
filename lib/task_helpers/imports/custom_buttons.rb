module TaskHelpers
  class Imports
    class CustomButtons
      def import(options)
        return unless options[:source]

        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |filename|
          $log.info("Importing Custom Buttons from: #{filename}")

          begin
            import_custom_buttons(filename, options)
          rescue StandardError
            raise StandardError, "Error importing #{filename} at #{$@}"
          end
        end
      end

      private

      class ImportArInstances
        def self.import(obj_hash, options)
          new.import(obj_hash, options)
        end

        def import(obj_hash, options)
          @connect_dialog =  options[:connect_dialog_by_name]
          @overwrite = options[:overwrite]
          ActiveRecord::Base.transaction { obj_hash.each { |obj_def| create_object(*obj_def) } }
        end

        def create_object(class_name, obj_array)
          klass = class_name.camelize.constantize

          delete_existing_objs(klass, obj_array) if @overwrite

          obj_array.collect do |obj|
            if klass.name == "CustomButtonSet"
              order = obj.fetch_path('attributes', 'set_data', :button_order)
              obj['attributes']['set_data'][:button_order] = nil if order.present?
            end

            klass.create!(obj['attributes']&.except('guid')).tap do |new_obj|
              add_children(obj, new_obj)
              add_associations(obj, new_obj)
              try("#{class_name}_post", new_obj)
            end
          end
        end

        def delete_existing_objs(klass, obj_array)
          objs_to_delete = []
          obj_array.each do |obj|
            if klass.name == "CustomButtonSet"
              objs_to_delete << klass.find_by(:name => obj.fetch_path('attributes', 'name'))
              obj["children"].each do |ch|
                child_klass = ch.first.camelize.constantize
                ch[1].each { |t| objs_to_delete << child_klass.find_by(:name => t.fetch_path('attributes', 'name')) }
              end
            end
          end

          objs_to_delete.compact.each do |obj|
            _log.info("Overwriting #{obj.class.name} #{obj.name}")
            obj.destroy
          end
        end

        def add_children(obj, new_obj)
          if obj['children'].present?
            obj['children'].each do |child|
              new_obj.add_members(create_object(*child))
            end
          end
        end

        def add_associations(obj, new_obj)
          return if obj['associations'].blank?

          obj['associations'].each do |assoc|
            # may contain dialog_label,delete it, then find and connect dialog (optionally)
            dialog_label = assoc.last.first['attributes'].delete('dialog_label')
            resource_action = create_object(*assoc).first
            if @connect_dialog
              resource_action.dialog = Dialog.in_region(MiqRegion.my_region_number).find_by(:label => dialog_label) if dialog_label
            end
            new_obj.send("#{assoc.first}=", resource_action)
          end
        end

        def custom_button_set_post(new_obj)
          new_obj.set_data[:button_order] = new_obj.custom_buttons.collect(&:id)
          new_obj.save!
        end

        def custom_button_post(new_obj)
          check_user(new_obj)
        end

        def check_user(new_obj)
          existing_user = User.find_by(:name => new_obj[:userid])
          new_obj.update(:userid => existing_user.nil? ? "admin" : existing_user)
        end
      end

      def import_custom_buttons(filename, options)
        custom_buttons = YAML.load_file(filename)
        ImportArInstances.import(custom_buttons, options)
      end
    end
  end
end
