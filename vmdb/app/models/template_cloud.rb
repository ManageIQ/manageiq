class TemplateCloud < MiqTemplate
  default_value_for :cloud, true

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_template", :vm => self)
  end
end
