class MiqPolicyImportService
  def cancel_import(import_file_upload_id)
    import_file_upload = ImportFileUpload.find(import_file_upload_id)

    import_file_upload.destroy
    destroy_queued_deletion(import_file_upload_id)
  end

  def import_policy(import_file_upload_id)
    import_file_upload = ImportFileUpload.find(import_file_upload_id)
    MiqPolicy.import_from_array(import_file_upload.uploaded_yaml_content, :save => true)

    import_file_upload.destroy
    destroy_queued_deletion(import_file_upload_id)
  end

  def store_for_import(file_contents)
    import_file_upload = create_import_file_upload(file_contents)
    queue_deletion(import_file_upload.id)

    import_file_upload
  end

  private

  def create_import_file_upload(file_contents)
    uploaded_content, _ = MiqPolicy.import(file_contents, :preview => true)

    ImportFileUpload.create.tap do |import_file_upload|
      import_file_upload.store_binary_data_as_yml(uploaded_content.to_yaml, "Policy import")
    end
  end

  def destroy_queued_deletion(import_file_upload_id)
    MiqQueue.first(
      :conditions => {
        :class_name  => "ImportFileUpload",
        :instance_id => import_file_upload_id,
        :method_name => "destroy"
      }
    ).destroy
  end

  def queue_deletion(import_file_upload_id)
    MiqQueue.put_or_update(
      :class_name  => "ImportFileUpload",
      :instance_id => import_file_upload_id,
      :deliver_on  => 1.day.from_now,
      :method_name => "destroy"
    )
  end
end
