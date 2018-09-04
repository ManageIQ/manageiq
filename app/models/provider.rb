class Provider < ApplicationRecord
  include NewWithTypeStiMixin
  include AuthenticationMixin
  include AsyncDeleteMixin
  include EmsRefresh::Manager
  include SupportsFeatureMixin
  include TenancyMixin

  belongs_to :tenant
  belongs_to :zone
  has_many :managers, :class_name => "ExtManagementSystem"

  has_many :endpoints, :through => :managers, :autosave => true

  delegate :verify_ssl,
           :verify_ssl?,
           :verify_ssl=,
           :url,
           :to => :default_endpoint

  virtual_column :verify_ssl,        :type => :integer
  virtual_column :security_protocol, :type => :string

  supports :refresh_ems

  def self.leaf_subclasses
    descendants.select { |d| d.subclasses.empty? }
  end

  def self.supported_subclasses
    subclasses.flat_map do |s|
      s.subclasses.empty? ? s : s.supported_subclasses
    end
  end

  def self.short_token
    parent.name.demodulize
  end

  def self.api_allowed_attributes
    %w[]
  end

  def image_name
    self.class.short_token.underscore
  end

  def default_endpoint
    default = endpoints.detect { |e| e.role == "default" }
    default || endpoints.build(:role => "default")
  end

  def with_provider_connection(options = {})
    raise _("no block given") unless block_given?
    _log.info("Connecting through #{self.class.name}: [#{name}]")
    yield connect(options)
  end

  def my_zone
    zone.try(:name).presence || MiqServer.my_zone
  end
  alias_method :zone_name, :my_zone

  def refresh_ems(opts = {})
    if missing_credentials?
      raise _("no Provider credentials defined")
    end
    unless authentication_status_ok?
      raise _("Provider failed last authentication check")
    end
    managers.flat_map { |manager| EmsRefresh.queue_refresh(manager, nil, opts) }
  end

  def self.destroy_queue(ids)
    find(ids).each(&:destroy_queue)
  end

  def destroy_queue
    msg = "Destroying #{self.class.name} with id: #{id}"

    _log.info(msg)
    task = MiqTask.create(
      :name    => msg,
      :state   => MiqTask::STATE_QUEUED,
      :status  => MiqTask::STATUS_OK,
      :message => msg,
    )
    self.class._queue_task('destroy', [id], task.id)
    task.id
  end

  def destroy(task_id = nil)
    _log.info("To destroy managers of provider: #{self.class.name} with id: #{id}")
    managers.each(&:destroy)

    _log.info("To destroy provider: #{self.class.name} with id: #{id}")
    super().tap do
      if task_id
        msg = "#{self.class.name} with id: #{id} destroyed"
        MiqTask.update_status(task_id, MiqTask::STATE_FINISHED, MiqTask::STATUS_OK, msg)
        _log.info(msg)
      end
    end
  end
end
