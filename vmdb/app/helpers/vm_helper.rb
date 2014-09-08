module VmHelper
  include_summary_presenter(VmTextualSummaryPresenter)
  include_summary_presenter(VmGraphicalSummaryPresenter)

  # TODO: These methods can be removed once the Summary and ListNav data layer is consolidated.
  def last_date(request_type)
    @last_date ||= {}
    return @last_date[request_type] if @last_date.has_key?(request_type)
    @last_date[request_type] = self.send("last_date_#{request_type}")
  end

  def last_date_processes
    return nil if @record.operating_system.nil?
    p = @record.operating_system.processes.first(:select=>"updated_on", :order => "updated_on DESC")
    return p.nil? ? nil : p.updated_on
  end

  def set_controller_action
    parent = @record.with_relationship_type("genealogy") { |r| r.parent }
    url = parent.vdi ? "vm_vdi" : request.parameters[:controller]
    action = parent.vdi ? "show" : "x_show"
    return url, action
  end
end
