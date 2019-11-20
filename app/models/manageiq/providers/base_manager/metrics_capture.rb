class ManageIQ::Providers::BaseManager::MetricsCapture
  include Vmdb::Logging

  attr_reader :target, :ems
  def initialize(target, ems = nil)
    @target = target
    @ems = ems
  end

  def zone
    ems.zone
  end

  def my_zone
    ems.zone.name
  end
end
