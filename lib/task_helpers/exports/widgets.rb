module TaskHelpers
  class Exports
    class Widgets
      def export(options = {})
        export_dir = options[:directory]

        widgets = options[:all] ? MiqWidget.all : MiqWidget.where(:read_only => false)

        widgets.each do |widget|
          filename = Exports.safe_filename(widget.description, options[:keep_spaces], options[:super_safe_filename])
          File.write("#{export_dir}/#{filename}.yaml", MiqWidget.export_to_yaml([widget.id], MiqWidget))
        end
      end
    end
  end
end
