class FileVersionsController < ApplicationController

  before_action :load_vars
  before_action :check_view_permissions, only: :index

  layout 'fluid'

  def index
  end

  def download
    if !@file_version
      render_404 and return
    elsif @file_version.file.is_stored_on_s3?
      redirect_to @file_version.presigned_url(download: true), status: 307
    else
      send_file @file_version.file.path, filename: URI.unescape(@file_version.file_file_name),
                type: @file_version.file_content_type
    end
  end

  def load_vars
    @file_version = FileVersion.find_by_id(params[:id])
    render_404 unless @file_version
  end

  def check_view_permissions
  end
end