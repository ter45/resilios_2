class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions, id: false do |t|
      t.string   :id,                     null: false
      t.string   :account_id,             null: false
      t.string   :stripe_subscription_id, null: false
      t.string   :plan,                   null: false
      t.string   :status,                 null: false
      t.integer  :orders_per_month_limit, default: 500
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :cancelled_at
      t.timestamps
    end
    add_index :subscriptions, :id,                     unique: true
    add_index :subscriptions, :account_id
    add_index :subscriptions, :stripe_subscription_id, unique: true
    add_index :subscriptions, :status
  end
end
