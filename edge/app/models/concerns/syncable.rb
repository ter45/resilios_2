module Syncable
  extend ActiveSupport::Concern

  included do
    after_create  :enqueue_sync_create
    after_update  :enqueue_sync_update
    after_destroy :enqueue_sync_delete
  end

  def synced?
    respond_to?(:synced_at) && synced_at.present?
  end

  private

  def enqueue_sync_create
    enqueue_operation("create")
  end

  def enqueue_sync_update
    return if only_sync_fields_changed?
    enqueue_operation("update")
  end

  def enqueue_sync_delete
    enqueue_operation("delete")
  end

  def enqueue_operation(operation_type)
    SyncOperation.create!(
      restaurant_id:  restaurant_id_for_sync,
      operation_type: operation_type,
      entity_type:    self.class.name,
      entity_id:      id,
      payload:        build_sync_payload(operation_type),
      status:         "pending"
    )
  rescue => e
    Rails.logger.error "[Syncable] CRITICO: #{e.message}"
    raise ActiveRecord::Rollback, "SyncOperation creation failed: #{e.message}"
  end

  def build_sync_payload(operation_type)
    if operation_type == "delete"
      { id: id, deleted_at: Time.current.iso8601(3) }.to_json
    else
      as_sync_json.to_json
    end
  end

  def as_sync_json
    as_json
  end

  def only_sync_fields_changed?
    sync_fields = %w[sync_status synced_at updated_at]
    (saved_changes.keys - sync_fields).empty?
  end

  def restaurant_id_for_sync
    respond_to?(:restaurant_id) ? restaurant_id : nil
  end
end
