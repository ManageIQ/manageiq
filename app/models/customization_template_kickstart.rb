class CustomizationTemplateKickstart < CustomizationTemplate
  DEFAULT_FILENAME = "ks.cfg".freeze

  def self.pxe_server_filename(pxe_image, mac_address)
    "#{pxe_image.class.pxe_server_filename(mac_address)}.ks.cfg"
  end

  def self.pxe_server_filepath(pxe_server, pxe_image, mac_address)
    File.join(pxe_server.customization_directory, pxe_server_filename(pxe_image, mac_address))
  end

  def self.kernel_args(pxe_server, pxe_image, mac_address)
    ks_access_path =
      if pxe_server.access_url.nil?
        nil
      else
        File.join(pxe_server.access_url, pxe_server_filepath(pxe_server, pxe_image, mac_address))
      end

    { :ks => ks_access_path, :ksdevice => mac_address }
  end

  def default_filename
    DEFAULT_FILENAME
  end

  def create_files_on_server(pxe_server, pxe_image, mac_address, _windows_image, substitution_options)
    filepath = self.class.pxe_server_filepath(pxe_server, pxe_image, mac_address)
    contents = script_with_substitution(substitution_options)
    pxe_server.write_file(filepath, contents)
  end

  def delete_files_on_server(pxe_server, pxe_image, mac_address, _windows_image)
    filepath = self.class.pxe_server_filepath(pxe_server, pxe_image, mac_address)
    pxe_server.delete_file(filepath)
  end
end
