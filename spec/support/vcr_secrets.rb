require "config"

class VcrSecrets
  DEFAULTS_FILE = "spec/config/secrets.defaults.yml".freeze
  SECRETS_FILE  = "spec/config/secrets.yml".freeze

  def self.secrets
    @secrets ||= Config.load_files(_root.join(DEFAULTS_FILE), _root.join(SECRETS_FILE))
  end

  def self.defaults
    @defaults ||= Config.load_files(_root.join(DEFAULTS_FILE))
  end

  def self.method_missing(m)
    secrets[m]
  end

  def self.respond_to_missing?(_m)
    true
  end

  def self.define_cassette_placeholder(vcr_config, toplevel_key, secret_key)
    vcr_config.define_cassette_placeholder(defaults[toplevel_key][secret_key]) do
      secrets[toplevel_key][secret_key]
    end
  end

  def self.define_all_cassette_placeholders(vcr_config, toplevel_key)
    secrets[toplevel_key].keys.each do |secret_key| # rubocop:disable Style/HashEachMethods
      define_cassette_placeholder(vcr_config, toplevel_key, secret_key)
    end
  end

  private_class_method def self._root
    @root ||= defined?(ENGINE_ROOT) ? Pathname.new(ENGINE_ROOT) : Rails.root
  end
end
