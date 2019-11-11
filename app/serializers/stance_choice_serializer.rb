class StanceChoiceSerializer < ActiveModel::Serializer
  embed :ids, include: true

  attributes :id, :score, :created_at, :stance_id, :rank, :rank_or_score

  has_one :poll_option
end
