class MigrateManagementSystemsReportsToProviders < ActiveRecord::Migration
  def up
    MiqReport.where(:rpt_group => "Configuration Management - Management Systems").each do |rpt|
      name  = rpt.name.gsub(/Management Systems/, 'Providers')
      title = rpt.title.gsub(/Management Systems/, 'Providers')
      group = rpt.rpt_group.gsub(/Management Systems/, 'Providers')
      filename = rpt.filename.gsub(/Management Systems/, 'Providers')
      headers  = rpt.headers.collect { |h| h.gsub(/Management System/, 'Provider') }
      rpt.update_attributes(:name => name, :title => title, :rpt_group => group, :filename => filename, :headers => headers)
    end
  end

  def down
    MiqReport.where(:rpt_group => "Configuration Management - Providers").each do |rpt|
      name  = rpt.name.gsub(/Providers/, 'Management Systems')
      title = rpt.title.gsub(/Providers/, 'Management Systems')
      group = rpt.rpt_group.gsub(/Providers/, 'Management Systems')
      filename = rpt.filename.gsub(/Providers/, 'Management Systems')
      headers  = rpt.headers.collect { |h| h.gsub(/Provider/, 'Management System') }
      rpt.update_attributes(:name => name, :title => title, :rpt_group => group, :filename => filename, :headers => headers)
    end
  end
end
