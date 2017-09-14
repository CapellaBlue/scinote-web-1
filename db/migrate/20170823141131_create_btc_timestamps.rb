class CreateBtcTimestamps < ActiveRecord::Migration
  def change
    create_table :btc_timestamps do |t|
      t.string :sha256, null: false
      t.string :file_uuid, null: false
      t.integer :project_id, null: false
      t.integer :user_id, null: false
      t.timestamps null: false
    end
    add_foreign_key :btc_timestamps, :projects
    add_index :btc_timestamps, :project_id
    add_foreign_key :btc_timestamps, :users
    add_index :btc_timestamps, :user_id
  end
end