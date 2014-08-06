class AutomateImportService
  def store_for_import(file_contents)
    import_file_upload = ImportFileUpload.create
    import_file_upload.store_binary_data_as_yml(file_contents, "Automate import")
    import_file_upload
  ensure
    queue_deletion(import_file_upload.id)
  end

  private

  def queue_deletion(import_file_upload_id)
    MiqQueue.put(
      :class_name  => "ImportFileUpload",
      :instance_id => import_file_upload_id,
      :deliver_on  => 1.day.from_now,
      :method_name => "destroy"
    )
  end
end
