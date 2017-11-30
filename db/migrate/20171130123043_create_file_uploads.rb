class CreateFileUploads < ActiveRecord::Migration
  def change
    create_table :file_uploads do |t|
      t.string :sha256, null: false
      t.string :file_uuid, null: false
      t.string :file_name, null: false
      t.integer :project_id, null: false
      t.integer :experiment_id, null: false
      t.integer :user_id, null: false
      t.timestamp null: false
    end
    add_foreign_key :file_uploads, :projects
    add_index :file_uploads, :project_id
    add_foreign_key :file_uploads, :experiments
    add_index :file_uploads, :experiment_id
    add_foreign_key :file_uploads, :users
    add_index :file_uploads, :user_id
  end
end