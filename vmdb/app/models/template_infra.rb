class TemplateInfra < MiqTemplate
  SUBCLASSES = %w{
    TemplateKvm
    TemplateMicrosoft
    TemplateRedhat
    TemplateVmware
    TemplateXen
  }

  default_value_for :cloud, false
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
TemplateInfra::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
