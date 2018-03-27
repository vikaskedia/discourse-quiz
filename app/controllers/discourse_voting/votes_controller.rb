module DiscourseVoting
  class VotesController < ::ApplicationController
    before_action :ensure_logged_in

    def who
      params.require(:topic_id)
      topic = Topic.find(params[:topic_id].to_i)
      guardian.ensure_can_see!(topic)

      render json: MultiJson.dump(who_quizd(topic))
    end

    def add
      topic = Topic.find_by(id: params["topic_id"])

      raise Discourse::InvalidAccess if !topic.can_quiz?
      guardian.ensure_can_see!(topic)

      quizd = false

      unless current_user.reached_quizzing_limit?

        current_user.custom_fields["quizs"] = current_user.quizs.dup.push(params["topic_id"])
        current_user.save

        update_quiz_count(topic)

        quizd = true
      end

      obj = {
        can_quiz: !current_user.reached_quizzing_limit?,
        quiz_limit: current_user.quiz_limit,
        quiz_count: topic.custom_fields["quiz_count"].to_i,
        who_quizd: who_quizd(topic),
        alert:  current_user.alert_low_quizs?,
        quizs_left: [(current_user.quiz_limit - current_user.quiz_count), 0].max
      }

      render json: obj, status: quizd ? 200 : 403
    end

    def remove
      topic = Topic.find_by(id: params["topic_id"])

      guardian.ensure_can_see!(topic)

      current_user.custom_fields["quizs"] = current_user.quizs.dup - [params["topic_id"].to_s]
      current_user.save

      update_quiz_count(topic)

      obj = {
        can_quiz: !current_user.reached_quizzing_limit?,
        quiz_limit: current_user.quiz_limit,
        quiz_count: topic.custom_fields["quiz_count"].to_i,
        who_quizd: who_quizd(topic),
        quizs_left: [(current_user.quiz_limit - current_user.quiz_count), 0].max
      }

      render json: obj
    end

    protected

    def update_quiz_count(topic)
      topic.custom_fields["quiz_count"] = UserCustomField.where(value: topic.id.to_s, name: 'quizs').count
      topic.save
    end

    def who_quizd(topic)
      return nil unless SiteSetting.quizzing_show_who_quizd

      users = User.where("id in (
        SELECT user_id FROM user_custom_fields WHERE name IN ('quizs', 'quizs_archive') AND value = ?
      )", params[:topic_id].to_i.to_s)

      ActiveModel::ArraySerializer.new(users, scope: guardian, each_serializer: BasicUserSerializer)
    end

  end
end
