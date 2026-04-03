class Category < ApplicationRecord
  self.primary_key = "id"
  belongs_to :restaurant
  has_many   :products, dependent: :destroy

  validates :name,          presence: true
  validates :restaurant_id, presence: true

  scope :active,  -> { where(active: true).order(:position) }
  scope :ordered, -> { order(:position, :name) }

  def active_products
    products.where(available: true).order(:position, :name)
  end
end
