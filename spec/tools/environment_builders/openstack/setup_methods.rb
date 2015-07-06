module SetupMethods
  def base_dir
    File.dirname(__FILE__)
  end

  def settings
    @settings ||= settings_from_file(@environment)
  end

  def settings_from_file(file)
    YAML.load_file(File.join(base_dir, "#{file}.yml"))
  end
end
