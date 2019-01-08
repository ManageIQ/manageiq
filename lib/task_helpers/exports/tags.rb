module TaskHelpers
  class Exports
    class Tags
      # Tag Categories that are not visible in the UI and should not be exported
      SPECIAL_TAGS = %w(/managed/folder_path_yellow /managed/folder_path_blue /managed/user/role).freeze

      def export(options = {})
        export_dir = options[:directory]

        tags = if options[:all]
                 Classification.is_category.includes(:tag).where.not(:tags => {:name => SPECIAL_TAGS})
               else
                 export_tags = []
                 Classification.is_category.includes(:tag).where.not(:tags => {:name => SPECIAL_TAGS}).each do |cat|
                   if !cat.default
                     export_tags << cat
                   else
                     cat.entries.each do |entry|
                       unless entry.default
                         export_tags << cat
                         break
                       end
                     end
                   end
                 end
                 export_tags
               end

        tags.each do |category|
          $log.info("Exporting Tag Category: #{category.description} (ID: #{category.id})")

          category_array = category.export_to_array
          category_array.first["ns"] = category.ns unless category.ns == '/managed'

          filename = Exports.safe_filename(category.description, options[:keep_spaces])
          File.write("#{export_dir}/#{filename}.yaml", category_array.to_yaml)
        end
      end
    end
  end
end
