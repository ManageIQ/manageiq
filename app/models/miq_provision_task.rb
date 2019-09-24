class MiqProvisionTask < MiqRequestTask
  include MiqProvisionQuotaMixin
  include_concern 'Tagging'

  validates_inclusion_of :state, :in => %w(pending queued active provisioned finished), :message => "should be pending, queued, active, provisioned or finished"

  AUTOMATE_DRIVES = true

  def self.base_model
    MiqProvisionTask
  end

  def do_request
    signal :run_provision
  end

  def self.display_name(number = 1)
    n_('Provision Task', 'Provision Tasks', number)
  end
end
