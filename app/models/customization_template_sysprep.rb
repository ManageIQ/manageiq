class CustomizationTemplateSysprep < CustomizationTemplate
  DISKPART_FILENAME = "diskpart.txt".freeze
  DISKPART_CONTENTS = <<-EOF
select disk 0
clean
create partition primary
select partition 1
format fs=ntfs label="Windows" quick
assign letter=c
active
exit
EOF

  IMAGE_BAT_FILENAME = "image.bat".freeze
  IMAGE_BAT_CONTENTS = <<-EOF
diskpart /s diskpart.txt
s:\\<%= evm[:windows_images_directory] %>\\imagex.exe /apply s:\\<%= evm[:windows_images_directory] %>\\<%= evm[:windows_image_path] %> <%= evm[:windows_image_index] %> c:
copy unattend.xml c:\\windows\\system32\\sysprep\\
bcdboot c:\\windows /s c:
s:\\<%= evm[:windows_images_directory] %>\\curl <%= evm[:post_install_callback_url] %>
wpeutil shutdown
EOF

  UNATTEND_FILENAME = "unattend.xml".freeze

  def self.pxe_server_filepath(pxe_server, pxe_image, mac_address)
    File.join(pxe_server.customization_directory, pxe_image.class.pxe_server_filename(mac_address))
  end

  def default_filename
    UNATTEND_FILENAME
  end

  def create_files_on_server(pxe_server, pxe_image, mac_address, windows_image, substitution_options)
    filepath = self.class.pxe_server_filepath(pxe_server, pxe_image, mac_address)
    unattend_contents = script_with_substitution(substitution_options)

    image_bat_options = substitution_options.merge(
      :windows_images_directory => pxe_server.windows_images_directory.chomp("/").gsub("/", "\\\\"),
      :windows_image_path       => windows_image.path.chomp("/").gsub("/", "\\\\"),
      :windows_image_index      => windows_image.index,
    )
    image_bat_contents = self.class.substitute_erb(IMAGE_BAT_CONTENTS, image_bat_options)

    pxe_server.with_depot do
      pxe_server.write_file(File.join(filepath, DISKPART_FILENAME),  DISKPART_CONTENTS)
      pxe_server.write_file(File.join(filepath, IMAGE_BAT_FILENAME), image_bat_contents)
      pxe_server.write_file(File.join(filepath, UNATTEND_FILENAME),  unattend_contents)
    end
  end

  def delete_files_on_server(pxe_server, pxe_image, mac_address, _windows_image)
    filepath = self.class.pxe_server_filepath(pxe_server, pxe_image, mac_address)
    pxe_server.delete_directory(filepath)
  end
end
