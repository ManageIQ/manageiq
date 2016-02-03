require 'aws-sdk'

def with_aws_stubbed(stub_responses_per_service)
  stub_responses_per_service.each do |service, stub_responses|
    raise "Aws.config[#{service}][:stub_responses] already set" if Aws.config.fetch(service, {})[:stub_responses]
    Aws.config[service] ||= {}
    Aws.config[service][:stub_responses] = stub_responses
  end
  yield
ensure
  stub_responses_per_service.keys.each do |service|
    Aws.config[service].delete(:stub_responses)
  end
end
