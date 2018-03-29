namespace :dialogs do
  desc "Imports dialogs from a yml file"
  task :import, [:filename] => [:environment] do |_, arguments|
    warn('dialogs:import is deprecated. Use evm:import:service_dialogs.')
    TaskHelpers::DialogImportHelper.new.import(arguments[:filename])
  end

  desc "Exports all dialogs to a yml file"
  task :export, [:filename] => [:environment] do |_, arguments|
    warn('dialogs:export is deprecated. Use evm:export:service_dialogs.')
    timestamp = format_timezone(Time.current, Time.zone, "export_filename")
    filename = arguments[:filename] || "dialog_export_#{timestamp}.yml"
    TaskHelpers::DialogExporter.new.export(filename)
  end
end
