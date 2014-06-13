module MiqWidget::ImportExport
  extend ActiveSupport::Concern

  module ClassMethods
    def import_from_hash(widget, options={})
      raise "No Widget to Import" if widget.nil?
      rep = widget.delete("MiqReportContent") { raise "No report for Widget: #{widget.inspect}" }

      log_header = "MIQ(#{self.name}.#{__method__})"
      status = { :class => self.name, :description => widget["description"], :children => [] }

      report, status[:children] = MiqReport.import_from_hash(rep.first, options)

      if status[:children][:level] == "error"
        status[:status] = :error
        $log.error("#{log_header} Importing widget: [#{widget["description"]}] - Aborted. Status: #{status[:children][:message]}")
        return nil, status
      end

      w = MiqWidget.where(:guid => widget["guid"]).first
      if w.nil?
        w = MiqWidget.new(widget)
        status.merge!(:status => :add, :message => "Imported Widget: [#{widget["description"]}]")
        msg = "Importing widget: [#{widget["description"]}]"
      elsif options[:overwrite]
        status[:old_description] = w.description
        w.attributes = widget
        status.merge!(:status => :update, :message => "Replaced Widget: [#{widget["description"]}]")
        msg = "Overwriting widget: [#{widget["description"]}]"
      else
        status.merge!(:status => :keep, :message => "Skipping Widget (already in DB): [#{widget["description"]}]")
        msg = "Skipping widget (already in DB): [#{widget["description"]}]"
      end

      unless w.valid?
        status[:status]  = :conflict
        status[:messages] << w.errors.full_messages
      end

      msg = "#{log_header} #{msg}"
      msg << ", Messages: #{status[:messages].join(",")}" if status[:messages]
      $log.info(msg)

      if options[:save]
        w.resource = report
        w.save!
        $log.info("#{log_header} - Completed.")
      end

      return w, status
    end
  end

  def export_to_array
    h = self.attributes
    ["id", "created_at", "updated_at"].each { |k| h.delete(k) }
    h["MiqReportContent"] = self.resource.export_to_array
    [self.class.to_s => h]
  end
end
