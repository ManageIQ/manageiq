module Ems
class InfraProvider < BaseProvider
  ::EmsInfra = self # XXX

  SUBCLASSES = %w{
    EmsKvm
    EmsMicrosoft
    EmsRedhat
    EmsVmware
  }

  def self.types
    self.subclasses.collect { |c| c.ems_type }
  end

  def self.supported_subclasses
    subclasses - [EmsKvm]
  end

  def self.supported_types
    self.supported_subclasses.collect { |c| c.ems_type }
  end

  #
  # ems_timeouts is a general purpose proc for obtaining
  # read and open timeouts for any ems type and optional service.
  #
  # :ems
  #   :ems_redhat    (This is the type parameter for these methods)
  #     :open_timeout: 3.minutes
  #     :inventory   (This is the optional service parameter for ems_timeouts)
  #        :read_timeout: 5.minutes
  #     :service
  #        :read_timeout: 1.hour
  #
  cache_with_timeout(:ems_config, 2.minutes) { VMDB::Config.new("vmdb").config[:ems] || {} }

  def self.ems_timeouts(type, service = nil)
    read_timeout = open_timeout = nil
    if ems_config[type]
      if service
        if ems_config[type][service.downcase.to_sym]
          config       = ems_config[type][service.downcase.to_sym]
          read_timeout = config[:read_timeout] if config[:read_timeout]
          open_timeout = config[:open_timeout] if config[:open_timeout]
        end
      end
      read_timeout = ems_config[type][:read_timeout] if read_timeout.nil?
      open_timeout = ems_config[type][:open_timeout] if open_timeout.nil?
    end
    read_timeout = read_timeout.to_i_with_method if read_timeout
    open_timeout = open_timeout.to_i_with_method if open_timeout
    [read_timeout, open_timeout]
  end

  #
  # Helper proc to make sure any ems configs defined in template
  # are merged in upon startup.
  #
  def self.merge_config_settings(cfg = VMDB::Config.new("vmdb"))
    path = [:ems, :ems_redhat, :service, :read_timeout]
    cfg.merge_from_template_if_missing(*path)
  end

end
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
Ems::InfraProvider::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
