module TaskHelpers
  class Exports
    class ScanProfiles
      def export(options = {})
        export_dir = options[:directory]

        scan_item_sets = if options[:all]
                           ScanItemSet.order(:id).all
                         else
                           ScanItemSet.order(:id).where(:read_only => [false, nil])
                         end

        scan_item_sets.each do |p|
          $log.send(:info, "Exporting Scan Profile: #{p.name} (#{p.description})")

          profile = ScanItem.get_profile(p.name).first.dup

          %w(id created_on updated_on).each { |k| profile.delete(k) }
          profile['definition'].each do |dd|
            %w(id created_on updated_on description).each { |k| dd.delete(k) }
          end

          scan_profile = profile.to_yaml

          file = Exports.safe_filename(p.name, options[:keep_spaces])
          File.write("#{export_dir}/ScanProfile_#{file}.yaml", scan_profile)
        end
      end
    end
  end
end
