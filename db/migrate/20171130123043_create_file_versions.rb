class CreateFileVersions < ActiveRecord::Migration
  def change
    create_table :file_versions do |t|
      t.string :sha256, null: false
      t.string :original_file_name, null: false
      t.integer :step_id, null: false
      t.integer :user_id, null: false
      t.timestamps null: false
    end
    add_attachment :file_versions, :file
    add_foreign_key :file_versions, :steps
    add_foreign_key :file_versions, :users
  end
end