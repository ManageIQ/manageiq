module MiqReport::Formatters
  extend ActiveSupport::Concern

  include_concern 'Csv'
  include_concern 'Graph'
  include_concern 'Html'
  include_concern 'Text'
  include_concern 'Timeline'
end
