module TaskHelpers
  class Imports
    class ScanProfiles
      def import(options)
        return unless options[:source]

        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/ScanProfile_*.yaml"
        Dir.glob(glob) do |filename|
          begin
            import_scan_profile(filename)
          rescue
            warn("Error importing #{options[:source]}")
          end
        end
      end

      private

      def import_scan_profile(filename)
        scan_profiles = YAML.load_file(filename)
        items = scan_profiles.delete("definition")

        profile = ScanItemSet.find_by(:name => scan_profiles["name"])

        if profile.nil?
          if scan_profiles["guid"].nil?
            scan_profiles["guid"] = SecureRandom.uuid
          end
          profile = ScanItemSet.new(scan_profiles)
        else
          profile.attributes = scan_profiles
        end
        profile.save!

        items.each do |item|
          next if item['filename']
          if item['guid'].nil?
            item['guid'] = SecureRandom.uuid
          end
          scan_item = ScanItem.create(item)
          profile.add_member(scan_item)
        end
      end
    end
  end
end
