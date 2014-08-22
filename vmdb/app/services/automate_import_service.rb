class AutomateImportService
  def cancel_import(import_file_upload_id)
    import_file_upload = ImportFileUpload.find(import_file_upload_id)

    destroy_queued_deletion(import_file_upload.id)
    import_file_upload.destroy
  end

  def import_datastore(import_file_upload, domain_name_to_import_from, domain_name_to_import_to, namespace_list)
    File.open("automate_temporary_zip.zip", "wb") { |file| file.write(import_file_upload.binary_blob.binary) }
    import_options = {
      "import_as" => domain_name_to_import_to,
      "overwrite" => true,
      "zip_file"  => "automate_temporary_zip.zip"
    }
    ae_import = MiqAeImport.new(domain_name_to_import_from, import_options)

    ae_import.remove_unrelated_entries(domain_name_to_import_from)
    reject_unrelated_namespaces(ae_import, domain_name_to_import_from, namespace_list)

    ae_import.import

    File.delete("automate_temporary_zip.zip")

    ae_import.import_stats
  end

  def store_for_import(file_contents)
    import_file_upload = ImportFileUpload.create
    import_file_upload.store_binary_data_as_yml(file_contents, "Automate import")
    import_file_upload
  ensure
    queue_deletion(import_file_upload.id)
  end

  private

  def reject_unrelated_namespaces(ae_import, domain_name, namespace_list)
    domain_name_related_files = ae_import.all_namespace_files.select do |namespace_file|
      namespace_file.name.match(domain_name)
    end

    files_to_reject = domain_name_related_files.reject do |domain_name_file|
      namespace_list.include?(File.dirname(domain_name_file.name).split("/")[1..-1].join("/"))
    end

    files_to_reject.each do |file|
      ae_import.remove_entry(file)
    end

    ae_import.update_sorted_entries
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
