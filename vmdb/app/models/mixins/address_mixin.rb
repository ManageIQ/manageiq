require 'MiqSockUtil'

module AddressMixin
  extend ActiveSupport::Concern

  # Possible future options: hostname_primary and ipaddress_primary
  def address(type=:ems)
    case self.class.address_configuration(type, :contactwith, :ipaddress).to_sym
    when :hostname           then self.hostname
    when :resolved_ipaddress then MiqSockUtil.resolve_hostname(self.hostname)
    else                          self.ipaddress
    end
  end

  def address_configuration(type, setting, default_value=nil)
    self.class.address_configuration(type, setting, default_value)
  end

  module ClassMethods
    def address_configuration(type, setting, default_value=nil)
      #TODO: Add config level for "class AND type".  Example: [:host][:vmware][:ems]
      vmdb_config = VMDB::Config.new('vmdb').config

      # When searching for config setting check the class first, then check more
      #   generic settings.
      value   = vmdb_config.fetch_path(self.name.underscore.to_sym, type, setting)
      value ||= vmdb_config.fetch_path(type, setting)
      value ||= default_value
      return value
    end
  end
end
