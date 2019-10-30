require 'fileutils'
require 'inifile'

module MiqConfigSssdLdap
  CHANGE_MODES = %w[httpd ldaps ldap].freeze

  class ConfigureDatabaseError < StandardError; end

  class ConfigureDatabase
    attr_reader :sssd_domain

    def initialize
      LOGGER.debug("Invoked #{self.class}\##{__method__}")
      @sssd_domain = domain_from_sssd
      LOGGER.debug("#{__method__} sssd_domain #{sssd_domain}")
    end

    def change_userids_to_upn
      LOGGER.debug("Invoked #{self.class}\##{__method__}")
      LOGGER.debug("Normalizing userids to User Principal Name (UPN)")

      return unless CHANGE_MODES.include?(Settings.authentication.to_hash[:mode])

      User.all.map do |u|
        next if %w[consumption_admin admin].include?(u.userid)

        LOGGER.debug("Updating userid #{u.userid}")
        save_new_or_delete_duplicate_userid(update_the_userid(u))
      end
    end

    private

    def update_the_userid(user)
      if user.userid.include?(",")
        LOGGER.debug("userid was generated from an MiqLdap login using OpenLdap.")
        user.userid = dn_to_upn(user.userid)
      elsif user.userid.include?("@")
        LOGGER.debug("userid was Generated from an MiqLdap login using Active Directory")
        user.userid = user.userid.downcase
      else
        LOGGER.debug("userid was generated from an SSSD login")
        user.userid = "#{user.userid}@#{sssd_domain}".downcase
      end
      LOGGER.debug("The updated user name is #{user.userid}")
      user
    end

    def save_new_or_delete_duplicate_userid(user)
      LOGGER.debug("Invoked #{self.class}\##{__method__} userid #{user.userid}")
      check_duplicate_u = find_user(user.userid)
      if check_duplicate_u.nil? || check_duplicate_u.id == user.id
        LOGGER.debug("Saving userid #{user.userid}")
        user.save
      else
        LOGGER.debug("Deleting this user, duplicate found #{user.id}")
        user.delete
      end
    end

    def domain_from_sssd
      sssd_ini = IniFile.load(SSSD_CONF_FILE)
      return if sssd_ini.nil?

      sssd_ini.sections[sssd_ini.sections.index { |s| s.include?("domain/") }].split("/")[1]
    end

    def dn_to_upn(userid)
      domain = userid.split(",").collect { |p| p.split('dc=')[1] }.compact.join('.')
      user = userid.split(",").collect { |p| p.split('=')[1] }[0]

      "#{user}@#{domain}".downcase
    end

    def find_user(userid)
      user = User.lookup_by_userid(userid)
      user || User.in_my_region.where('lower(userid) = ?', userid).order(:lastlogon).last
    end
  end
end
