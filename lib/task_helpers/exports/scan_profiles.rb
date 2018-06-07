module TaskHelpers
  class Exports
    class ScanProfiles
      def export(options = {})
        export_dir = options[:directory]

        ScanItemSet.all.each do |p|
          next if p.read_only
          next if p.members.map { |m| m.slice(:filename) }

          $log.send(level, "Exporting Scan Profile: #{p.name} (#{p.description})")

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
