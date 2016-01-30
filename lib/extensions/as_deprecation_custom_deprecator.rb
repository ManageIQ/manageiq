# Fixed by https://github.com/rails/rails/pull/21953
raise "Delete this patch in #{__FILE__}" if Gem::Version.new(Rails.version) >= Gem::Version.new("5.0")

deprecate_methods_fix = Module.new do
  def deprecate_methods(target_module, *method_names)
    options = method_names.extract_options!
    options.reverse_merge!(:deprecator => self)
    super(target_module, *method_names.push(options))
  end
end
ActiveSupport::Deprecation.prepend(deprecate_methods_fix)
