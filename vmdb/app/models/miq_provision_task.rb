class MiqProvisionTask < MiqRequestTask
  include MiqProvisionQuotaMixin
  include ReportableMixin

  validates_inclusion_of :state, :in => %w(pending queued active provisioned finished), :message => "should be pending, queued, active, provisioned or finished"

  AUTOMATE_DRIVES = true
  SUBCLASSES      = %w(MiqProvision MiqProvisionTaskConfiguredSystemForeman)

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
