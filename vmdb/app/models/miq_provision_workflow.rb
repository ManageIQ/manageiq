class MiqProvisionWorkflow < MiqRequestWorkflow
  SUBCLASSES = %w{
    MiqProvisionVirtWorkflow
  }

  def self.class_for_platform(platform)
    "MiqProvision#{platform.titleize}Workflow".constantize
  end

  def self.class_for_source(source_or_id)
    source = source_or_id.kind_of?(ActiveRecord) ? source_or_id : VmOrTemplate.find_by_id(source_or_id)
    return nil if source.nil?
    class_for_platform(source.class.model_suffix)
  end
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
MiqProvisionWorkflow::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
