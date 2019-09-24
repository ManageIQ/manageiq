module TaskHelpers
  class Exports
    class Schedules
      def export(options = {})
        export_dir = options[:directory]

        schedules = options[:all] ? MiqSchedule.all : MiqSchedule.where(:userid => 'system', :prod_default => 'system')

        schedules.each do |schedule|
          filename = Exports.safe_filename(schedule.name, options[:keep_spaces])
          File.write("#{export_dir}/#{filename}.yaml", MiqSchedule.export_to_yaml([schedule], MiqSchedule))
        end
      end
    end
  end
end
