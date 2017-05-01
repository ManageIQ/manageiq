require "manageiq"

module DatabaseConfigurationPatch
  def database_configuration
    yaml = Pathname.new(File.expand_path("../../config/database.yml", __dir__))

    if yaml.exist?
      require "yaml"
      require "erb"

      data = yaml.read
      data = ERB.new(data).result if !ManageIQ.env.production? || ENV['ERB_IN_CONFIG']

      begin
        # TODO: Allow this to work with miq-yaml:
        #
        # manageiq-gems-pending/gems/pending/util/extensions/miq-yaml
        #
        # rubocop:disable Security/YAMLLoad
        data = YAML.load(data) || {}
        # rubocop:enable Security/YAMLLoad
      rescue Psych::SyntaxError => e
        raise "YAML syntax error occurred while parsing #{paths["config/database"].first}. " \
              "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
              "Error: #{e.message}"
      rescue => e
        raise e, "Cannot load `Rails.application.database_configuration`:\n#{e.message}", e.backtrace
      end

      Vmdb::Settings.decrypt_passwords!(data)
    else
      super
    end
  end
end
