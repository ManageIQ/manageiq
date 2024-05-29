class MiqProvisionTask < MiqRequestTask
  include MiqProvisionQuotaMixin
  include Tagging

  validates_inclusion_of :state, :in => %w[pending queued active provisioned finished], :message => "should be pending, queued, active, provisioned or finished"

  AUTOMATE_DRIVES = true

  def self.base_model
    MiqProvisionTask
  end

  def statemachine_task_status
    if %w[finished provisioned].include?(state)
      status.to_s.downcase == 'error' ? 'error' : 'ok'
    else
      'retry'
    end
  end

  def do_request
    signal :run_provision
  end

  def self.display_name(number = 1)
    n_('Provision Task', 'Provision Tasks', number)
  end
end
