import { createWidget } from 'discourse/widgets/widget';

export default createWidget('remove-quiz', {
  tagName: 'div.remove-quiz',

  buildClasses() {
    return 'quiz-option';
  },

  html() {
    return ["Remove quiz"];
  },

  click(){
    this.sendWidgetAction('removeVote');
  }
});
