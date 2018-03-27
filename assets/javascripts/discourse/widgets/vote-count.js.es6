import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { ajax } from 'discourse/lib/ajax';


export default createWidget('quiz-count', {
  tagName: 'div.quiz-count-wrapper',
  buildKey: () => 'quiz-count',

  buildClasses() {
    if (this.attrs.quiz_count === 0){
      return "no-quizzes";
    }
  },

  defaultState() {
    return { whoVotedUsers: null };
  },

  html(attrs){
    let quizCount = h('div.quiz-count', attrs.quiz_count.toString());
    let whoVoted = null;
    if (this.siteSettings.quizzing_show_who_quizd && this.state.whoVotedUsers && this.state.whoVotedUsers.length > 0) {
      whoVoted = this.attach('small-user-list', {
        users: this.state.whoVotedUsers,
        addSelf: attrs.liked,
        listClassName: 'regular-quizzes',
      });
    }

    let buffer = [quizCount];
    if (whoVoted) {
      buffer.push(h('div.who-quizd.popup-menu.quizzing-popup-menu', [whoVoted]));
    }
    return buffer;
  },

  click(){
    if (this.siteSettings.quizzing_show_who_quizd && this.attrs.quiz_count > 0) {
      if (this.state.whoVotedUsers === null) {
        return this.getWhoVoted();
      } else {
        $(".who-quizd").toggle();
      }
    }
  },

  clickOutside(){
    $(".who-quizd").hide();
  },

  getWhoVoted() {
    return ajax("/quizzing/who", {
      type: 'GET',
      data: {
        topic_id: this.attrs.id
      }
    }).then((users)=>{
      this.state.whoVotedUsers = users.map(whoVotedAvatars);
    });
  },
});

function whoVotedAvatars(user) {
  return { template: user.avatar_template,
           username: user.username,
           post_url: user.post_url,
           url: Discourse.getURL('/users/') + user.username.toLowerCase() };
}
