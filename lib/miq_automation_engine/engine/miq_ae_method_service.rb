module MiqAeMethodService
end

Dir.glob(Pathname.new(__dir__).join("miq_ae_method_service/*.rb")) do |file|
  require_relative "miq_ae_method_service/#{File.basename(file)}"
end
