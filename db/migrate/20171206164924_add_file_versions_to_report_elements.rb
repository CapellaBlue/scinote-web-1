class AddFileVersionsToReportElements < ActiveRecord::Migration
  def change
    add_column :report_elements, :file_version_id, :integer
    add_foreign_key :report_elements, :file_versions
    add_index :report_elements, :file_version_id
  end
end