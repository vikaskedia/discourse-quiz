import { createWidget } from 'discourse/widgets/widget';
import showModal from 'discourse/lib/show-modal';

export default createWidget('quiz-button', {
  tagName: 'div.quiz-button',

  buildClasses(attrs) {
    var buttonClass = "";
    if (attrs.closed){
      buttonClass = "quizzing-closed";
    }
    else{
      if (!attrs.user_quizd){
        buttonClass = "nonquiz";
      }
      else{
        if (this.currentUser && this.currentUser.quizs_exceeded){
          buttonClass = "quiz-limited nonquiz";
        }
        else{
          buttonClass = "quiz";
        }
      }
    }
    if (this.siteSettings.quizzing_show_who_quizd) {
      buttonClass += ' show-pointer';
    }
    return buttonClass;
  },

  html(attrs){
    var buttonTitle = I18n.t('quizzing.quiz_title');
    if (!this.currentUser){
      buttonTitle = I18n.t('log_in');
    }
    else{
      if (attrs.closed){
        buttonTitle = I18n.t('quizzing.quizzing_closed_title');
      }
      else{
        if (attrs.user_quizd){
          buttonTitle = I18n.t('quizzing.quizd_title');
        }
        else{
          if (this.currentUser && this.currentUser.quizs_exceeded){
            buttonTitle = I18n.t('quizzing.quizzing_limit');
          }
          else{
            buttonTitle = I18n.t('quizzing.quiz_title');
          }
        }
      }
    }
    return buttonTitle;
  },

  click(){
    if (!this.currentUser){
      showModal('login');
    }
    if (!this.attrs.closed && this.parentWidget.state.allowClick && !this.attrs.user_quizd){
      this.parentWidget.state.allowClick = false;
      this.parentWidget.state.initialVote = true;
      this.sendWidgetAction('addVote');
    }
    if (this.attrs.user_quizd || this.currentUser.quizs_exceeded) {
      $(".quiz-options").toggle();
    }
  },

  clickOutside(){
    $(".quiz-options").hide();
    this.parentWidget.state.initialVote = false;
  }
});
