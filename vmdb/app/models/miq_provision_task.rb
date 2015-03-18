class MiqProvisionTask < MiqRequestTask
  include ReportableMixin
  include MiqProvisionQuotaMixin

  alias_attribute :provision_type,        :request_type
  alias_attribute :miq_provision_request, :miq_request

  virtual_belongs_to :miq_provision_request
  virtual_column     :provision_type,       :type => :string

  validates_inclusion_of :state, :in => %w(pending queued active provisioned finished), :message => "should be pending, queued, active, provisioned or finished"

  AUTOMATE_DRIVES = true
  SUBCLASSES      = %w(MiqProvisionTaskVirt)

  def self.base_model
    MiqProvision
  end
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
MiqProvisionTask::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
