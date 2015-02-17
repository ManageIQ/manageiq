class MiqProvisionWorkflow < MiqRequestWorkflow
  SUBCLASSES = %w{
    MiqProvisionVirtWorkflow
  }
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
MiqProvisionWorkflow::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
