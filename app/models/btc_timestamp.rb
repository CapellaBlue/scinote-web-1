require 'digest'

class BtcTimestamp < ActiveRecord::Base
  include SearchableModel

  has_attached_file :report, path: ':rails_root/report_versions'
  validates_attachment :report,
                       presence: true,
                       size: {
                           less_than: Constants::FILE_MAX_SIZE_MB.megabytes
                       }
  validates_attachment_content_type :report, content_type: ['application/pdf']
  validates :file_uuid, presence: true, uniqueness: true
  validates :sha256, presence: true, uniqueness: true, length: { is: 64 }

  belongs_to :project, inverse_of: :btc_timestamps
  belongs_to :user, inverse_of: :btc_timestamps

  def create(file, file_content, file_size, file_uuid, project_id, user_id)
    self.report = file
    self.sha256 = Digest::SHA256.hexdigest file_content.to_s
    self.project_id = project_id
    self.file_uuid = file_uuid
    self.user_id = user_id

    self.report_file_name = self.file_uuid
    self.report_content_type = Rack::Mime.mime_type('.pdf')
    self.report_file_size = file_size

    BtcTimestamp.transaction do
      begin
        save!
      rescue
        nil
      end
    end
  end
end