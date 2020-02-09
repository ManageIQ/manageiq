require_relative 'rhconsulting_illegal_chars'
require_relative 'rhconsulting_options'

class ServiceDialogImportExport
  class ParsedNonDialogYamlError < StandardError; end

  def export(filedir, options = {})
    raise "Must supply filedir" if filedir.blank?
    dialogs_hash = export_dialogs(Dialog.order(:id).all)
    dialogs_hash.each { |x|
      data = []
      data << x
      # Replace invalid filename characters
      fname = MiqIllegalChars.replace(x['label'], options)
      File.write("#{filedir}/#{fname}.yml", data.to_yaml)
    }
  end

  def import(filedir)
    raise "Must supply filedir" if filedir.blank?
    if File.file?(filedir)
      Dialog.transaction do
        import_dialogs_from_file("#{filedir}")
      end
    elsif File.directory?(filedir)
      Dialog.transaction do
        Dir.foreach(filedir) do |filename|
          next if filename == '.' or filename == '..'
          import_dialogs_from_file("#{filedir}/#{filename}")
        end
      end
    end
  end

  private

  def import_dialogs_from_file(filename)
    dialogs = YAML.load_file(filename)
    import_dialogs(dialogs)
  end

  def build_associations_list(dialog)
    associations = []
    dialog["dialog_tabs"].flat_map do |tab|
      tab["dialog_groups"].flat_map do |group|
        group["dialog_fields"].flat_map do |field|
          associations << { field["name"] => field["dialog_field_responders"] } if field["dialog_field_responders"].present?
        end
      end
    end
    associations
  end

  def check_field_associations(fields)
    puts "Changed! check_for_circular_references fields: #{fields}"
    
    dialog_field_association_validator = DialogFieldAssociationValidator.new
    associations = fields.each_with_object({}) { |df, hsh| hsh.merge!(df["name"] => df["dialog_field_responders"]) if df["dialog_field_responders"].present? }
    raise DialogFieldAssociationCircularReferenceError if dialog_field_association_validator.check_for_circular_references(associations)
  end

  def build_associations(dialog, association_list)
    fields = dialog.dialog_fields
    association_list.each do |association|
      association.each_value do |value|
        value.each do |responder|
          next if fields.select { |field| field.name == responder }.empty?
          DialogFieldAssociation.create(:trigger_id => fields.find { |field| field.name.include?(association.keys.first) }.id,
                                        :respond_id => fields.find { |field| field.name == responder }.id)
        end
      end
    end
  end

  def import_dialogs(dialogs)
    begin
      dialogs.each do |d|
        puts "Dialog: [#{d['label']}]"
        association_list = build_associations_list(d)
        d.delete('blueprint_id') # This field is not found in 4.6 and breaks the import of exports from previous versions.
        dialog = Dialog.find_by_label(d["label"])
        if dialog
          dialog.update_attributes!("dialog_tabs" => import_dialog_tabs(d))
        else
          dialog = Dialog.create(d.merge("dialog_tabs" => import_dialog_tabs(d)))
        end
        build_associations(dialog,association_list)
      end
    rescue
      raise ParsedNonDialogYamlError
    end
  end

  def import_dialog_tabs(dialog)
    dialog["dialog_tabs"].collect do |dialog_tab|
      DialogTab.create(dialog_tab.merge("dialog_groups" => import_dialog_groups(dialog_tab)))
    end
  end

  def import_dialog_groups(dialog_tab)
    dialog_tab["dialog_groups"].collect do |dialog_group|
      DialogGroup.create(dialog_group.merge("dialog_fields" => import_dialog_fields(dialog_group)))
    end
  end

  def import_dialog_fields(dialog_group)
    # TODO the method is outdate with manageiq database. need sync, isuue is opened for this
    # https://github.com/rhtconsulting/cfme-rhconsulting-scripts/issues/148
    # check_field_associations(dialog_group["dialog_fields"])
    
    dialog_group["dialog_fields"].collect do |dialog_field|
      dialog_field.delete('dialog_field_responders')

      # Allow for importing the old format or the new format
      # This will allow for compatibility of exports in both formats
      df = dialog_field['type'].constantize.create(dialog_field.reject { |a| ['resource_action'].include?(a) || ['resource_action_fqname'].include?(a) })

      # This is the old export format that only compatible with the export script
      unless dialog_field['resource_action_fqname'].blank?
        df.resource_action.fqname = dialog_field['resource_action_fqname']
        df.resource_action.save!
      end

      # This is the new format that is compatible with the export script and Web UI
      unless dialog_field['resource_action'].blank?
        df.resource_action.action = dialog_field['resource_action']['action']
        df.resource_action.resource_type = dialog_field['resource_action']['resource_type']
        df.resource_action.ae_namespace = dialog_field['resource_action']['ae_namespace']
        df.resource_action.ae_class = dialog_field['resource_action']['ae_class']
        df.resource_action.ae_instance = dialog_field['resource_action']['ae_instance']
        df.resource_action.ae_message = dialog_field['resource_action']['ae_message']
        df.resource_action.ae_attributes = dialog_field['resource_action']['ae_attributes']
        df.resource_action.save!
      end
      df
    end
  end

  def export_dialogs(dialogs)
    dialogs.map do |dialog|
      dialog_tabs = export_dialog_tabs(dialog.dialog_tabs)

      included_attributes(dialog.attributes, ["created_at", "id", "updated_at"]).merge("dialog_tabs" => dialog_tabs)
    end
  end

  def export_resource_action(resource_action)
    included_attributes(resource_action.attributes, ["created_at", "resource_id", "id", "updated_at"])
  end

  def export_dialog_fields(dialog_fields)
    dialog_fields.map do |dialog_field|
      field_attributes = included_attributes(dialog_field.attributes, ["created_at", "dialog_group_id", "id", "updated_at"])
      if dialog_field.respond_to?(:resource_action) && dialog_field.resource_action
        field_attributes["resource_action"] = {}
        field_attributes["resource_action"]["action"] = dialog_field.resource_action.action
        field_attributes["resource_action"]["resource_type"] = dialog_field.resource_action.resource_type
        field_attributes["resource_action"]["ae_namespace"] = dialog_field.resource_action.ae_namespace
        field_attributes["resource_action"]["ae_class"] = dialog_field.resource_action.ae_class
        field_attributes["resource_action"]["ae_instance"] = dialog_field.resource_action.ae_instance
        field_attributes["resource_action"]["ae_message"] = dialog_field.resource_action.ae_message
        field_attributes["resource_action"]["ae_attributes"] = dialog_field.resource_action.ae_attributes
      end
      if dialog_field.respond_to?(:dialog_field_responders)
        field_attributes["dialog_field_responders"] = []
        dialog_field.dialog_field_responders.each do |responder|
          field_attributes["dialog_field_responders"].push(responder.name)
        end
      end
      field_attributes
    end
  end

  def export_dialog_groups(dialog_groups)
    dialog_groups.map do |dialog_group|
      dialog_fields = export_dialog_fields(dialog_group.dialog_fields)

      included_attributes(dialog_group.attributes, ["created_at", "dialog_tab_id", "id", "updated_at"]).merge("dialog_fields" => dialog_fields)
    end
  end

  def export_dialog_tabs(dialog_tabs)
    dialog_tabs.map do |dialog_tab|
      dialog_groups = export_dialog_groups(dialog_tab.dialog_groups)

      included_attributes(dialog_tab.attributes, ["created_at", "dialog_id", "id", "updated_at"]).merge("dialog_groups" => dialog_groups)
    end
  end

  def included_attributes(attributes, excluded_attributes)
    attributes.reject { |key, _| excluded_attributes.include?(key) }
  end

end

namespace :rhconsulting do
  namespace :service_dialogs do

    desc 'Usage information'
    task :usage => [:environment] do
      puts 'Export - Usage: rake rhconsulting:service_dialogs:export[/path/to/dir/with/dialogs]'
      puts 'Import - Usage: rake rhconsulting:service_dialogs:import[/path/to/dir/with/dialogs]'
    end

    desc 'Import all service dialogs to individual YAML files'
    task :import, [:filedir] => [:environment] do |_, arguments|
      ServiceDialogImportExport.new.import(arguments[:filedir])
    end

    desc 'Exports all service dialogs to individual YAML files'
    task :export, [:filedir] => [:environment] do |_, arguments|
      options = RhconsultingOptions.parse_options(arguments.extras)
      ServiceDialogImportExport.new.export(arguments[:filedir], options)
    end

  end
end


