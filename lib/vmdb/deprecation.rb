Vmdb::Deprecation ||= begin
  deprecator = ActiveSupport::Deprecation.new("D-release", "ManageIQ")
  deprecator.behavior = [:stderr, :log]
  deprecator
end
