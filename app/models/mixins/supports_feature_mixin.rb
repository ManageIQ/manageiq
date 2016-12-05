module SupportsFeatureMixin
  #
  # Including this in a model gives you a DSL to make features supported or not
  #
  #   class Post
  #     include SupportsFeatureMixin
  #     supports :publish
  #     supports_not :fake, :reason => 'We keep it real'
  #     supports :archive do
  #       unsupported_reason_add(:archive, 'Its too good') if featured?
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
  #   Post.new(featured: true).unsupported_reason(:archive) # => "Its too good"
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
  extend ActiveSupport::Concern

  QUERYABLE_FEATURES = {
    :add_host                   => 'Add Host',
    :add_interface              => 'Add Interface',
    :associate_floating_ip      => 'Associate a Floating IP',
    :clone                      => 'Clone',
    # FIXME: this is just a internal helper and should be refactored
    :control                    => 'Basic control operations',
    :cloud_tenant_mapping       => 'CloudTenant mapping',
    :create                     => 'Creation',
    :backup_create              => 'CloudVolume backup creation',
    :backup_restore             => 'CloudVolume backup restore',
    :cinder_service             => 'Cinder storage service',
    :create_floating_ip         => 'Floating IP Creation',
    :create_host_aggregate      => 'Host Aggregate Creation',
    :create_network_router      => 'Network Router Creation',
    :create_security_group      => 'Security Group Creation',
    :swift_service              => 'Swift storage service',
    :delete                     => 'Deletion',
    :delete_aggregate           => 'Host Aggregate Deletion',
    :delete_floating_ip         => 'Floating IP Deletion',
    :delete_network_router      => 'Network Router Deletion',
    :delete_security_group      => 'Security Group Deletion',
    :disassociate_floating_ip   => 'Disassociate a Floating IP',
    :discovery                  => 'Discovery of Managers for a Provider',
    :evacuate                   => 'Evacuation',
    :events                     => 'Query for events',
    :launch_cockpit             => 'Launch Cockpit UI',
    :live_migrate               => 'Live Migration',
    :migrate                    => 'Migration',
    :provisioning               => 'Provisioning',
    :quick_stats                => 'Quick Stats',
    :reboot_guest               => 'Reboot Guest Operation',
    :reconfigure                => 'Reconfiguration',
    :reconfigure_disks          => 'Reconfigure Virtual Machines Disks',
    :refresh_network_interfaces => 'Refresh Network Interfaces for a Host',
    :refresh_new_target         => 'Refresh non-existing record',
    :regions                    => 'Regions of a Provider',
    :remove_host                => 'Remove Host',
    :remove_interface           => 'Remove Interface',
    :reset                      => 'Reset',
    :resize                     => 'Resizing',
    :retire                     => 'Retirement',
    :smartstate_analysis        => 'Smartstate Analaysis',
    :snapshot_create            => 'Create Snapshot',
    :snapshots                  => 'Snapshots',
    :shutdown_guest             => 'Shutdown Guest Operation',
    :suspend                    => 'Suspending',
    :terminate                  => 'Terminate a VM',
    :timeline                   => 'Query for events',
    :update_aggregate           => 'Host Aggregate Update',
    :update                     => 'Update',
    :update_floating_ip         => 'Update Floating IP association',
    :update_network_router      => 'Network Router Update',
    :ems_network_new            => 'New EMS Network Provider',
    :update_security_group      => 'Security Group Update',
    :block_storage              => 'Block Storage',
    :object_storage             => 'Object Storage',
  }.freeze

  # Whenever this mixin is included we define all features as unsupported by default.
  # This way we can query for every feature
  included do
    QUERYABLE_FEATURES.keys.each do |feature|
      supports_not(feature)
    end
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

    private

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
