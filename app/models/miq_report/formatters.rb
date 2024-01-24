module MiqReport::Formatters
  extend ActiveSupport::Concern

  include Csv
  include Graph
  include Html
  include Text
  include Timeline
end
