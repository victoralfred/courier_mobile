import 'package:equatable/equatable.dart';
import '../../../domain/entities/user_role.dart';

abstract class RegistrationEvent extends Equatable {
  const RegistrationEvent();

  @override
  List<Object?> get props => [];
}

class RegistrationFirstNameChanged extends RegistrationEvent {
  final String firstName;

  const RegistrationFirstNameChanged(this.firstName);

  @override
  List<Object> get props => [firstName];
}

class RegistrationLastNameChanged extends RegistrationEvent {
  final String lastName;

  const RegistrationLastNameChanged(this.lastName);

  @override
  List<Object> get props => [lastName];
}

class RegistrationEmailChanged extends RegistrationEvent {
  final String email;

  const RegistrationEmailChanged(this.email);

  @override
  List<Object> get props => [email];
}

class RegistrationPhoneChanged extends RegistrationEvent {
  final String phone;

  const RegistrationPhoneChanged(this.phone);

  @override
  List<Object> get props => [phone];
}

class RegistrationPasswordChanged extends RegistrationEvent {
  final String password;

  const RegistrationPasswordChanged(this.password);

  @override
  List<Object> get props => [password];
}

class RegistrationConfirmPasswordChanged extends RegistrationEvent {
  final String confirmPassword;

  const RegistrationConfirmPasswordChanged(this.confirmPassword);

  @override
  List<Object> get props => [confirmPassword];
}

class RegistrationRoleSelected extends RegistrationEvent {
  final UserRoleType role;

  const RegistrationRoleSelected(this.role);

  @override
  List<Object> get props => [role];
}

class RegistrationPasswordVisibilityToggled extends RegistrationEvent {
  const RegistrationPasswordVisibilityToggled();
}

class RegistrationConfirmPasswordVisibilityToggled extends RegistrationEvent {
  const RegistrationConfirmPasswordVisibilityToggled();
}

class RegistrationTermsAccepted extends RegistrationEvent {
  final bool accepted;

  const RegistrationTermsAccepted(this.accepted);

  @override
  List<Object> get props => [accepted];
}

class RegistrationSubmitted extends RegistrationEvent {
  const RegistrationSubmitted();
}