import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';

export default createWidget('quiz-options', {
  tagName: 'div.quiz-options',

  buildClasses() {
    return 'quizzing-popup-menu popup-menu hidden';
  },

  html(attrs){
    var contents = [];

    if (attrs.user_quizd){
        contents.push(this.attach('remove-quiz', attrs));
    }
    else if (this.currentUser && this.currentUser.quizzes_exceeded && !attrs.user_quizd) {
      contents.push([
          h("div", I18n.t("quizzing.reached_limit")),
          h("p",
            h("a",{ href: this.currentUser.get("path") + "/activity/quizzes" }, I18n.t("quizzing.list_quizzes"))
          )
      ]);
    }
    return contents;
  }
});
