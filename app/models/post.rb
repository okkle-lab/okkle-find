class Post < ApplicationRecord
  enum :post_type, {
    general:          "general",
    practical_update: "practical_update",
    hype_check:       "hype_check",
    score_update:     "score_update",
    roundup:          "roundup"
  }, default: "general"

  belongs_to :tool, optional: true

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true

  scope :published, -> { where.not(published_at: nil).where("published_at <= ?", Time.current) }
  scope :recent,    -> { order(published_at: :desc) }

  def to_param = slug

  POST_TYPE_LABELS = {
    "general"          => "News",
    "practical_update" => "Update",
    "hype_check"       => "Hype check",
    "score_update"     => "Score update",
    "roundup"          => "Weekly roundup"
  }.freeze

  def type_label = POST_TYPE_LABELS.fetch(post_type, "News")
end
