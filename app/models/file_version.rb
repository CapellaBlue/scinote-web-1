require 'digest'

class FileVersion < ActiveRecord::Base
  include SearchableModel
  has_attached_file :file, path: ":rails_root/file_versions"
  validates_attachment :file,
                       presence: true,
                       size: {
                           less_than: Constants::FILE_MAX_SIZE_MB.megabytes
                       }
  do_not_validate_attachment_file_type :file

  validates :sha256, presence: true, uniqueness: true, length: {is: 64}
  validates :original_file_name, presence: true
  validates :file_file_name, presence: true, uniqueness: true
  validates :file_content_type, presence: true
  validates :file_file_size, presence: true

  belongs_to :step, inverse_of: :file_versions
  belongs_to :user, inverse_of: :file_versions

  def create(file, file_content, step_id, user_id, file_name, file_size)
    self.file = file
    self.sha256 = Digest::SHA256.hexdigest file_content
    self.original_file_name = file_name
    self.step_id = step_id
    self.user_id = user_id

    file_ext = file_name.split(".").last
    self.file_file_name = self.sha256
    self.file_content_type = Rack::Mime.mime_type(".#{file_ext}")
    self.file_file_size = file_size

    FileVersion.transaction do
      begin
        save!
      rescue
        nil
      end
    end

  end
end