class EnableExtensions < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'pgcrypto'
    enable_extension 'pg_trgm'
  end
end
