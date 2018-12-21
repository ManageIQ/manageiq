module TaskHelpers
  class Exports
    class ScanProfiles
      def export(options = {})
        export_dir = options[:directory]

        scan_item_sets = options[:all] ? ScanItemSet.all : ScanItemSet.where(:read_only => [false, nil])

        scan_item_sets.order(:id).each do |scan_item_set|
          $log.info("Exporting Scan Profile: #{scan_item_set.name} (ID: #{scan_item_set.id})")

          profile = ScanItem.get_profile(scan_item_set.name).first.dup

          %w(id created_on updated_on).each { |key| profile.delete(key) }
          profile['definition'].each do |dd|
            %w(id created_on updated_on description).each { |key| dd.delete(key) }
          end

          scan_profile = profile.to_yaml

          filename = Exports.safe_filename(scan_item_set.name, options[:keep_spaces])
          File.write("#{export_dir}/#{filename}.yaml", scan_profile)
        end
      end
    end
  end
end
