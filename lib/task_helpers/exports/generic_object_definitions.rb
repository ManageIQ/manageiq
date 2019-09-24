module TaskHelpers
  class Exports
    class GenericObjectDefinitions
      def export(options = {})
        export_dir = options[:directory]
        GenericObjectDefinition.all.each do |god|
          filename = Exports.safe_filename(god.name, options[:keep_spaces])
          File.write("#{export_dir}/#{filename}.yaml", god.export_to_array.to_yaml)
        end
      end
    end
  end
end
