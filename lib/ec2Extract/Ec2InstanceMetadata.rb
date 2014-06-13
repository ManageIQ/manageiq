require 'httpclient'

class Ec2InstanceMetadata
	
	def initialize(version='latest')
		@baseUrl		= 'http://169.254.169.254/'
		@version		= version
		@url			= "#{@baseUrl}#{@version}/"
		@metadataUrl	= "#{@url}meta-data/"
		@httpClient		= HTTPClient.new
	end
	
	def version=(val)
		@version = val
		@url = "#{@baseUrl}#{@version}/"
		@metadataUrl = "#{@url}meta-data/"
		return val
	end
	
	def versions
		do_get(@baseUrl, "versions").split("\n")
	end
	
	def metadata(path)
		rv = do_get(@metadataUrl + path, "metadata")
		return rv.split("\n") if rv.include?("\n")
		return rv
	end
	
	def user_data
		do_get(@url + "user-data", "user_data")
	end
	
	private
	
	def do_get(url, method)
		rv = @httpClient.get(url)
		raise "#{self.class.name}.#{method}: #{url} #{rv.reason} (#{rv.status})" if rv.status != 200
		return rv.content
	end
	
end
