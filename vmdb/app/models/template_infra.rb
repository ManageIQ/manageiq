class TemplateInfra < MiqTemplate
  SUBCLASSES = %w{
    TemplateMicrosoft
    TemplateRedhat
    TemplateVmware
    TemplateXen
  }

  default_value_for :cloud, false

  def self.eligible_for_provisioning
    super.where(:type => %w(TemplateRedhat TemplateVmware))
  end

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_template", :vm => self, :host => host)
  end
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
TemplateInfra::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
