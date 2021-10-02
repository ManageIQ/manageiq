module MiqTemplate::Operations
  extend ActiveSupport::Concern

  included do
    supports     :clone
  end
end
