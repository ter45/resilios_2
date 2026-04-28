class Account < ApplicationRecord
  self.primary_key = "id"
  has_secure_password
  has_many :restaurants,   dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :edge_nodes,    through: :restaurants
  validates :name,   presence: true
  validates :email,  presence: true, uniqueness: true
  validates :plan,   inclusion: { in: %w[trial starter pro enterprise] }
  validates :status, inclusion: { in: %w[active suspended cancelled] }
end
