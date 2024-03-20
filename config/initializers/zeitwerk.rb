if ENV['DEBUG_MANAGEIQ_ZEITWERK'].present?
  Zeitwerk::Loader.default_logger = method(:puts)
  Rails.autoloaders.main.logger = Logger.new($stdout)
end

# These specific directories are for code organization, not namespacing:
# TODO: these should be either renamed with good names, the intermediate directory removed
# and/or both.
Rails.autoloaders.main.collapse(Rails.root.join("lib/manageiq/reporting/charting"))
Rails.autoloaders.main.collapse(Rails.root.join("lib/ansible/runner/credential"))
Rails.autoloaders.main.collapse(Rails.root.join("lib/pdf_generator"))

excluded_from_eager_load = %w[
  ApplicationRecord
  MiqDecorator
  OrchestrationStack::Status
  ResourcePool
]

DescendantLoader.instance.discovered_parent_child_classes.each do |parent, children|
  next if excluded_from_eager_load.include?(parent)

  puts "Registering on_load for class: #{parent}"
  Rails.autoloaders.main.on_load(parent.to_s) do |klass, _abspath|
    puts "Running on_load for class: #{klass} with children: #{children}"
    children.each do |child|
      begin
        child.safe_constantize
      rescue NameError => err
        puts "!!! FAILED to load #{child} for parent: #{klass} with inheritance column: #{klass.try(:inheritance_column)} reason: #{err}. Error class: #{err.class.name}"
        raise
      end
    end
  end
end
