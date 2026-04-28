class Restaurant < ApplicationRecord
  self.primary_key = "id"
  belongs_to :account
  has_many :edge_nodes, dependent: :destroy
  has_many :orders,     dependent: :destroy
  validates :name, presence: true
end
