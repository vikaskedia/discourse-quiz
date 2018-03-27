import computed from 'ember-addons/ember-computed-decorators';
import Category from 'discourse/models/category';
import { withPluginApi } from 'discourse/lib/plugin-api';

function initialize(api) {

  api.addPostClassesCallback((post) => {
    if (post.post_number === 1 && post.can_quiz) {
      return ["quizzing-post"];
    }
  });
  api.includePostAttributes('can_quiz');
  api.addTagsHtmlCallback((topic) => {
    if (!topic.can_quiz) { return; }

    var buffer = [];

    let title;
    if (topic.user_quizd) {
      title = ` title='${I18n.t('quizzing.quizd')}'`;
    }

    let userVotedClass = topic.user_quizd ? " quizd" : "";
    buffer.push(`<a href='${topic.get('url')}' class='list-quiz-count discourse-tag${userVotedClass}'${title}>`);
    buffer.push(I18n.t('quizzing.quizzes', {count: topic.quiz_count}));
    if (topic.user_quizd) {
      buffer.push(`<i class='fa fa-star'></i>`);
    }
    buffer.push("</a>");

    if (buffer.length > 0){
      return buffer.join("");
    }

  }, {priority: -100});
}

export default {
  name: 'extend-category-for-quizzing',
  before: 'inject-discourse-objects',
  initialize(container) {

    withPluginApi('0.8.4', api => {
      initialize(api, container);
    });

    Category.reopen({

      @computed("url")
      quizzesUrl(url) {
        return `${url}/l/quizzes`;
      },

      @computed('custom_fields.enable_topic_quizzing')
      enable_topic_quizzing: {
        get(enableField) {
          return enableField === "true";
        },
        set(value) {
          value = value ? "true" : "false";
          this.set("custom_fields.enable_topic_quizzing", value);
          return value;
        }
      }

    });
  }
};
