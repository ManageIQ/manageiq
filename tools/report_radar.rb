OUTPUT_CSV_FILE_PATH = 'cores_usage_per_label.csv'.freeze

HEADERS_AND_COLUMNS = ['Hour', 'Date', 'Label of image (key : value)', 'Project', 'Used Cores'].freeze

CSV.open(OUTPUT_CSV_FILE_PATH, "wb") do |csv|
  csv << HEADERS_AND_COLUMNS
  MetricRollup.where(:resource_type => 'CustomAttribute').order(:timestamp).select(:timestamp, :resource_name, :cpu_usage_rate_average, :resource_id, :resource_type).each do |mr|
    date         = mr.timestamp.to_date
    hour         = mr.timestamp.hour
    project_name = mr.resource_name
    label_name   = "#{mr.resource.name}:#{mr.resource.value}"
    csv << [hour, date, label_name, project_name, mr.cpu_usage_rate_average]
  end
end
