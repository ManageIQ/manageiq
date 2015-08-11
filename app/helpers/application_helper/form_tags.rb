module ApplicationHelper
  module FormTags
    def datepicker_input_tag(name, value = nil, options = {})
      datepicker_options = {
        "data-provide"         => "datepicker",
        "data-date-autoclose"  => "true",
        "data-date-format"     => "mm/dd/yyyy",
        "data-date-language"   => FastGettext.locale,
        "data-date-week-start" => 0
      }
      text_field_tag(name, value, options.merge!(datepicker_options))
    end
  end
end
