module SetupMethods
  def base_dir
    File.dirname(__FILE__)
  end

  def settings
    @settings ||= settings_from_file.deep_merge(settings_from_file(@environment))
  end

  def settings_from_file(file = "base")
    path = File.join(base_dir, "#{file}.yml")

    YAML.load_file(path)
  end
end
