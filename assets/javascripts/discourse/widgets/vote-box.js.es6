import { createWidget } from 'discourse/widgets/widget';
import { ajax } from 'discourse/lib/ajax';
import RawHtml from 'discourse/widgets/raw-html';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default createWidget('quiz-box', {
  tagName: 'div.quizzing-wrapper',
  buildKey: () => 'quiz-box',

  buildClasses() {
    if (this.siteSettings.quizzing_show_who_quizd) { return 'show-pointer'; }
  },

  defaultState() {
    return { allowClick: true, initialVote: false };
  },

  html(attrs, state){
    var quizCount = this.attach('quiz-count', attrs);
    var quizButton = this.attach('quiz-button', attrs);
    var quizOptions = this.attach('quiz-options', attrs);
    let contents = [quizCount, quizButton, quizOptions];

    if (state.quizsAlert > 0) {
      const html = "<div class='quizzing-popup-menu quiz-options popup-menu'>" + I18n.t("quizzing.quizs_left", {
          count: state.quizsAlert,
          path: this.currentUser.get("path") + "/activity/quizs"
      }) + "</div>";
      contents.push(new RawHtml({html}));
    }

    return contents;

  },

  hideVotesAlert() {
    if (this.state.quizsAlert) {
      this.state.quizsAlert = null;
      this.scheduleRerender();
    }
  },

  click() {
    this.hideVotesAlert();
  },

  clickOutside(){
    this.hideVotesAlert();
  },

  addVote(){
    var topic = this.attrs;
    var state = this.state;
    return ajax("/quizzing/quiz", {
      type: 'POST',
      data: {
        topic_id: topic.id
      }
    }).then(result => {
      topic.set('quiz_count', result.quiz_count);
      topic.set('user_quizd', true);
      this.currentUser.set('quizs_exceeded', !result.can_quiz);
      if (result.alert) {
        state.quizsAlert = result.quizs_left;
        this.scheduleRerender();
      }
      topic.set('who_quizd', result.who_quizd);
      state.allowClick = true;
    }).catch(popupAjaxError);
  },

  removeVote(){
    var topic = this.attrs;
    var state = this.state;
    return ajax("/quizzing/unquiz", {
      type: 'POST',
      data: {
        topic_id: topic.id
      }
    }).then(result => {
      topic.set('quiz_count', result.quiz_count);
      topic.set('user_quizd', false);
      this.currentUser.set('quizs_exceeded', !result.can_quiz);
      topic.set('who_quizd', result.who_quizd);
      state.allowClick = true;
    }).catch(popupAjaxError);
  }

});
