require 'digest'

class FileUpload < ActiveRecord::Base
  include SearchableModel
  validates :file_uuid, presence: true, uniqueness: true
  validates :file_name, presence: true
  validates :sha256, presence: true, uniqueness: true, length: {is: 64}

  belongs_to :project, inverse_of: :file_uploads
  belongs_to :experiment, inverse_of: :file_uploads
  belongs_to :user, inverse_of: :file_uploads

  def create(path, file_uuid, file_name, project_id, experiment_id, user_id)
    self.sha256 = Digest::SHA256.hexdigest File.read path unless path.nil?
    self.file_name = file_name unless file_name.nil?
    self.project_id = project_id unless project_id.nil?
    self.file_uuid = file_uuid unless file_uuid.nil? && Uuid.validate(file_uuid).false?
    self.experiment_id = experiment_id unless experiment_id.nil?
    self.user_id = user_id unless user_id.nil?

    FileUpload.transaction do
      save! unless self.file_uuid.nil?|| self.file_name.nil? || self.project_id.nil? || self.experiment_id.nil? || self.user_id.nil?
    end
  end
end