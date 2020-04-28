class DialogImportService
  class ImportNonYamlError < StandardError; end
  class ParsedNonDialogYamlError < StandardError; end

  DEFAULT_DIALOG_VERSION = '5.10'.freeze # assumed for dialogs without version info
  CURRENT_DIALOG_VERSION = '5.11'.freeze

  def initialize(dialog_field_importer = DialogFieldImporter.new, dialog_import_validator = DialogImportValidator.new, dialog_field_association_validator = DialogFieldAssociationValidator.new)
    @dialog_field_importer = dialog_field_importer
    @dialog_import_validator = dialog_import_validator
    @dialog_field_association_validator = dialog_field_association_validator
  end

  def cancel_import(import_file_upload_id)
    import_file_upload = ImportFileUpload.find(import_file_upload_id)

    destroy_queued_deletion(import_file_upload.id)
    import_file_upload.destroy
  end

  def import_from_file(filename)
    dialogs = YAML.load_file(filename)

    begin
      dialogs.each do |dialog|
        dialog.except!(:blueprint_id, 'blueprint_id') # blueprint_id might appear in some old dialogs, but no longer exists
        if dialog_with_label?(dialog["label"])
          yield dialog if block_given?
        else
          Dialog.create(dialog.except('export_version').merge("dialog_tabs" => build_dialog_tabs(dialog, dialog['export_version'] || DEFAULT_DIALOG_VERSION)))
        end
      end
    rescue DialogFieldImporter::InvalidDialogFieldTypeError
      raise
    rescue
      raise ParsedNonDialogYamlError
    end
  end

  def import_all_service_dialogs_from_yaml_file(filename)
    dialogs = YAML.load_file(filename)

    import_from_dialogs(dialogs)
  end

  def import_service_dialogs(import_file_upload, dialogs_to_import)
    unless dialogs_to_import.nil?
      dialogs = YAML.load(import_file_upload.uploaded_content)
      dialogs = dialogs.select do |dialog|
        dialogs_to_import.include?(dialog["label"])
      end

      import_from_dialogs(dialogs)
    end

    destroy_queued_deletion(import_file_upload.id)
    import_file_upload.destroy
  end

  def store_for_import(file_contents)
    import_file_upload = create_import_file_upload(file_contents)

    @dialog_import_validator.determine_validity(import_file_upload)

    import_file_upload
  ensure
    queue_deletion(import_file_upload.id)
  end

  def build_dialog_tabs(dialog, export_version = CURRENT_DIALOG_VERSION)
    dialog["dialog_tabs"].collect do |dialog_tab|
      DialogTab.create!(dialog_tab.merge("dialog_groups" => build_dialog_groups(dialog_tab, export_version)))
    end
  end

  def build_dialog_groups(dialog_tab, export_version = CURRENT_DIALOG_VERSION)
    dialog_tab["dialog_groups"].collect do |dialog_group|
      DialogGroup.create!(dialog_group.merge("dialog_fields" => build_dialog_fields(dialog_group, export_version)))
    end
  end

  def build_dialog_fields(dialog_group, export_version = CURRENT_DIALOG_VERSION)
    check_field_associations(dialog_group["dialog_fields"])
    dialog_group["dialog_fields"].collect do |dialog_field|
      dialog_field["options"].try(:symbolize_keys!)
      @dialog_field_importer.import_field(dialog_field, export_version)
    end
  end

  def build_resource_actions(dialog)
    (dialog['resource_actions'] || []).collect do |resource_action|
      ResourceAction.create!(resource_action.merge('dialog_id' => dialog['id']))
    end
  end

  def check_field_associations(fields)
    associations = fields.each_with_object({}) { |df, hsh| hsh.merge!(df["name"] => df["dialog_field_responders"]) if df["dialog_field_responders"].present? }
    associations.each_key { |k| @dialog_field_association_validator.check_for_circular_references(associations, k) }
  end

  def import(dialog)
    ActiveRecord::Base.transaction do
      @dialog_import_validator.determine_dialog_validity(dialog)
      new_dialog = Dialog.create(dialog.except('dialog_tabs', 'export_version'))
      association_list = build_association_list(dialog)
      new_dialog.update!(dialog.merge('dialog_tabs' => build_dialog_tabs(dialog, dialog['export_version'] || DEFAULT_DIALOG_VERSION)))
      build_associations(new_dialog, association_list)
      new_dialog
    end
  end

  def build_associations(dialog, association_list)
    fields = dialog.dialog_fields
    association_list.each do |association|
      association.each_value do |value|
        value.each do |responder|
          next if fields.select { |field| field.name == responder }.empty?
          DialogFieldAssociation.create!(:trigger_id => fields.find { |field| field.name.include?(association.keys.first) }.id,
                                        :respond_id => fields.find { |field| field.name == responder }.id)
        end
      end
    end
  end

  def build_association_list(dialog)
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

  private

  def create_import_file_upload(file_contents)
    ImportFileUpload.create.tap do |import_file_upload|
      import_file_upload.store_binary_data_as_yml(file_contents, "Service dialog import")
    end
  end

  def import_from_dialogs(dialogs)
    raise ParsedNonDialogYamlError if dialogs.empty?
    dialogs.each do |dialog|
      dialog.except!(:blueprint_id, 'blueprint_id') # blueprint_id might appear in some old dialogs, but no longer exists
      new_or_existing_dialog = Dialog.where(:label => dialog["label"]).first_or_create
      dialog['id'] = new_or_existing_dialog.id
      new_associations = build_association_list(dialog)
      new_or_existing_dialog.update!(
        dialog.except('export_version').merge(
          "dialog_tabs"      => build_dialog_tabs(dialog, dialog['export_version'] || DEFAULT_DIALOG_VERSION),
          "resource_actions" => build_resource_actions(dialog)
        )
      )
      association_list = new_associations.reject(&:blank?).present? ? new_associations : build_old_association_list(new_or_existing_dialog.dialog_fields).flatten
      build_associations(new_or_existing_dialog, association_list.reject(&:blank?))
    end
  end

  def dialog_with_label?(label)
    Dialog.where("label" => label).exists?
  end

  def build_old_association_list(fields)
    trigger_fields = absolute_position(fields.select(&:trigger_auto_refresh))
    responder_fields = absolute_position(fields.select(&:auto_refresh))
    trigger_fields.enum_for(:each_with_index).collect do |tf, index|
      specific_responders = if trigger_fields[index + 1]
                              responder_fields.select { |rf| responder_range(tf, trigger_fields[index + 1]).cover?(rf[:position]) }.pluck(:name)
                            else
                              responder_fields.select { |rf| responder_range(tf, nil).cover?(rf[:position]) }.pluck(:name)
                            end
      {tf[:name] => specific_responders}
    end
  end

  def absolute_position(dialog_fields)
    dialog_fields.collect do |f|
      field_position = f.position
      dialog_group_position = f.dialog_group.position
      dialog_tab_position = f.dialog_group.dialog_tab.position
      index = field_position + dialog_group_position * 1000 + dialog_tab_position * 100_000
      {:name => f.name, :position => index}
    end
  end

  def responder_range(trigger_min, trigger_max)
    min = trigger_min[:position] + 1
    max = trigger_max.present? ? trigger_max[:position] - 1 : 100_000_000
    (min..max)
  end

  def destroy_queued_deletion(import_file_upload_id)
    MiqQueue.unqueue(
      :class_name  => "ImportFileUpload",
      :instance_id => import_file_upload_id,
      :method_name => "destroy"
    )
  end

  def queue_deletion(import_file_upload_id)
    MiqQueue.put(
      :class_name  => "ImportFileUpload",
      :instance_id => import_file_upload_id,
      :deliver_on  => 1.day.from_now,
      :method_name => "destroy"
    )
  end
end
