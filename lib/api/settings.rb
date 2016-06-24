class Api::Settings
  def self.data
    @data ||= YAML.load_file(Rails.root.join("config/api.yml"))
  end

  def self.base
    data[:base]
  end

  def self.version
    data[:version]
  end

  def self.collections
    data[:collections]
  end
end
