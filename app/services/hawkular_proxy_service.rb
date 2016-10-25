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
    when 'get_last'
      { :id        => @params['metric_id'],
        :last_data => get_last(@params['metric_id']) }
    else
      {}
    end
  rescue StandardError => e
    { :error => e }
  end

  def metric_definitions
    tags = @params['tags'].blank? ? nil : JSON.parse(@params['tags'])
    tags = nil if tags.empty?
    client.gauges.query(tags).compact.map { |m| m.json if m.json }.sort { |a, b| a["id"].downcase <=> b["id"].downcase }
  end

  def metric_tags
    metric_definitions.map { |x| x["tags"].keys if x["tags"] }.compact.flatten.uniq.sort
  end

  def get_data(id)
    ends = @params['ends'] || nil
    starts = @params['starts'] || nil
    bucket_duration = @params['bucket_duration'] || nil

    client.gauges.get_data(id,
                           :limit          => @params['limit'] || 100,
                           :starts         => starts.to_i,
                           :ends           => ends.to_i,
                           :bucketDuration => bucket_duration,
                           :order          => 'ASC')
  end

  def get_last(id)
    client.gauges.get_data(id,
                           :limit => 1,
                           :order => 'DESC').first
  end
end
