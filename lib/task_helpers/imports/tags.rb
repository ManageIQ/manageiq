module TaskHelpers
  class Imports
    class Tags
      class ClassificationYamlError < StandardError
        attr_accessor :details

        def initialize(message = nil, details = nil)
          super(message)
          self.details = details
        end
      end

      def import(options = {})
        return unless options[:source]

        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |filename|
          $log.info("Importing Tags from: #{filename}")

          begin
            tag_categories = YAML.load_file(filename)
            import_tags(tag_categories)
          rescue ClassificationYamlError => err
            $log.error("Error importing #{filename} : #{err.message}")
            warn("Error importing #{filename} : #{err.message}")
            err.details.each do |detail|
              $log.error(detail.to_s)
              warn("\t#{detail}")
            end
          rescue ActiveModel::UnknownAttributeError => err
            $log.error("Error importing #{filename} : #{err.message}")
            warn("Error importing #{filename} : #{err.message}")
          end
        end
      end

      private

      # Tag Categories that are not visible in the UI and should not be imported
      SPECIAL_TAGS = %w(/managed/folder_path_yellow /managed/folder_path_blue /managed/user/role).freeze

      UPDATE_CAT_FIELDS = %w(description example_text show perf_by_tag).freeze
      UPDATE_ENTRY_FIELDS = %w(description name).freeze

      REGION_NUMBER = MiqRegion.my_region_number.freeze

      def import_tags(tag_categories)
        tag_categories.each do |tag_category|
          tag = tag_category["ns"] ? "#{tag_category["ns"]}/#{tag_category["name"]}" : "/managed/#{tag_category["name"]}"
          next if SPECIAL_TAGS.include?(tag)
          Classification.transaction do
            import_classification(tag_category)
          end
        end
      end

      def import_classification(tag_category)
        ns = tag_category["ns"] ? tag_category["ns"] : "/managed"
        tag_category["name"] = tag_category["name"].to_s
        tag_category.delete("parent_id")

        classification = Classification.lookup_by_name(tag_category['name'], REGION_NUMBER, ns)

        entries = tag_category.delete('entries')

        if classification
          classification.update(tag_category.select { |k| UPDATE_CAT_FIELDS.include?(k) })
        else
          classification = Classification.is_category.create(tag_category)
        end

        raise ClassificationYamlError.new("Tag Category error", classification.errors.full_messages) unless classification.valid?

        import_entries(classification, entries)
      end

      def import_entries(classification, entries)
        errors = []
        entries.each_with_index do |entry, index|
          entry["name"] = entry["name"].to_s
          tag_entry = classification.find_entry_by_name(entry['name'])
          tag_entry = classification.entries.detect { |ent| ent.description == entry['description'] } if tag_entry.nil?

          if tag_entry
            tag_entry.update(entry.select { |key| UPDATE_ENTRY_FIELDS.include?(key) })
          else
            tag_entry = Classification.create(entry.merge('parent_id' => classification.id))
          end

          next if tag_entry.valid?
          tag_entry.errors.full_messages.each do |message|
            errors << "Entry #{index}: #{message}"
          end
        end

        raise ClassificationYamlError.new("Tag Entry errors", errors) unless errors.empty?
      end
    end
  end
end
