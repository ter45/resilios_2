class SyncOperation < ApplicationRecord
  self.primary_key = "id"

  STATUSES        = %w[pending processing synced failed].freeze
  OPERATION_TYPES = %w[create update delete].freeze
  ENTITY_TYPES    = %w[Order OrderItem Product Category Table].freeze
  MAX_RETRIES     = 5

  validates :restaurant_id,  presence: true
  validates :operation_type, presence: true, inclusion: { in: OPERATION_TYPES }
  validates :entity_type,    presence: true, inclusion: { in: ENTITY_TYPES }
  validates :entity_id,      presence: true
  validates :payload,        presence: true
  validates :status,         inclusion: { in: STATUSES }

  scope :pending,   -> { where(status: "pending").order(:created_at) }
  scope :failed,    -> { where(status: "failed") }
  scope :for_batch, ->(size) { pending.limit(size) }

  before_update :protect_immutable_fields

  def to_api_payload
    {
      id:             id,
      operation_type: operation_type,
      entity_type:    entity_type,
      entity_id:      entity_id,
      created_at:     created_at.iso8601(3),
      payload:        JSON.parse(payload)
    }
  end

  def mark_synced!
    update!(status: "synced", synced_at: Time.current)
  end

  def mark_failed!(error_message)
    update!(
      status:      retry_count < MAX_RETRIES ? "pending" : "failed",
      retry_count: retry_count + 1,
      last_error:  error_message
    )
  end

  def self.pending_count
    where(status: "pending").count
  end

  def self.oldest_pending_at
    where(status: "pending").minimum(:created_at)
  end

  def self.max_lag_seconds
    oldest = oldest_pending_at
    return 0 unless oldest
    (Time.current - oldest).to_i
  end

  private

  def protect_immutable_fields
    immutable = %w[operation_type entity_type entity_id payload]
    changed_immutable = (changed & immutable)
    if changed_immutable.any?
      errors.add(:base, "Cannot modify immutable fields: #{changed_immutable.join(', ')}")
      throw :abort
    end
  end
end
