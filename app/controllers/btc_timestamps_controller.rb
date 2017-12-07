class BtcTimestampsController < ApplicationController

  before_action :load_vars_nested, only: :index
  before_action :load_vars, only: :download
  before_action :check_view_permissions, only: :index

  layout 'fluid'

  # Index showing all reports of a single project
  def index
  end

  def download
    if !@report_version
      render_404 and return
    elsif @report_version.report.is_stored_on_s3?
      redirect_to @report_version.presigned_url(download: true), status: 307
    else
      send_file @report_version.report.path, filename: URI.unescape(@report_version.report_file_name + '.pdf'),
                type: @report_version.report_content_type
    end
  end

  def load_vars_nested
    @project = Project.find_by_id(params[:project_id])
    render_404 unless @project
  end

  def load_vars
    @report_version = BtcTimestamp.find_by_id(params[:id])
    render_404 unless @report_version
  end

  def check_view_permissions
    render_403 unless can_view_timestamped_reports(@project)
  end

end
