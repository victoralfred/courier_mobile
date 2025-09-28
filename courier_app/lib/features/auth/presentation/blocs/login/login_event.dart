import 'package:equatable/equatable.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object?> get props => [];
}

class LoginEmailChanged extends LoginEvent {
  final String email;

  const LoginEmailChanged(this.email);

  @override
  List<Object> get props => [email];
}

class LoginPasswordChanged extends LoginEvent {
  final String password;

  const LoginPasswordChanged(this.password);

  @override
  List<Object> get props => [password];
}

class LoginSubmitted extends LoginEvent {
  const LoginSubmitted();
}

class LoginWithOAuth extends LoginEvent {
  final OAuthProviderType provider;

  const LoginWithOAuth(this.provider);

  @override
  List<Object> get props => [provider];
}

class LoginWithBiometric extends LoginEvent {
  const LoginWithBiometric();
}

class LoginPasswordVisibilityToggled extends LoginEvent {
  const LoginPasswordVisibilityToggled();
}

enum OAuthProviderType {
  google,
  github,
  microsoft,
  apple,
}