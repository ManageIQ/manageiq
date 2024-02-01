class YamlPermittedClasses
  DEFAULT_PERMITTED_CLASSES = [
    ActiveSupport::Duration,
    ActiveSupport::HashWithIndifferentAccess,
    ActiveSupport::TimeWithZone,
    ActiveSupport::TimeZone,
    Date,
    DateTime,
    Object,
    Range,
    Regexp,
    Symbol,
    Time
  ].freeze
  def self.app_yaml_permitted_classes
    @app_yaml_permitted_classes ||= DEFAULT_PERMITTED_CLASSES + [MiqExpression]
  end

  def self.app_yaml_permitted_classes=(classes)
    @app_yaml_permitted_classes = Array(classes)
  end

  def self.default_permitted_classes
    @default_permitted_classes ||= DEFAULT_PERMITTED_CLASSES
  end

  def self.permitted_classes
    initialized? ? app_yaml_permitted_classes : default_permitted_classes
  end

  def self.initialize_app_yaml_permitted_classes
    @initialize_app_yaml_permitted_classes ||= begin
      if ActiveRecord.respond_to?(:yaml_column_permitted_classes)
        ActiveRecord.yaml_column_permitted_classes       = YamlPermittedClasses.app_yaml_permitted_classes
      else
        ActiveRecord::Base.yaml_column_permitted_classes = YamlPermittedClasses.app_yaml_permitted_classes
      end
      true
    end
  end

  def self.initialized?
    !!@initialize_app_yaml_permitted_classes
  end
end
