# TODO: Move this to config
OS_API_KEY = '2e13775d-4a1b-40b2-80d8-c9061de8bb39'.freeze
OS_BASE_URL = 'https://api.originstamp.org/api/'.freeze

class AssetsController < ApplicationController
  include WopiUtil
  # include ActionView::Helpers
  include ActionView::Helpers::AssetTagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Context
  include InputSanitizeHelper
  include FileIconsHelper
  include WopiHelper

  before_action :load_vars
  before_action :check_read_permission, except: :file_present
  before_action :load_vars, except: :signature
  before_action :check_read_permission, except: [:signature, :file_present]
  before_action :check_edit_permission, only: :edit

  after_action :save_file_version

  def send_hash_to_originstamp_job(sha256)
    # Send hash to OriginStamp
    Rails.logger.info "File version: #{sha256}: OriginStamp submission started."
    url = URI(OS_BASE_URL + sha256)

    req = Net::HTTP::Get.new(url.path)
    req['Authorization'] = OS_API_KEY

    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true
    res = https.request(req)
    Rails.logger.info "File version: #{sha256} was submitted to OriginStamp with code: #{res.code}."
  end

  def save_file_version
    # Save file versions of uploaded files in file_versions table together with file.
    if @asset.nil?
      return
    end
    if @asset.file.path.include? 'processing.gif'
      return
    end
    step_id = @asset.step.id
    user_id = @asset.created_by.id
    file_version_entry = FileVersion.new
    fetched_file = @asset.file.fetch
    file_content = fetched_file.read
    file_version_entry.create(@asset.file,
                              file_content,
                              step_id,
                              user_id,
                              @asset.file_file_name,
                              @asset.file_file_size)

    Rails.logger.info "Asset version: #{file_version_entry.sha256}: Creating submission job"
    delay(queue: send_hash_to_originstamp_job(file_version_entry.sha256))
  end

  # Validates asset and then generates S3 upload posts, because
  # otherwise untracked files could be uploaded to S3
  def signature
    respond_to do |format|
      format.json {
        asset = Asset.new(asset_params)
        if asset.valid?
          posts = generate_upload_posts asset
          render json: {
            posts: posts
          }
        else
          render json: {
            status: 'error',
            errors: asset.errors
          }, status: :bad_request
        end
      }
    end
  end

  def file_present
    respond_to do |format|
      format.json do
        if @asset.file.processing?
          render json: {}, status: 404
        else
          # Only if file is present,
          # check_read_permission
          check_read_permission

          # If check_read_permission already rendered error,
          # stop execution
          return if performed?

          # If check permission passes, return :ok
          render json: {
            'asset-id' => @asset.id,
            'image-tag-url' => @asset.url(:medium),
            'preview-url' => large_image_url_asset_path(@asset),
            'filename' => truncate(@asset.file_file_name,
                                   length:
                                     Constants::FILENAME_TRUNCATION_LENGTH),
            'download-url' => download_asset_path(@asset),
            'type' => asset_data_type(@asset),
            'wopi-file-name' => wopi_asset_file_name(@asset, true),
            'wopi-edit' => (wopi_asset_edit_button(@asset) if wopi_file?(@asset)),
            'wopi-view' => (wopi_asset_view_button(@asset) if wopi_file?(@asset))
          }, status: 200
        end
      end
    end
  end

  def large_image_url
    respond_to do |format|
      format.json do
        render json: {
          'large-preview-url' => @asset.url(:large),
          'filename' => truncate(@asset.file_file_name,
                                 length:
                                   Constants::FILENAME_TRUNCATION_LENGTH),
          'download-url' => download_asset_path(@asset),
          'type' => (@asset.is_image? ? 'image' : 'file')
        }
      end
    end
  end

  def download
    if !@asset.file_present
      render_404 and return
    elsif @asset.file.is_stored_on_s3?
      redirect_to @asset.presigned_url(download: true), status: 307
    else
      send_file @asset.file.path, filename: URI.unescape(@asset.file_file_name),
        type: @asset.file_content_type
    end
  end

  def edit
    @action_url = append_wd_params(@asset
                                   .get_action_url(current_user, 'edit', false))
    @favicon_url = @asset.favicon_url('edit')
    tkn = current_user.get_wopi_token
    @token = tkn.token
    @ttl = (tkn.ttl * 1000).to_s
    create_wopi_file_activity(current_user, true)

    render layout: false
  end

  def view
    @action_url = append_wd_params(@asset
                                   .get_action_url(current_user, 'view', false))
    @favicon_url = @asset.favicon_url('view')
    tkn = current_user.get_wopi_token
    @token = tkn.token
    @ttl = (tkn.ttl * 1000).to_s

    render layout: false
  end

  private

  def load_vars
    @asset = Asset.find_by_id(params[:id])
    render_404 unless @asset

    step_assoc = @asset.step
    result_assoc = @asset.result
    @assoc = step_assoc unless step_assoc.nil?
    @assoc = result_assoc unless result_assoc.nil?

    if @assoc.class == Step
      @protocol = @asset.step.protocol
    else
      @my_module = @assoc.my_module
    end
  end

  def check_read_permission
    if @assoc.class == Step
      unless can_view_or_download_step_assets(@protocol)
        render_403 and return
      end
    elsif @assoc.class == Result
      unless can_view_or_download_result_assets(@my_module)
        render_403 and return
      end
    end
  end

  def check_edit_permission
    if @assoc.class == Step
      unless can_edit_step_in_protocol(@protocol)
        render_403 and return
      end
    elsif @assoc.class == Result
      unless can_edit_result_asset_in_module(@my_module)
        render_403 and return
      end
    end
  end

  def generate_upload_posts(asset)
    posts = []
    s3_post = S3_BUCKET.presigned_post(
      key: asset.file.path[1..-1],
      success_action_status: '201',
      acl: 'private',
      storage_class: "STANDARD",
      content_length_range: 1..Constants::FILE_MAX_SIZE_MB.megabytes,
      content_type: asset.file_content_type
    )
    posts.push({
      url: s3_post.url,
      fields: s3_post.fields
    })

    condition = %r{^image/#{Regexp.union(Constants::WHITELISTED_IMAGE_TYPES)}}

    if condition === asset.file_content_type
      asset.file.options[:styles].each do |style, option|
        s3_post = S3_BUCKET.presigned_post(
          key: asset.file.path(style)[1..-1],
          success_action_status: '201',
          acl: 'public-read',
          storage_class: "REDUCED_REDUNDANCY",
          content_length_range: 1..Constants::FILE_MAX_SIZE_MB.megabytes,
          content_type: asset.file_content_type
        )
        posts.push({
          url: s3_post.url,
          fields: s3_post.fields,
          style_option: option,
          mime_type: asset.file_content_type
        })
      end
    end

    posts
  end

  def append_wd_params(url)
    wd_params = ''
    params.keys.select { |i| i[/^wd.*/] }.each do |wd|
      next if wd == 'wdPreviousSession' || wd == 'wdPreviousCorrelation'
      wd_params += "&#{wd}=#{params[wd]}"
    end
    url + wd_params
  end

  def asset_params
    params.permit(
      :file
    )
  end

  def asset_data_type(asset)
    return 'wopi' if wopi_file?(asset)
    return 'image' if asset.is_image?
    'file'
  end
end
