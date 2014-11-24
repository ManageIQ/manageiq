def spec_dir
  @spec_dir ||= File.expand_path(File.join(File.dirname(__FILE__), '..'))
end

def lib_dir
  @lib_dir ||= File.expand_path(File.join(spec_dir, '..'))
end

def lib_disk_dir
  @lib_disk_dir ||= File.expand_path(File.join(lib_dir, "disk"))
end

def image_dir
  @image_dir ||= File.join('spec', 'images')
end

def image_for(id)
  File.join(image_dir, id)
end
