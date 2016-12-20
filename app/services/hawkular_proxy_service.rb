class HawkularProxyService
  include UiServiceMixin

  def initialize(provider_id, controller)
    @provider_id = provider_id
    @controller = controller

    @params = controller.params
    @ems = ManageIQ::Providers::ContainerManager.find(@provider_id) unless @provider_id.blank?
    @tenant = @params['tenant'] || '_system'
  end

  def client
    ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClient.new(@ems, @tenant)
  end

  def data(query)
    case query
    when 'metric_definitions'
      { :metric_definitions => metric_definitions }
    when 'metric_tags'
      { :metric_tags => metric_tags }
    when 'get_data'
      { :id   => @params['metric_id'],
        :data => get_data(@params['metric_id']).compact }
    when 'get_tenants'
      { :tenants => tenants }
    else
      {}
    end
  rescue StandardError => e
    { :error => e }
  end

  def metric_definitions
    tags = @params['tags'].blank? ? nil : JSON.parse(@params['tags'])
    tags = nil if tags == {}
    client.gauges.query(tags).compact.map { |m| m.json if m.json }.sort { |a, b| a["id"].downcase <=> b["id"].downcase }
  end

  def metric_tags
    metric_definitions.map { |x| x["tags"].keys if x["tags"] }.compact.flatten.uniq.sort
  end

  def get_data(id)
    ends = @params['ends'] || (DateTime.now.to_i * 1000)
    starts = @params['starts'] || (ends - 8 * 60 * 60 * 1000)
    bucket_duration = @params['bucket_duration'] || nil
    order = @params['order'] || 'ASC'

    client.gauges.get_data(id,
                           :limit          => @params['limit'] || 100,
                           :starts         => starts.to_i,
                           :ends           => ends.to_i,
                           :bucketDuration => bucket_duration,
                           :order          => order)
  end

  def tenants
    tenants = client.hawkular_client.http_get('/tenants')
    tenants = if @params['include'].blank?
                tenants.map { |x| x["id"] }.compact
              else
                tenants.map { |x| x["id"] if x["id"].include?(@params['include']) }.compact
              end

    limit = @params['limit'].to_i || 7
    tenants[0..limit]
  end
end
