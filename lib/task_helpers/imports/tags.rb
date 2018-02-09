module TaskHelpers
  class Imports
    class Tags
      class ClassificationDescError < StandardError; end
      class ClassificationNameError < StandardError; end
      class ClassificationEntryDescError < StandardError; end
      class ClassificationEntryNameError < StandardError; end
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
        Dir.glob(glob) do |fname|
          begin
            tag_categories = YAML.load_file(fname)
            import_tags(tag_categories)
          rescue ClassificationDescError
            warn("Error importing #{fname} : Tag category description is required")
          rescue ClassificationNameError
            warn("Error importing #{fname} : Tag category name is required")
          rescue ClassificationEntryDescError
            warn("Error importing #{fname} : Tag entry description is required")
          rescue ClassificationEntryNameError
            warn("Error importing #{fname} : Tag entry name is required")
          rescue ClassificationYamlError => e
            warn("Error importing #{fname} : #{e.message}")
            e.details.each { |k, v| warn("#{k}: #{v.first[:error]}") }
          rescue ActiveModel::UnknownAttributeError => e
            warn("Error importing #{fname} : #{e.message}")
          end
        end
      end

      private

      # Description attribute of Tag Categories that are not visible in the UI
      SPECIAL_TAGS = ['Parent Folder Path (VMs & Templates)', 'Parent Folder Path (Hosts & Clusters)', 'User roles'].freeze

      UPDATE_FIELDS = %w(description example_text show perf_by_tag).freeze

      def import_tags(tag_categories)
        tag_categories.each do |tag_category|
          next if SPECIAL_TAGS.include?(tag_category['description'])
          Classification.transaction do
            import_classification(tag_category)
          end
        end
      end

      def import_classification(tag_category)
        raise ClassificationDescError unless tag_category['description']
        raise ClassificationNameError unless tag_category['name']

        classification = Classification.find_by_name(tag_category['name'])

        entries = tag_category.delete('entries')

        if classification
          classification.update_attributes!(tag_category.select { |k| UPDATE_FIELDS.include?(k) })
        else
          classification = Classification.create(tag_category)
          raise ClassificationYamlError.new("Tag Category error", classification.errors.details) if classification.errors.count.positive?
        end

        import_entries(classification, entries)
      end

      def import_entries(classification, entries)
        entries.each do |entry|
          raise ClassificationEntryDescError unless entry['description']
          raise ClassificationEntryNameError unless entry['name']

          tag_entry = classification.find_entry_by_name(entry['name'])

          if tag_entry
            tag_entry.update_attributes!(entry.select { |k| UPDATE_FIELDS.include?(k) })
          else
            Classification.create(entry.merge('parent_id' => classification.id))
            raise ClassificationYamlError.new("Tag Entry error", classification.errors.details) if classification.errors.count.positive?
          end
        end
      end
    end
  end
end
