class HostStorage < ApplicationRecord
  belongs_to :host
  belongs_to :storage

  scope :writable, -> { where(:read_only => [nil, false]) }
  scope :read_only, -> { where(:read_only => true) }

  scope :accessible, -> { where(:accessible => [true, nil]) }
  scope :inaccessible, -> { where(:accessible => false) }

  class << self
    def writable_accessible
      writable.accessible.joins(:storage).merge(Storage.available)
    end
  end
end
