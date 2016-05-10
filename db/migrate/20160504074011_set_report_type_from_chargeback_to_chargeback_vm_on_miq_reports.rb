class SetReportTypeFromChargebackToChargebackVmOnMiqReports < ActiveRecord::Migration[5.0]
  CHARGEBACK_REPORT_DB_MODEL = "Chargeback".freeze # old
  CHARGEBACK_VM_REPORT_DB_MODEL = "ChargebackVm".freeze # new

  class MiqReport < ActiveRecord::Base
    serialize :db_options
  end

  def up
    say_with_time('Set Chargeback to ChargebackVm on MiqReports for db column rtp_type in db_options') do
      MiqReport.where(:db => CHARGEBACK_REPORT_DB_MODEL).all.each do |miq_report|
        miq_report.db_options[:rpt_type] = miq_report.db = CHARGEBACK_VM_REPORT_DB_MODEL
        miq_report.save!
      end
    end
  end

  def down
    say_with_time('Set ChargebackVm back to Chargeback on MiqReports for db column in db_options') do
      MiqReport.where(:db => CHARGEBACK_VM_REPORT_DB_MODEL).all.each do |miq_report|
        miq_report.db_options[:rpt_type] = CHARGEBACK_REPORT_DB_MODEL.downcase
        miq_report.db = CHARGEBACK_REPORT_DB_MODEL
        miq_report.save!
      end
    end
  end
end
