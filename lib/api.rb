module Api
  def self.model_to_collection(klass)
    klass = klass.name if klass.kind_of?(Class)
    Api::Settings.collections.detect { |_name, cfg| cfg[:klass] == klass }.try(:first)
  end
end
