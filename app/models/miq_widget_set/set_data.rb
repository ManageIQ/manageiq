module MiqWidgetSet::SetData
  extend ActiveSupport::Concern

  SET_DATA_COLS = %i[col1 col2 col3].freeze

  included do
    validate :set_data do
      errors.add(:set_data, "One widget must be selected(set_data)") if widget_ids.empty?

      filtered_widget_ids = set_data_widgets.pluck(:id)
      if (widget_ids - filtered_widget_ids).present?
        errors.add(:set_data, "Unable to find widget ids: #{(widget_ids - filtered_widget_ids).join(', ')}")
      end
    end

    before_validation :init_set_data

    def set_data_widgets
      MiqWidget.where(:id => widget_ids)
    end

    private

    def init_set_data
      self.set_data ||= {}
      new_set_data ||= {}
      self.set_data.symbolize_keys!
      SET_DATA_COLS.each do |col_key|
        new_set_data[col_key] = self.set_data[col_key] || []
      end

      new_set_data[:reset_upon_login] = !!set_data[:reset_upon_login]
      new_set_data[:locked] = !!set_data[:locked]
      self.set_data = new_set_data
    end

    def widget_ids
      SET_DATA_COLS.flat_map { |x| set_data[x] }.compact
    end
  end
end
