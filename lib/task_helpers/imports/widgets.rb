module TaskHelpers
  class Imports
    class Widgets
      def import(options = {})
        return unless options[:source]

        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |filename|
          $log.info("Importing Widgets from: #{filename}")

          widget_options = { :userid    => 'admin',
                             :overwrite => options[:overwrite],
                             :save      => true }

          begin
            widget_fd = File.open(filename, 'r')
            MiqWidget.import(widget_fd, widget_options)
          rescue ActiveModel::UnknownAttributeError, RuntimeError => err
            $log.error("Error importing #{filename} : #{err.message}")
            warn("Error importing #{filename} : #{err.message}")
          end
        end
      end
    end
  end
end
