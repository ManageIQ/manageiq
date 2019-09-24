class MiqWidget::ContentGeneration
  def initialize(options)
    raise _("Must call .new with an options hash.") unless options.kind_of?(Hash)

    options.each do |k, v|
      class_eval { attr_accessor k.to_sym }
      instance_variable_set("@#{k}", v)
    end

    self
  end

  def self.based_on_miq_report?
    true
  end
end
