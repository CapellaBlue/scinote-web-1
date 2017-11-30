require 'digest'

class BtcTimestamp < ActiveRecord::Base
  include SearchableModel
  validates :file_uuid, presence: true, uniqueness: true
  validates :sha256, presence: true, uniqueness: true, length: {is: 64}

  belongs_to :project, inverse_of: :btc_timestamps
  belongs_to :user, inverse_of: :btc_timestamps

  def create(path, project_id, file_uuid, user_id)
    self.sha256 = Digest::SHA256.hexdigest File.read path unless path.nil?
    self.project_id = project_id unless project_id.nil?
    self.file_uuid = file_uuid unless file_uuid.nil? && Uuid.validate(file_uuid).false?
    self.user_id = user_id unless user_id.nil?

    BtcTimestamp.transaction do
      save! unless self.sha256.nil? || self.project_id.nil? || self.file_uuid.nil? || self.user_id.nil?
    end
  end
end