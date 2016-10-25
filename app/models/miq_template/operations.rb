module MiqTemplate::Operations
  extend ActiveSupport::Concern

  included do
    supports :clone
  end

  def validate_collect_running_processes
    validate_invalid_for_template(_("VM Process collection"))
  end

  def validate_start
    validate_invalid_for_template(_("Start Operation"))
  end

  def validate_stop
    validate_invalid_for_template(_("Stop Operation"))
  end

  def validate_standby_guest
    validate_invalid_for_template(_("Standby Guest Operation"))
  end

  def validate_reset
    validate_invalid_for_template(_("Reset Operation"))
  end

  private

  def validate_invalid_for_template(message_prefix)
    {:available => false,
     :message   => _("%{message} is not available for Images/Templates.") % {:message => message_prefix}}
  end
end
