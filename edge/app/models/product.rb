class Product < ApplicationRecord
  self.primary_key = "id"
  belongs_to :restaurant
  belongs_to :category
  has_many   :order_items

  validates :name,          presence: true
  validates :price,         presence: true, numericality: { greater_than: 0 }
  validates :restaurant_id, presence: true
  validates :category_id,   presence: true

  scope :available,   -> { where(available: true).order(:position, :name) }
  scope :by_category, ->(cat_id) { where(category_id: cat_id).available }
end
