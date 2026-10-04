class ChatSession < ApplicationRecord
  serialize :data, coder: JSON

  validates :key, presence: true, uniqueness: true

  after_initialize do
    self.data ||= {}
  end
end
