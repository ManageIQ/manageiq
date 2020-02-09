#
# Including this in a model gives you a DSL to make features supported or not
#
#   class Post
#     include SupportsFeatureMixin
#     supports :publish
#     supports_not :fake, :reason => 'We keep it real'
#     supports :archive do
#       unsupported_reason_add(:archive, 'It is too good') if featured?
#     end
#   end
#
# To make a feature conditionally supported, pass a block to the +supports+ method.
# The block is evaluated in the context of the instance.
# If you call the private method +unsupported_reason_add+ with the feature
# and a reason, then the feature will be unsupported and the reason will be
# accessible through
#
#   instance.unsupported_reason(:feature)
#
# The above allows you to call +supports_feature?+ or +supports?(feature) :methods
# on the Class and Instance
#
#   Post.supports_publish?                       # => true
#   Post.supports?(:publish)                     # => true
#   Post.new.supports_publish?                   # => true
#   Post.supports_fake?                          # => false
#   Post.supports_archive?                       # => true
#   Post.new(featured: true).supports_archive?   # => false
#
# To get a reason why a feature is unsupported use the +unsupported_reason+ method
#
#   Post.unsupported_reason(:publish)                     # => "Feature not supported"
#   Post.unsupported_reason(:fake)                        # => "We keep it real"
#   Post.new(featured: true).unsupported_reason(:archive) # => "It is too good"
#
# To query for known features you can ask the class or the instance via +feature_known?+
#
#   Post.feature_known?('fake')     # => true
#   Post.new.feature_known?(:fake)  # => true
#   Post.new.feature_known?(:alert) # => false
#
# If you include this concern in a Module that gets included by the Model
# you have to extend that model with +ActiveSupport::Concern+ and wrap the
# +supports+ calls in an +included+ block. This is also true for modules in between!
#
#   module Operations
#     extend ActiveSupport::Concern
#     module Power
#       extend ActiveSupport::Concern
#       included do
#         supports :operation
#       end
#     end
#   end
#
module SupportsFeatureMixin
  extend ActiveSupport::Concern

  QUERYABLE_FEATURES = {
    :add_host                            => 'Add Host',
    :add_interface                       => 'Add Interface',
    :add_security_group                  => 'Add Security Group',
    :associate_floating_ip               => 'Associate a Floating IP',
    :clone                               => 'Clone',
    # FIXME: this is just a internal helper and should be refactored
    :control                             => 'Basic control operations',
    :cloud_tenant_mapping                => 'CloudTenant mapping',
    :cloud_object_store_container_create => 'Create Object Store Container',
    :cloud_object_store_container_clear  => 'Clear Object Store Container',
    :create                              => 'Creation',
    :backup_create                       => 'CloudVolume backup creation',
    :backup_restore                      => 'CloudVolume backup restore',
    :cinder_service                      => 'Cinder storage service',
    :cinder_volume_types                 => 'Cinder volume types',
    :conversion_host                     => 'Conversion host capable',
    :create_floating_ip                  => 'Floating IP Creation',
    :create_host_aggregate               => 'Host Aggregate Creation',
    :create_security_group               => 'Security Group Creation',
    :console                             => 'Remote Console',
    :external_logging                    => 'Launch External Logging UI',
    :swift_service                       => 'Swift storage service',
    :delete                              => 'Deletion',
    :destroy                             => 'Destroy',
    :delete_aggregate                    => 'Host Aggregate Deletion',
    :delete_floating_ip                  => 'Floating IP Deletion',
    :delete_security_group               => 'Security Group Deletion',
    :disassociate_floating_ip            => 'Disassociate a Floating IP',
    :discovery                           => 'Discovery of Managers for a Provider',
    :evacuate                            => 'Evacuation',
    :cockpit_console                     => 'Cockpit Console',
    :html5_console                       => 'HTML5 Console',
    :vmrc_console                        => 'VMRC Console',
    :native_console                      => 'Native Console',
    :launch_cockpit                      => 'Launch Cockpit UI',
    :launch_html5_console                => 'Launch HTML5 Console',
    :launch_vmrc_console                 => 'Launch VMRC Console',
    :launch_native_console               => 'Launch Native Console',
    :admin_ui                            => 'Open Admin UI for a Provider',
    :live_migrate                        => 'Live Migration',
    :warm_migrate                        => 'Warm Migration',
    :migrate                             => 'Migration',
    :capture                             => 'Capture of Capacity & Utilization Metrics',
    :openscap_scan                       => 'OpenSCAP security scan',
    :order                               => 'Service Order',
    :provisioning                        => 'Provisioning',
    :publish                             => 'Publishing',
    :quick_stats                         => 'Quick Stats',
    :reboot_guest                        => 'Reboot Guest Operation',
    :reconfigure                         => 'Reconfiguration',
    :reconfigure_disks                   => 'Reconfigure Virtual Machines Disks',
    :reconfigure_disksize                => 'Reconfigure Virtual Machines Disk Size',
    :reconfigure_network_adapters        => 'Reconfigure Network Adapters',
    :reconfigure_cdroms                  => 'Reconfigure Virtual Machines CD/DVDs',
    :refresh_ems                         => 'Refresh Relationships and Power States',
    :refresh_network_interfaces          => 'Refresh Network Interfaces for a Host',
    :refresh_new_target                  => 'Refresh non-existing record',
    :regions                             => 'Regions of a Provider',
    :remove_all_snapshots                => 'Remove all snapshots',
    :remove_host                         => 'Remove Host',
    :remove_interface                    => 'Remove Interface',
    :remove_security_group               => 'Remove Security Group',
    :remove_snapshot                     => 'Remove Snapshot',
    :remove_snapshot_by_description      => 'Remove snapshot having a description',
    :rename                              => 'Rename a VM',
    :reset                               => 'Reset',
    :resize                              => 'Resizing',
    :retire                              => 'Retirement',
    :revert_to_snapshot                  => 'Revert Snapshot Operation',
    :smartstate_analysis                 => 'Smartstate Analysis',
    :snapshot_create                     => 'Create Snapshot',
    :snapshots                           => 'Snapshots',
    :shutdown_guest                      => 'Shutdown Guest Operation',
    :start                               => 'Start',
    :streaming_refresh                   => 'Streaming refresh',
    :suspend                             => 'Suspending',
    :terminate                           => 'Terminate a VM',
    :timeline                            => 'Query for events',
    :update_aggregate                    => 'Host Aggregate Update',
    :update                              => 'Update',
    :update_floating_ip                  => 'Update Floating IP association',
    :ems_network_new                     => 'New EMS Network Provider',
    :ems_storage_new                    =>  'New EMS Storage Manager',
    :update_security_group               => 'Security Group Update',
    :upgrade_cluster                     => 'Cluster Upgrade',
    :block_storage                       => 'Block Storage',
    :storage_services                    => 'Storage Services',
    :object_storage                      => 'Object Storage',
    :vm_import                           => 'VM Import',
    :volume_multiattachment              => 'Volume Multiattachment',
    :volume_resizing                     => 'Volume Resizing',
    :change_password                     => 'Change Password',
    :volume_availability_zones           => 'Volume Availability Zones',
    :assume_role                         => 'Assume Role',
    :instantiate                         => 'Instantiate',
  }.freeze

  # Whenever this mixin is included we define all features as unsupported by default.
  # This way we can query for every feature
  included do
    QUERYABLE_FEATURES.keys.each do |feature|
      supports_not(feature)
    end

    private_class_method :unsupported
    private_class_method :unsupported_reason_add
    private_class_method :define_supports_feature_methods
  end

  class UnknownFeatureError < StandardError; end

  def self.guard_queryable_feature(feature)
    unless QUERYABLE_FEATURES.key?(feature.to_sym)
      raise UnknownFeatureError, "Feature ':#{feature}' is unknown to SupportsFeatureMixin."
    end
  end

  def self.reason_or_default(reason)
    reason.present? ? reason : _("Feature not available/supported")
  end

  # query instance for the reason why the feature is unsupported
  def unsupported_reason(feature)
    SupportsFeatureMixin.guard_queryable_feature(feature)
    feature = feature.to_sym
    public_send("supports_#{feature}?") unless unsupported.key?(feature)
    unsupported[feature]
  end

  # query the instance if the feature is supported or not
  def supports?(feature)
    SupportsFeatureMixin.guard_queryable_feature(feature)
    public_send("supports_#{feature}?")
  end

  # query the instance if a feature is generally known
  def feature_known?(feature)
    self.class.feature_known?(feature)
  end

  private

  # used inside a +supports+ block to add a reason why the feature is not supported
  # just adding a reason will make the feature unsupported
  def unsupported_reason_add(feature, reason = nil)
    SupportsFeatureMixin.guard_queryable_feature(feature)
    feature = feature.to_sym
    unsupported[feature] = SupportsFeatureMixin.reason_or_default(reason)
  end

  def unsupported
    @unsupported ||= {}
  end

  class_methods do
    # This is the DSL used a class level to define what is supported
    def supports(feature, &block)
      SupportsFeatureMixin.guard_queryable_feature(feature)
      define_supports_feature_methods(feature, &block)
    end

    # supports_not does not take a block, because its never supported
    # and not conditionally supported
    def supports_not(feature, reason: nil)
      SupportsFeatureMixin.guard_queryable_feature(feature)
      define_supports_feature_methods(feature, :is_supported => false, :reason => reason)
    end

    # query the class if the feature is supported or not
    def supports?(feature)
      SupportsFeatureMixin.guard_queryable_feature(feature)
      public_send("supports_#{feature}?")
    end

    # query the class for the reason why something is unsupported
    def unsupported_reason(feature)
      SupportsFeatureMixin.guard_queryable_feature(feature)
      feature = feature.to_sym
      public_send("supports_#{feature}?") unless unsupported.key?(feature)
      unsupported[feature]
    end

    # query the class if a feature is generally known
    def feature_known?(feature)
      SupportsFeatureMixin::QUERYABLE_FEATURES.key?(feature.to_sym)
    end

    def unsupported
      # This is a class variable and it might be modified during runtime
      # because we dont eager load all classes at boot time, so it needs to be thread safe
      @unsupported ||= Concurrent::Hash.new
    end

    # use this for making a class not support a feature
    def unsupported_reason_add(feature, reason = nil)
      SupportsFeatureMixin.guard_queryable_feature(feature)
      feature = feature.to_sym
      unsupported[feature] = SupportsFeatureMixin.reason_or_default(reason)
    end

    def define_supports_feature_methods(feature, is_supported: true, reason: nil, &block)
      method_name = "supports_#{feature}?"
      feature = feature.to_sym

      # defines the method on the instance
      define_method(method_name) do
        unsupported.delete(feature)
        if block_given?
          begin
            instance_eval(&block)
          rescue => e
            _log.log_backtrace(e)
            unsupported_reason_add(feature, "Internal Error: #{e.message}")
          end
        else
          unsupported_reason_add(feature, reason) unless is_supported
        end
        !unsupported.key?(feature)
      end

      # defines the method on the class
      define_singleton_method(method_name) do
        unsupported.delete(feature)
        # TODO: durandom - make reason evaluate in class context, to e.g. include the name of a subclass (.to_proc?)
        unsupported_reason_add(feature, reason) unless is_supported
        !unsupported.key?(feature)
      end
    end
  end
end
