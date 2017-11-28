UPLOAD_DIR = 'timestamps'.freeze

class BtcTimestampsController < ApplicationController

  before_action :load_vars_nested

  before_action :check_view_permissions, only: :index

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

  def load_vars_nested
    @project = Project.find_by_id(params[:project_id])
    render_404 unless @project
  end

  def check_view_permissions
    render_403 unless can_view_timestamped_reports(@project)
  end

end
