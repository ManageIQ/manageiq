module VmHelper
  include_concern 'TextualSummary'
  include_concern 'GraphicalSummary'

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
    url = request.parameters[:controller]
    action = "x_show"
    return url, action
  end

  def textual_cloud_network
    return nil unless @record.kind_of?(VmAmazon)
    {:label => "Virtual Private Cloud", :value => @record.cloud_network ? @record.cloud_network.name : 'None'}
  end

  def textual_cloud_subnet
    return nil unless @record.kind_of?(VmAmazon)
    {:label => "Cloud Subnet", :value => @record.cloud_subnet ? @record.cloud_subnet.name : 'None'}
  end
end
