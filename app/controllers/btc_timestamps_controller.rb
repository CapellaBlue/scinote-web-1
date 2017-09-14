UPLOAD_DIR = 'timestamps'.freeze

class BtcTimestampsController < ApplicationController

  before_action :load_vars_nested

  before_action :check_view_permissions, only: :index

  before_action :check_destroy_permissions, only: :destroy

  layout 'fluid'

  # Index showing all reports of a single project
  def index
  end

  def download
    file_uuid = params[:uuid]
    file_ext = '.pdf'
    send_file(
        UPLOAD_DIR + '/' + file_uuid + file_ext,
        type: 'application/pdf'
    )
  end

  def destroy
      begin
        btc_timestamp_ids = JSON.parse(params[:report_ids])
      rescue
        render_404
      end
      btc_timestamp_ids.each do |timestamp_id|
        timestamp = BtcTimestamp.find_by_id(timestamp_id)
        next unless timestamp.present?
        # delete saved PDF
        file_uuid = timestamp.file_uuid
        file_ext = '.pdf'
        path = UPLOAD_DIR + '/' + file_uuid + file_ext
        File.delete(path) if File.exist?(path)
        # destroy DB record
        timestamp.destroy
        # record an activity
        Activity.create(
            type_of: :delete_btc_timestamp,
            project: timestamp.project,
            user: current_user,
            message: I18n.t(
                'activities.delete_btc_timestamp',
                user: current_user.full_name,
                btc_timestamp: timestamp.sha256
            )
        )
      end
      redirect_to project_btc_timestamps_path(@project)
  end

  def load_vars_nested
    @project = Project.find_by_id(params[:project_id])
    render_404 unless @project
  end

  def check_view_permissions
    render_403 unless can_view_btc_timestamps(@project)
  end

  def check_destroy_permissions
    render_403 unless can_delete_btc_timestamps(@project)
  end

end
