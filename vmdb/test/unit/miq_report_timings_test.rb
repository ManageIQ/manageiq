require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))

class MiqReportTimingsTest < ActiveSupport::TestCase
  $skip_test = true
  ActiveRecord::Base.establish_connection(:adapter => "postgresql", :host => "localhost", :username => "root", :password => "smartvm", :database => "rod_4003_demo_3") unless $skip_test

  def test_it
    return if $skip_test
    errored = false
    fd = File.open("#{Rails.root}/miq_report_timings.csv", "w")
    fd.puts '"id","name","duration"'
    MiqReport.all(:conditions=>{:template_type => "report"}, :order => "id").each do |r|
      t0 = Time.now
      puts "#{r.id} => #{r.name}..."
      begin
        r.generate_table
        r.build_html_rows
      rescue => err
        errored = true
        puts "ERROR: #{err}"
      end
      t = Time.now - t0
      puts "#{r.id} => #{r.name}... Completed in #{t} seconds"
      fd.puts "#{r.id},\"#{r.name}\",#{t}"
    end
    fd.close

    flunk if errored
  end
end
