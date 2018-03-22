module TaskHelpers
  class Exports
    class Tags
      # Tag Categories that are not visible in the UI and should not be exported
      SPECIAL_TAGS = %w(/managed/folder_path_yellow /managed/folder_path_blue /managed/user/role).freeze

      def export(options = {})
        export_dir = options[:directory]

        tags = if options[:all]
                 Classification.includes(:tag).where(:parent_id => 0).where.not(:tags => {:name => SPECIAL_TAGS})
               else
                 export_tags = []
                 Classification.includes(:tag).where(:parent_id => 0).where.not(:tags => {:name => SPECIAL_TAGS}).each do |cat|
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
          fname = Exports.safe_filename(category.description, options[:keep_spaces])
          cat = category.export_to_array
          cat.first["ns"] = category.ns unless category.ns == '/managed'
          File.write("#{export_dir}/#{fname}.yaml", cat.to_yaml)
        end
      end
    end
  end
end
