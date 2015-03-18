class MiqProvisionTask < MiqRequestTask
  include MiqProvisionQuotaMixin
  include ReportableMixin

  alias_attribute :provision_type,        :request_type
  alias_attribute :miq_provision_request, :miq_request

  validates_inclusion_of :state, :in => %w(pending queued active provisioned finished), :message => "should be pending, queued, active, provisioned or finished"

  virtual_belongs_to :miq_provision_request
  virtual_column     :provision_type,       :type => :string

  AUTOMATE_DRIVES = true
  SUBCLASSES      = %w(MiqProvision)

  def self.base_model
    MiqProvisionTask
  end

  def do_request
    signal :run_provision
  end
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
MiqProvisionTask::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
