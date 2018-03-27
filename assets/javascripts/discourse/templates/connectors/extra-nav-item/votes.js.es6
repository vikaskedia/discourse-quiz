export default {
  quizdPath(){
    return "foobar";
  },
  path(category){
    if (category) {
      return category.get('quizzesUrl');
    }
  },
  displayName() {
    return I18n.t("quizzing.quiz_title_plural");
  },
  setupComponent(args, component) {
    const filterMode = args.filterMode;
    // no endsWith in IE
    if (filterMode && filterMode.indexOf("quizzes", filterMode.length - 5) !== -1) {
      component.set("classNames", ["active"]);
    }
  },
  shouldRender(args, component) {
    const category = component.get("category");
    return !!(category && category.get("can_quiz"));
  }
};
