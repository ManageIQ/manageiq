class DialogImportService
  class ImportNonYamlError < StandardError; end
  class ParsedNonDialogYamlError < StandardError; end

  def initialize(dialog_field_importer = DialogFieldImporter.new, dialog_import_validator = DialogImportValidator.new)
    @dialog_field_importer = dialog_field_importer
    @dialog_import_validator = dialog_import_validator
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
        if dialog_with_label?(dialog["label"])
          yield dialog if block_given?
        else
          Dialog.create(dialog.merge("dialog_tabs" => build_dialog_tabs(dialog)))
        end
      end
    rescue DialogFieldImporter::InvalidDialogFieldTypeError
      raise
    rescue
      raise ParsedNonDialogYamlError
    end
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

  private

  def create_import_file_upload(file_contents)
    ImportFileUpload.create.tap do |import_file_upload|
      import_file_upload.store_binary_data_as_yml(file_contents, "Service dialog import")
    end
  end

  def import_from_dialogs(dialogs)
    begin
      raise ParsedNonDialogYamlError if dialogs.empty?

      dialogs.each do |dialog|
        new_or_existing_dialog = Dialog.where(:label => dialog["label"]).first_or_create
        new_or_existing_dialog.update_attributes(dialog.merge("dialog_tabs" => build_dialog_tabs(dialog)))
      end
    rescue DialogFieldImporter::InvalidDialogFieldTypeError
      raise
    end
  end

  def build_dialog_tabs(dialog)
    dialog["dialog_tabs"].collect do |dialog_tab|
      DialogTab.create(dialog_tab.merge("dialog_groups" => build_dialog_groups(dialog_tab)))
    end
  end

  def build_dialog_groups(dialog_tab)
    dialog_tab["dialog_groups"].collect do |dialog_group|
      DialogGroup.create(dialog_group.merge("dialog_fields" => build_dialog_fields(dialog_group)))
    end
  end

  def build_dialog_fields(dialog_group)
    dialog_group["dialog_fields"].collect do |dialog_field|
      @dialog_field_importer.import_field(dialog_field)
    end
  end

  def dialog_with_label?(label)
    Dialog.where("label" => label).exists?
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
