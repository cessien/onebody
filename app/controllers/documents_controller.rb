class DocumentsController < ApplicationController
  before_action :find_parent_folder, only: %w(index show new)
  before_action :ensure_admin, except: %w(index show download)
  before_action :persist_prefs, only: %(index)

  def index
    if params[:network_folder]
      @network_folders = filesystem_items params[:network_folder]
      @hide_internal
    elsif params[:network_folder].nil? && (params[:folder_id].nil? || params[:folder_id] == 0)
      @network_folders = filesystem_items
    else
      @network_folders = []
    end
    @folders = (@parent_folder.try(:folders) || DocumentFolder.top).order(:name).includes(:groups)
    @folders = DocumentFolderAuthorizer.readable_by(@logged_in, @folders)
    if @logged_in.admin?(:manage_documents)
      @hidden_folder_count = @folders.hidden.count
      @restricted_folder_count = @folders.restricted.count('distinct document_folders.id')
    end
    @folders = @folders.open unless @show_restricted_folders
    @folders = @folders.active unless @show_hidden_folders
    @documents = (@parent_folder.try(:documents) || Document.top).order(:name)
    cookies[:document_view] = params[:view] if params[:view].present?
    @view = cookies[:document_view] || 'detail'
  end

  def show
    @document = Document.find(params[:id])
    fail ActiveRecord::RecordNotFound unless @logged_in.can_read?(@document)
  end

  def new
    if params[:folder]
      @folder = (@parent_folder.try(:folders) || DocumentFolder).new
      render action: 'new_folder'
    else
      @document = (@parent_folder.try(:documents) || Document).new
    end
  end

  def create
    if params[:folder]
      @folder = DocumentFolder.new(folder_params)
      if @folder.save
        redirect_to documents_path(folder_id: @folder), notice: t('documents.create_folder.notice')
      else
        render action: 'new_folder'
      end
    elsif params[:document][:file].kind_of?(Array)
      params[:document][:file].each_with_index do |file, index|
        @document = Document.new({
          :name => params[:document][:name][index],
          :description => params[:document][:description][index],
          :folder_id => params[:document][:folder_id],
          :file => file,
        })
        if !@document.save
          params[:multiple_documents] = true
          render action: 'new'
          return
        end
      end
      redirect_to documents_path(folder_id: params[:document][:folder_id] || 0), notice: t('documents.multiple_create.notice')
    else
      @document = Document.new(document_params)
      if @document.save
        redirect_to document_path(@document), notice: t('documents.create.notice')
      else
        render action: 'new'
      end
    end
  end

  def edit
    if params[:folder]
      @folder = DocumentFolder.find(params[:id])
      render action: 'edit_folder'
    else
      @document = Document.find(params[:id])
    end
  end

  def update
    if params[:folder]
      @folder = DocumentFolder.find(params[:id])
      if @folder.update_attributes(folder_params)
        redirect_to documents_path(folder_id: @folder.folder_id), notice: t('documents.update_folder.notice')
      else
        render action: 'edit_folder'
      end
    else
      @document = Document.find(params[:id])
      if @document.update_attributes(document_params)
        redirect_to documents_path(folder_id: @document.folder_id), notice: t('documents.update.notice')
      else
        render action: 'edit'
      end
    end
  end

  def destroy
    if params[:folder]
      @folder = DocumentFolder.find(params[:id])
      @folder.destroy
      redirect_to documents_path(folder_id: @folder.folder_id), notice: t('documents.delete_folder.notice')
    else
      @document = Document.find(params[:id])
      @document.destroy
      redirect_to documents_path(folder_id: @document.folder_id), notice: t('documents.delete.notice')
    end
  end

  def download
    @document = Document.find(params[:id])
    fail ActiveRecord::RecordNotFound unless @logged_in.can_read?(@document)
    send_file(
      @document.file.path,
      disposition: params[:inline] ? 'inline' : 'attachment',
      filename: @document.file_file_name,
      type: @document.file.content_type
    )
  end

  def filesystem_items(path=nil)
    files = Array.new()
    toplevelmounts = [{:name => 'M Drive', :path =>'/mnt/m_drive'},{:name => 'Test', :path => '/vagrant'}]
    if path.nil?
      toplevelmounts.each do |item|
	next if !Dir.exists? item[:path]
        files.concat([{
          :name => item[:name],
          :description => 'This is an externally-mapped folder. You will only be able to retrieve files.',
          :path => item[:path],  
	  :icon => 'fa fa-hdd-o',
          :updated_at => DateTime.now,
          :restricted => true,
          :item_count => Dir.entries(item[:path]).length - 2,
	  :folder => true,
        }])
      end
    else
      Dir.foreach(path) do |item|
        next if item == '.' or item == '..'
	fullpath = "#{path}/#{item}"
        file = File.new fullpath
        files.concat([{
          :name => item,
          :description => '',
          :path => fullpath,  
	  :icon => File.directory?(item) ? 'fa fa-folder-o':'fa fa-file',
          :updated_at => file.atime,
          :restricted => true,
          :item_count => File.directory?(item) ? Dir.entries(fullpath).length - 2: file.size,
	  :folder => File.directory?(item),
        }])
      end
    end
    return files
  end

  private

  def find_parent_folder
    return if params[:folder_id].blank?
    @parent_folder = DocumentFolder.find(params[:folder_id])
    return if @logged_in.admin?(:manage_documents)
    fail ActiveRecord::RecordNotFound if @parent_folder && !@logged_in.can_read?(@parent_folder)
  end

  def folder_params
    params.require(:folder).permit(:name, :description, :hidden, :folder_id, group_ids: [])
  end

  def document_params
    params.require(:document).permit(:name, :description, :folder_id, :file)
  end

  def feature_enabled?
    return if Setting.get(:features, :documents)
    redirect_to people_path
    false
  end

  def ensure_admin
    return if @logged_in.admin?(:manage_documents)
    render text: t('not_authorized'), layout: true
    false
  end

  def persist_prefs
    cookies[:restricted_folders] = params[:restricted_folders] if params[:restricted_folders].present?
    @show_restricted_folders = !@logged_in.admin?(:manage_documents) || cookies[:restricted_folders] == 'true'
    cookies[:hidden_folders] = params[:hidden_folders] if params[:hidden_folders].present?
    @show_hidden_folders = cookies[:hidden_folders] == 'true'
  end
end
