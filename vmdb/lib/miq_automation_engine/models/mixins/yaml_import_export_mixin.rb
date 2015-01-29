module YAMLImportExportMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def export_to_array(list, klass)
      begin
        klass = klass.kind_of?(Class) ? klass : Object.const_get(klass)
      rescue => err
        $log.error("MIQ(export_to_array) List: [#{list}], Class: [#{klass}] - #{err.message}")
        return []
      end

      list = klass.where(:id => list) unless list.first.kind_of?(klass)
      list.collect { |obj| obj.export_to_array if obj }.compact.flatten
    end

    def export_to_yaml(list, klass)
      export_to_array(list, klass).to_yaml
    end

    # Import from a file that the user selects to upload
    #
    # @param fd [Integer] file descriptor of the file to be uploaded.
    # @param options [Hash] The properties to change.
    # @option options [Boolean] :save Save into DB the objects to be imported.
    # @option options [Boolean] :overwrite Overwrite the exsiting object.
    # @option options [String] :userid The current user's id, used to check the
    #     user's accessibility to the objects to be imported.
    # @return [Array<Hash>, Array<String>] The array of objects to be imported,
    #   and the array of importing status.
    def import(fd, options = {})
      log_prefix = "MIQ(#{name}).#{__method__}"

      fd.rewind   # ensure to be at the beginning as the file is read multiple times
      begin
        reps = YAML.load(fd.read)
      rescue Psych::SyntaxError => err
        $log.error("#{log_prefix} Failed to load from #{fd}: #{err}")
        raise "Invalid YAML file"
      end

      return reps, import_from_array(reps, options)
    end

    # Import from an array of hash of the objects
    #
    # @param input [Array] The objects to be imported.
    # @param options [Hash] The properties to change.
    # @option (see #import)
    # @return [Array<String>] The array of importing status.
    def import_from_array(input, options = {})
      input.collect do |i|
        begin
          klass = Object.const_get(i.keys.first)
          report = i[klass.to_s]
        rescue
          # for the legacy MiqReport
          klass = MiqReport
          report = i
        end

        _, stat = klass.import_from_hash(report.deep_clone, options)
        stat
      end
    end
  end
end
