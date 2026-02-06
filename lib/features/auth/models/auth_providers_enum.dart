enum AuthProviders {
  gmail,
  email,
  mobile,
  apple
  ;

  static AuthProviders fromString(String v) =>
      AuthProviders.values.firstWhere((e) => e.toString() == v);
}
