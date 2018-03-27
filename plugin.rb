# name: discourse-quizzing
# about: Adds the ability to quiz on features in a specified category.
# version: 0.4
# author: Joe Buhlig joebuhlig.com, Sam Saffron
# url: https://www.github.com/joebuhlig/discourse-feature-quizzing

register_asset "stylesheets/common/feature-quizzing.scss"
register_asset "stylesheets/desktop/feature-quizzing.scss", :desktop
register_asset "stylesheets/mobile/feature-quizzing.scss", :mobile

enabled_site_setting :quizzing_enabled

Discourse.top_menu_items.push(:quizs)
Discourse.anonymous_top_menu_items.push(:quizs)
Discourse.filters.push(:quizs)
Discourse.anonymous_filters.push(:quizs)

after_initialize do

  require_dependency 'basic_category_serializer'
  class ::BasicCategorySerializer
    attributes :can_quiz

    def include_can_quiz?
      Category.can_quiz?(object.id)
    end

    def can_quiz
      true
    end

  end

  require_dependency 'post_serializer'
  class ::PostSerializer
    attributes :can_quiz

    def include_can_quiz?
      object.post_number == 1 && object.topic && object.topic.can_quiz?
    end

    def can_quiz
      true
    end
  end

  require_dependency 'topic_view_serializer'
  class ::TopicViewSerializer
    attributes :can_quiz, :quiz_count, :user_quizd

    def can_quiz
      object.topic.can_quiz?
    end

    def quiz_count
      object.topic.quiz_count
    end

    def user_quizd
      if scope.user
        object.topic.user_quizd(scope.user)
      else
        false
      end
    end

  end

  add_to_serializer(:topic_list_item, :quiz_count) { object.quiz_count }
  add_to_serializer(:topic_list_item, :can_quiz) { object.can_quiz? }
  add_to_serializer(:topic_list_item, :user_quizd) {
    object.user_quizd(scope.user) if scope.user
  }

  class ::Category
      def self.reset_quizzing_cache
        @allowed_quizzing_cache["allowed"] =
          begin
            Set.new(
              CategoryCustomField
                .where(name: "enable_topic_quizzing", value: "true")
                .pluck(:category_id)
            )
          end
      end

      @allowed_quizzing_cache = DistributedCache.new("allowed_quizzing")

      def self.can_quiz?(category_id)
        return false unless SiteSetting.quizzing_enabled

        unless set = @allowed_quizzing_cache["allowed"]
          set = reset_quizzing_cache
        end
        set.include?(category_id)
      end


      after_save :reset_quizzing_cache


      protected
      def reset_quizzing_cache
        ::Category.reset_quizzing_cache
      end
  end

  require_dependency 'user'
  class ::User
      def quiz_count
        if self.custom_fields["quizs"]
          user_quizs = self.custom_fields["quizs"]
          user_quizs.length - 1
        else
          0
        end
      end

      def alert_low_quizs?
        (quiz_limit - quiz_count) <= SiteSetting.quizzing_alert_quizs_left
      end

      def quizs
        if self.custom_fields["quizs"]
          self.custom_fields["quizs"]
        else
          [nil]
        end
      end

      def quizs_archive
        if self.custom_fields["quizs_archive"]
          return self.custom_fields["quizs_archive"]
        else
          return [nil]
        end
      end

      def reached_quizzing_limit?
        quiz_count >= quiz_limit
      end

      def quiz_limit
        SiteSetting.send("quizzing_tl#{self.trust_level}_quiz_limit")
      end

  end

  require_dependency 'current_user_serializer'
  class ::CurrentUserSerializer
    attributes :quizs_exceeded,  :quiz_count

    def quizs_exceeded
      object.reached_quizzing_limit?
    end

    def quiz_count
      object.quiz_count
    end

  end

  require_dependency 'topic'
  class ::Topic

    def can_quiz?
      SiteSetting.quizzing_enabled && Category.can_quiz?(category_id) && category.topic_id != id
    end

    def quiz_count
      if self.custom_fields["quiz_count"]
        self.custom_fields["quiz_count"].to_i
      else
        0 if self.can_quiz?
      end
    end

    def user_quizd(user)
      if user && user.custom_fields["quizs"]
        user.custom_fields["quizs"].include? self.id.to_s
      else
        false
      end
    end

  end

  require_dependency 'list_controller'
  class ::ListController
    def quizd_by
      unless SiteSetting.quizzing_show_quizs_on_profile
        render nothing: true, status: 404
      end
      list_opts = build_topic_list_options
      target_user = fetch_user_from_params(include_inactive: current_user.try(:staff?))
      list = generate_list_for("quizd_by", target_user, list_opts)
      list.more_topics_url = url_for(construct_url_with(:next, list_opts))
      list.prev_topics_url = url_for(construct_url_with(:prev, list_opts))
      respond_with_list(list)
    end
  end

  require_dependency 'topic_query'
  class ::TopicQuery
    SORTABLE_MAPPING["quizs"] = "custom_fields.quiz_count"

    def list_quizd_by(user)
      create_list(:user_topics) do |topics|
        topics.where(id: user.custom_fields["quizs"])
      end
    end

    def list_quizs
      create_list(:quizs, unordered: true) do |topics|
        topics.joins("left join topic_custom_fields tfv ON tfv.topic_id = topics.id AND tfv.name = 'quiz_count'")
              .order("coalesce(tfv.value,'0')::integer desc, topics.bumped_at desc")
      end
    end
  end

  require_dependency "jobs/base"
  module ::Jobs

    class VoteRelease < Jobs::Base
      def execute(args)
        if Topic.find_by(id: args[:topic_id])
          UserCustomField.where(name: "quizs", value: args[:topic_id]).find_each do |user_field|
            user = User.find(user_field.user_id)
            user.custom_fields["quizs"] = user.quizs.dup - [args[:topic_id].to_s]
            user.custom_fields["quizs_archive"] = user.quizs_archive.dup.push(args[:topic_id])
            user.save
          end
        end
      end
    end

    class VoteReclaim < Jobs::Base
      def execute(args)
        if Topic.find_by(id: args[:topic_id])
          UserCustomField.where(name: "quizs_archive", value: args[:topic_id]).find_each do |user_field|
            user = User.find(user_field.user_id)
            user.custom_fields["quizs"] = user.quizs.dup.push(args[:topic_id])
            user.custom_fields["quizs_archive"] = user.quizs_archive.dup - [args[:topic_id].to_s]
            user.save
          end
        end
      end
    end

  end

  DiscourseEvent.on(:topic_status_updated) do |topic_id, status, enabled|
    if (status == 'closed' || status == 'autoclosed' || status == 'archived') && enabled == true
      Jobs.enqueue(:quiz_release, {topic_id: topic_id})
    end

    if (status == 'closed' || status == 'autoclosed' || status == 'archived') && enabled == false
      Jobs.enqueue(:quiz_reclaim, {topic_id: topic_id})
    end
  end

  module ::DiscourseVoting
    class Engine < ::Rails::Engine
      isolate_namespace DiscourseVoting
    end
  end

  require File.expand_path(File.dirname(__FILE__) + '/app/controllers/discourse_quizzing/quizs_controller')

  DiscourseVoting::Engine.routes.draw do
    post 'quiz' => 'quizs#add'
    post 'unquiz' => 'quizs#remove'
    get 'who' => 'quizs#who'
  end

  Discourse::Application.routes.append do
    mount ::DiscourseVoting::Engine, at: "/quizzing"
    # USERNAME_ROUTE_FORMAT is deprecated but we may need to support it for older installs
    username_route_format = defined?(RouteFormat) ? RouteFormat.username : USERNAME_ROUTE_FORMAT
    get "topics/quizd-by/:username" => "list#quizd_by", as: "quizd_by", constraints: {username: username_route_format}
  end

  TopicList.preloaded_custom_fields << "quiz_count" if TopicList.respond_to? :preloaded_custom_fields
end
