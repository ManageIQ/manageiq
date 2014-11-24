require 'yaml'

module VimMappingRegistry
	YML_DIR = File.join(File.dirname(__FILE__), "wsdl41", "methods")

	def self.registry
		@registry ||= Hash.new do |h, k|
			file = File.join(YML_DIR, "#{k}.yml")
			h[k] = File.exist?(file) ? YAML.load_file(file) : nil
		end
	end

	def self.argInfoMap(cType)
		registry[cType]
	end

	def self.args(cType)
		registry[cType] && registry[cType].keys
	end
end
