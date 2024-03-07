module MiqWidgetSet::SetData
  extend ActiveSupport::Concern

  SET_DATA_COLS = %i[col1 col2].freeze

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

    def has_widget_id_member?(widget_id)
      widget_ids.include?(widget_id)
    end

    private

    def init_set_data
      old_set_data = set_data.to_h.symbolize_keys
      new_set_data = {}

      SET_DATA_COLS.each do |col_key|
        new_set_data[col_key] = old_set_data[col_key] || []
      end

      new_set_data[:reset_upon_login] = !!old_set_data[:reset_upon_login]
      new_set_data[:locked] = !!old_set_data[:locked]
      self.set_data = new_set_data
    end

    def widget_ids
      SET_DATA_COLS.flat_map { |x| set_data[x] }.compact
    end
  end
end
