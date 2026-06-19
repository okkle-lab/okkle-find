class PagesController < ApplicationController
  def home
    @categories = Category.ordered

    @stats = {
      tools: Tool.visible.count,
      models: ModelVariant.count,
      categories: Rubric::CATEGORIES.size
    }

    tools = Tool.visible.includes(:model_variants).to_a
    @top_rated = tools
      .filter_map { |t| [t, t.overall_verdict] if t.overall_verdict }
      .sort_by { |_t, v| -v }
      .first(5)
  end

  def methodology
    @categories = Rubric::CATEGORIES
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
