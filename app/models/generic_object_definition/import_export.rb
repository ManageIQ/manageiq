module GenericObjectDefinition::ImportExport
  extend ActiveSupport::Concern

  IMPORT_CLASS_NAMES = %w[GenericObjectDefinition].freeze

  module ClassMethods
    def import_from_hash(god, options = nil)
      raise _("No Generic Object Definition to Import") if god.nil?
      if god["name"].blank? || god["properties"].blank?
        raise _("Incorrect format.")
      end
      existing_god = GenericObjectDefinition.find_by(:name => god["name"])
      if existing_god.present?
        if options[:overwrite]
          # if generic object definition exists, overwrite its content
          msg = "Overwriting Generic Object Definition: [#{existing_god.name}]"
          existing_god.attributes = god
          result = {
            :message => "Replaced Generic Object Definition: [#{god["name"]}]",
            :level   => :info,
            :status  => :update
          }
        else
          # if generic object definition exists, do not overwrite
          msg = "Skipping Generic Object Definition (already in DB): [#{existing_god.name}]"
          result = {:message => msg, :level => :error, :status => :skip}
        end
      else
        # create new generic object definition
        msg = "Importing Generic Object Definition: [#{god["name"]}]"
        existing_god = GenericObjectDefinition.new(god)
        result = {
          :message => "Imported Generic Object Definition: [#{god["name"]}]",
          :level   => :info,
          :status  => :add
        }
      end
      _log.info(msg)

      if result[:status].in?([:add, :update])
        existing_god.save!
        _log.info("- Completed.")
      end

      return god, result
    end
  end

  def export_to_array
    god_attrs = attributes
    ["id", "created_at", "updated_at"].each { |god| god_attrs.delete(god) }
    [{self.class.to_s => god_attrs}]
  end
end
