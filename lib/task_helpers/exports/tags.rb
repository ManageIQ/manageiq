module TaskHelpers
  class Exports
    class Tags
      # Description attribute of Tag Categories that are not visible in the UI
      SPECIAL_TAGS = ['Parent Folder Path (VMs & Templates)', 'Parent Folder Path (Hosts & Clusters)', 'User roles'].freeze

      def export(options = {})
        export_dir = options[:directory]

        tags = if options[:all]
                 Classification.where('parent_id = ? AND description NOT IN (?)', 0, SPECIAL_TAGS)
               else
                 export_tags = []
                 Classification.where('parent_id = ? AND description NOT IN (?)', 0, SPECIAL_TAGS).each do |cat|
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
          File.write("#{export_dir}/#{fname}.yaml", category.export_to_yaml)
        end
      end
    end
  end
end
