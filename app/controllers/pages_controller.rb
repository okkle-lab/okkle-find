class PagesController < ApplicationController
  def home
    @categories = Category.ordered

    @stats = {
      tools: Tool.visible.count,
      models: ModelVariant.count,
      categories: Rubric.categories.size
    }

    @top_rated = Tool.visible.includes(:model_variants).to_a
      .filter_map { |t| (result = t.broad_overall_result) && [t, result] }
      .sort_by { |_t, result| -result.score }
      .first(5)

    @recent_posts =
      if FeatureFlags.latest_in_ai?
        Post.published.recent.limit(3)
      else
        Post.none
      end
  end

  def methodology
    @categories = Rubric.categories
  end

  def learn
    @topics = LearnTopic.all
  end

  def learn_topic
    @slug = params[:slug]
    @topic = LearnTopic.find(@slug)
    redirect_to(learn_path) if @topic.nil?
  end
end
