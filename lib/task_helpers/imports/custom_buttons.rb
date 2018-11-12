module TaskHelpers
  class Imports
    class CustomButtons
      def import(options)
        return unless options[:source]
        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |filename|
          $log.info("Importing Custom Buttons from: #{filename}")

          begin
            import_custom_buttons(filename)
          rescue StandardError
            raise StandardError, "Error importing #{filename} at #{$@}"
          end
        end
      end

      private

      class ImportArInstances
        def self.import(obj_hash)
          new.import(obj_hash)
        end

        def import(obj_hash)
          ActiveRecord::Base.transaction { obj_hash.each { |obj_def| create_object(*obj_def) } }
        end

        def create_object(class_name, obj_array)
          klass = class_name.camelize.constantize

          obj_array.collect do |obj|
            begin
              klass.create!(obj['attributes']&.except('guid')).tap do |new_obj|
                add_children(obj, new_obj)
                add_associations(obj, new_obj)
                try("#{class_name}_post", new_obj)
              end
            rescue StandardError
              raise
            end
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
          if obj['associations'].present?
            obj['associations'].each do |assoc|
              new_obj.send("#{assoc.first}=", create_object(*assoc).first)
            end
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
          new_obj.update_attributes(:userid => existing_user.nil? ? "admin" : existing_user)
        end
      end

      def import_custom_buttons(filename)
        custom_buttons = YAML.load_file(filename)
        ImportArInstances.import(custom_buttons)
      end
    end
  end
end
