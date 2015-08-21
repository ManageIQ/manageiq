class ManageIQ::Providers::BaseManager::MetricsCapture
  include Vmdb::Logging

  attr_reader :target
  def initialize(target)
    @target = target
  end
end
