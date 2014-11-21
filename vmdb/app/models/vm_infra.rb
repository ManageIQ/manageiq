class VmInfra < Vm
  SUBCLASSES = %w{
    VmKvm
    VmMicrosoft
    VmRedhat
    VmVmware
    VmXen
  }

  default_value_for :cloud, false

  # Show certain non-generic charts
  def cpu_mhz_available?
    true
  end

  def memory_mb_available?
    true
  end

  def self.calculate_power_state(raw_power_state)
    return raw_power_state if raw_power_state == "wait_for_launch"
    super
  end

  def post_create_actions
    inherit_host_mgt_tags
    super
    post_create_autoscan
  end

  private

  def inherit_host_mgt_tags
    return unless host.try(:inherit_mgt_tags)

    log_header = "MIQ(#{self.class.name}#inherit_host_mgt_tags)"
    $log.info("#{log_header} Applying tags from [(#{host.class.name}) #{host.name}] to [(#{self.class.name}) #{name}]")
    tags = host.tag_list(:ns => "/managed").split
    tags.delete_if { |t| t =~ /^power_state/ } # omit power state since this is assigned by the system

    tag_add(tags, :ns => "/managed")
  rescue => err
    $log.log_backtrace(err)
  end

  def post_create_autoscan
    return unless host.try(:autoscan)

    log_header = "MIQ(#{self.class.name}#post_create_autoscan)"
    $log.info("#{log_header} Creating scan job on [(#{self.class.name}) #{name}]")
    scan
  end

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_create", :vm => self, :host => host)
  end
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
VmInfra::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
