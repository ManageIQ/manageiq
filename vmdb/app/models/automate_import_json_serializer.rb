class AutomateImportJsonSerializer
  def serialize(import_file_upload)
    File.open("automate_temporary_zip.zip", "wb") { |file| file.write(import_file_upload.binary_blob.binary) }
    ae_import = MiqAeImport.new("*", "zip_file" => "automate_temporary_zip.zip")

    File.delete("automate_temporary_zip.zip")

    domains = ae_import.domain_entries("*")

    domain_array = domains.collect do |domain|
      {
        :title    => File.dirname(domain),
        :key      => File.dirname(domain),
        :icon     => "/images/icons/new/ae_domain.png",
        :children => build_namespace_list(ae_import, File.dirname(domain))
      }
    end

    {:children => domain_array}.to_json
  end

  private

  def build_namespace_list(ae_import, domain_or_namespace_name)
    ae_import.namespace_files(domain_or_namespace_name).collect do |namespace|
      namespace_name = File.dirname(namespace)
      {
        :title    => namespace_name.split("/").last,
        :key      => namespace_name.split("/")[1..-1].join("/"),
        :icon     => "/images/icons/new/ae_namespace.png",
        :children => build_namespace_list(ae_import, namespace_name)
      }
    end
  end
end
