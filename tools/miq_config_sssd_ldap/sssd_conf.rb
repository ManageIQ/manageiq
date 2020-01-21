require 'erb'
require 'fileutils'
require 'iniparse'
require 'sssd_conf/domain'
require 'sssd_conf/ifp'
require 'sssd_conf/pam'
require 'sssd_conf/sssd'
require 'auth_template_files'

module MiqConfigSssdLdap
  class SssdConfError < StandardError; end

  class SssdConf < AuthTemplateFiles
    attr_reader :src_path, :dest_path, :ldap_uri, :ldap_search_base, :initial_settings, :sssd_conf_contents

    def initialize(initial_settings)
      LOGGER.debug("Invoked #{self.class}\##{__method__}")

      super

      @src_path   = "#{template_dir}#{SSSD_CONF_DIR}/sssd.conf.erb"
      @dest_path  = "#{SSSD_CONF_DIR}/sssd.conf"
      @ldap_uri   = "#{initial_settings[:mode]}://#{initial_settings[:ldaphost][0]}:#{initial_settings[:ldapport]}"
      @ldap_search_base   = initial_settings[:basedn]
      @sssd_conf_contents = sssd_conf_to_hash
    end

    def update
      LOGGER.debug("Invoked #{self.class}\##{__method__}")

      [Domain, Sssd, Pam, Ifp].each do |section_class|
        section = section_class.new(initial_settings)
        sssd_conf_contents[section.section_name.to_sym] = section.update_attribute_values(sssd_conf_contents)
      end

      write_updates(sssd_conf_contents)
    end

    private

    def create
      LOGGER.debug("Invoked #{self.class}\##{__method__}")

      begin
        File.write(dest_path, ERB.new(File.read(src_path), nil, '-').result(binding))
        FileUtils.chmod(0o600, dest_path)
      rescue Errno::ENOENT, IndexError => e
        LOGGER.fatal(e.message)
        raise SssdConfError, e.message
      end
    end

    def sssd_conf_to_hash
      create unless File.exist?(SSSD_CONF_FILE)

      IniParse.open(SSSD_CONF_FILE).to_hash.deep_transform_keys! do |key|
        key = key.downcase
        key.start_with?("domain/") ? :domain : key.to_sym
      end
    end

    def write_updates(sssd_conf_contents)
      File.open(SSSD_CONF_FILE, "w") do |f|
        sssd_conf_contents.each do |section, values|
          if section == :domain
            f.write("\n[domain/#{initial_settings[:domain]}]\n")
            f.write("\n[application/#{initial_settings[:domain]}]\n")
          else
            f.write("\n[#{section}]\n")
          end
          values.each do |attribute, value|
            f.write("#{attribute} = #{value}\n")
          end
        end
      end
    end
  end
end
