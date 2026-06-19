class Admin::PostsController < ApplicationController
  http_basic_authenticate_with name: "admin", password: ENV.fetch("ADMIN_PASSWORD", "aifinder2025")

  before_action :load_tools
  before_action :load_post, only: %i[edit update]

  def index
    @posts = Post.order(created_at: :desc)
  end

  def new
    @post = Post.new(post_type: "general")
  end

  def create
    @post = Post.new(post_params)
    @post.slug = @post.title.to_s.parameterize if @post.slug.blank?
    if @post.save
      redirect_to admin_posts_path, notice: "Post saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @post.update(post_params)
      redirect_to admin_posts_path, notice: "Updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def fetch_url
    render json: UrlFetcher.call(params[:url])
  end

  def fetch_news
    count = NewsAggregator.call
    redirect_to admin_posts_path, notice: "#{count} new post(s) imported from RSS feeds."
  end

  private

  def load_tools = @tools = Tool.order(:name)
  def load_post  = @post  = Post.find(params[:id])

  def post_params
    params.require(:post).permit(
      :title, :slug, :excerpt, :body,
      :source_name, :source_url, :image_url,
      :published_at, :post_type, :verdict, :tool_id
    )
  end
end
