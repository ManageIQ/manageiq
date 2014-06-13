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

    def column_for_find_by_address(type=:ems)
      case self.address_configuration(type, :contactwith, :ipaddress).to_sym
      when :hostname           then :hostname
      when :resolved_ipaddress then :ipaddress # TODO: Support actual reverse lookup
      else                          :ipaddress
      end
    end

    def find_first_by_address(addr, type=:ems)
      self.find(:first, :conditions => {self.column_for_find_by_address(type) => addr})
    end
    alias find_by_address find_first_by_address

    def find_all_by_address(addr, type=:ems)
      self.find(:all, :conditions => {self.column_for_find_by_address(type) => addr})
    end
  end
end
